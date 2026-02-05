import SwiftUI
import SwiftData

// MARK: - Section Content Views
// Clean, minimal list views for each section

// MARK: - Orders Section

struct AllOrdersListView: View {
    @Query(sort: \SDOrder.createdAt, order: .reverse) private var orders: [SDOrder]
    @State private var searchText = ""
    @State private var statusFilter: String? = nil
    @State private var cachedFilteredOrders: [SDOrder] = []

    var body: some View {
        List {
            ForEach(cachedFilteredOrders) { order in
                NavigationLink(value: SDSidebarItem.orderDetail(order.id)) {
                    OrderListRow(order: order)
                }
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Search orders")
        .navigationTitle("Orders")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("All") { statusFilter = nil }
                    Divider()
                    ForEach(["pending", "confirmed", "preparing", "ready", "completed", "cancelled"], id: \.self) { status in
                        Button(status.capitalized) { statusFilter = status }
                    }
                } label: {
                    Label(statusFilter?.capitalized ?? "Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task { updateFilteredOrders() }
        .onChange(of: searchText) { _, _ in updateFilteredOrders() }
        .onChange(of: statusFilter) { _, _ in updateFilteredOrders() }
        .onChange(of: orders.count) { _, _ in updateFilteredOrders() }
    }

    private func updateFilteredOrders() {
        cachedFilteredOrders = orders.filter { order in
            let matchesSearch = searchText.isEmpty ||
                order.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                order.orderNumber.localizedCaseInsensitiveContains(searchText)
            let matchesStatus = statusFilter == nil || order.status == statusFilter
            return matchesSearch && matchesStatus
        }
    }
}

struct OrderListRow: View {
    let order: SDOrder

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(order.orderNumber)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if !order.displayTitle.contains("#") {
                        Text(order.displayTitle)
                            .font(.subheadline.weight(.medium))
                    }
                }
                Text(order.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(order.displayTotal)
                .font(.subheadline.weight(.medium).monospacedDigit())

            OrderStatusBadge(status: order.status)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Locations Section

struct AllLocationsListView: View {
    @Query(sort: \SDLocation.name) private var locations: [SDLocation]

    var body: some View {
        List {
            ForEach(locations) { location in
                NavigationLink(value: SDSidebarItem.locationDetail(location.id)) {
                    LocationListRow(location: location)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Locations")
    }
}

struct LocationListRow: View {
    let location: SDLocation

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(location.isActive ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.subheadline.weight(.medium))
                if let city = location.city, let state = location.state {
                    Text("\(city), \(state)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if location.activeOrderCount > 0 {
                Text("\(location.activeOrderCount) orders")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            NavigationLink(value: SDSidebarItem.queue(location.id)) {
                Image(systemName: "person.3.sequence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Customers Section

struct CustomersListView: View {
    var store: EditorStore
    @State private var searchText = ""
    @State private var cachedFilteredCustomers: [Customer] = []

    var body: some View {
        List {
            ForEach(cachedFilteredCustomers) { customer in
                NavigationLink(value: SDSidebarItem.customerDetail(customer.id)) {
                    CustomerListRow(customer: customer)
                }
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Search customers")
        .navigationTitle("Customers")
        .task {
            if store.customers.isEmpty {
                await store.loadCustomers()
            }
            updateFilteredCustomers()
        }
        .onChange(of: searchText) { _, _ in updateFilteredCustomers() }
        .onChange(of: store.customers.count) { _, _ in updateFilteredCustomers() }
    }

    private func updateFilteredCustomers() {
        if searchText.isEmpty {
            cachedFilteredCustomers = store.customers
        } else {
            cachedFilteredCustomers = store.customers.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                ($0.email?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.phone?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
}

struct CustomerListRow: View {
    let customer: Customer

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay {
                    Text(customer.initials)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(customer.displayName)
                    .font(.subheadline.weight(.medium))
                if let email = customer.email {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(customer.formattedTotalSpent)
                    .font(.caption.monospacedDigit())
                if let tier = customer.loyaltyTier, !tier.isEmpty {
                    Text(tier.capitalized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Catalog Section

struct CatalogContentView: View {
    var store: EditorStore
    @Binding var selection: SDSidebarItem?
    @State private var searchText = ""
    @State private var selectedProductIds: Set<UUID> = []
    @State private var isEditMode = false
    @State private var showArchived = false
    @State private var isProcessing = false

    // Cached filtered data (avoid filtering on every render)
    @State private var cachedFilteredProducts: [Product] = []
    @State private var cachedArchivedCount: Int = 0
    // Debounce token to prevent onChange cascade during bulk loads
    @State private var filterGeneration: Int = 0

    var body: some View {
        // PERF: List at top level with .searchable outside conditionals
        // prevents _NSDetectedLayoutRecursion from VStack + conditional + searchable
        List(selection: isEditMode ? $selectedProductIds : .constant(Set<UUID>())) {
            if isEditMode && !selectedProductIds.isEmpty {
                Section {
                    bulkActionBar
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            }

            if store.products.isEmpty {
                ContentUnavailableView("No Products", systemImage: "square.grid.2x2", description: Text("Products will appear here"))
                    .listRowSeparator(.hidden)
            } else if cachedFilteredProducts.isEmpty {
                ContentUnavailableView(
                    showArchived ? "No Archived Products" : "No Products Found",
                    systemImage: showArchived ? "archivebox" : "magnifyingglass",
                    description: Text(showArchived ? "Archived products will appear here" : "Try a different search term")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(cachedFilteredProducts) { product in
                    if isEditMode {
                        ProductListRow(product: product, showArchiveBadge: showArchived)
                            .tag(product.id)
                    } else {
                        NavigationLink(value: SDSidebarItem.productDetail(product.id)) {
                            ProductListRow(product: product, showArchiveBadge: showArchived)
                        }
                        .contextMenu {
                            productContextMenu(for: product)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Search products")
        .navigationTitle(showArchived ? "Archived" : "Catalog")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showArchived.toggle()
                    selectedProductIds.removeAll()
                } label: {
                    Label(
                        showArchived ? "Show Active" : "Show Archived",
                        systemImage: showArchived ? "tray.full" : "archivebox"
                    )
                }
                .help(showArchived ? "Show active products" : "Show archived products (\(cachedArchivedCount))")

                Button {
                    withAnimation {
                        isEditMode.toggle()
                        if !isEditMode {
                            selectedProductIds.removeAll()
                        }
                    }
                } label: {
                    Text(isEditMode ? "Done" : "Select")
                }
            }
        }
        .task { updateFilteredProducts() }
        .onChange(of: searchText) { _, _ in updateFilteredProducts() }
        .onChange(of: showArchived) { _, _ in updateFilteredProducts() }
        .onChange(of: store.products.count) { _, newCount in
            // Debounce: only refilter if count actually changed meaningfully
            let gen = filterGeneration + 1
            filterGeneration = gen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.filterGeneration == gen {
                    self.updateFilteredProducts()
                }
            }
        }
        .onChange(of: isEditMode) { _, newValue in
            if !newValue {
                selectedProductIds.removeAll()
            }
        }
    }

    // MARK: - Bulk Action Bar (extracted to reduce body complexity)

    @ViewBuilder
    private var bulkActionBar: some View {
        HStack(spacing: 16) {
            Text("\(selectedProductIds.count) selected")
                .font(.subheadline.weight(.medium))

            Spacer()

            if isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else {
                if showArchived {
                    Button {
                        Task { await bulkUnarchive() }
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                } else {
                    Button {
                        Task { await bulkArchive() }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }

                Button {
                    selectedProductIds.removeAll()
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func updateFilteredProducts() {
        let products = store.products
        cachedArchivedCount = products.reduce(into: 0) { count, p in
            if p.status == "archived" { count += 1 }
        }
        let archived = showArchived
        let search = searchText
        cachedFilteredProducts = products.filter { product in
            let isArchived = product.status == "archived"
            let matchesArchiveFilter = archived ? isArchived : !isArchived
            guard matchesArchiveFilter else { return false }
            if search.isEmpty { return true }
            return product.name.localizedCaseInsensitiveContains(search) ||
                (product.sku?.localizedCaseInsensitiveContains(search) ?? false)
        }
    }

    private func bulkArchive() async {
        guard !selectedProductIds.isEmpty else { return }
        isProcessing = true
        await store.bulkUpdateProductStatus(ids: Array(selectedProductIds), status: "archived")
        selectedProductIds.removeAll()
        isProcessing = false
        isEditMode = false
    }

    private func bulkUnarchive() async {
        guard !selectedProductIds.isEmpty else { return }
        isProcessing = true
        await store.bulkUpdateProductStatus(ids: Array(selectedProductIds), status: "published")
        selectedProductIds.removeAll()
        isProcessing = false
        isEditMode = false
    }

    @ViewBuilder
    private func productContextMenu(for product: Product) -> some View {
        if product.status == "archived" {
            Button {
                Task { await store.bulkUpdateProductStatus(ids: [product.id], status: "published") }
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
        } else {
            Button {
                Task { await store.bulkUpdateProductStatus(ids: [product.id], status: "archived") }
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }

        Divider()

        if product.status != "published" {
            Button {
                Task { await store.bulkUpdateProductStatus(ids: [product.id], status: "published") }
            } label: {
                Label("Publish", systemImage: "checkmark.circle")
            }
        }

        if product.status != "draft" {
            Button {
                Task { await store.bulkUpdateProductStatus(ids: [product.id], status: "draft") }
            } label: {
                Label("Set as Draft", systemImage: "pencil.circle")
            }
        }

        Divider()

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(product.id.uuidString, forType: .string)
        } label: {
            Label("Copy ID", systemImage: "doc.on.doc")
        }

        if let sku = product.sku {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(sku, forType: .string)
            } label: {
                Label("Copy SKU", systemImage: "barcode")
            }
        }
    }
}

struct ProductListRow: View {
    let product: Product
    var showArchiveBadge: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                // PERF: CachedAsyncImage uses NSCache instead of re-fetching per scroll
                CachedAsyncImage(
                    url: product.featuredImage.flatMap { URL(string: $0) },
                    size: 40
                )

                if showArchiveBadge {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.orange)
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let sku = product.sku {
                        Text(sku)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if product.status == "draft" {
                        Text("Draft")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(product.displayPrice)
                    .font(.subheadline.monospacedDigit())
                HStack(spacing: 4) {
                    Circle()
                        .fill(product.stockStatusColor)
                        .frame(width: 6, height: 6)
                    Text(product.stockQuantity.map { "\($0)" } ?? "—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Creations Section

struct CreationsContentView: View {
    var store: EditorStore
    @Binding var selection: SDSidebarItem?
    @State private var searchText = ""
    @State private var cachedFilteredCreations: [Creation] = []

    var body: some View {
        Group {
            if store.creations.isEmpty {
                ContentUnavailableView("No Creations", systemImage: "wand.and.stars", description: Text("React components and templates"))
            } else {
                List {
                    ForEach(cachedFilteredCreations) { creation in
                        NavigationLink(value: SDSidebarItem.creationDetail(creation.id)) {
                            CreationListRow(creation: creation)
                        }
                    }
                }
                .listStyle(.inset)
                .searchable(text: $searchText, prompt: "Search creations")
            }
        }
        .navigationTitle("Creations")
        .task { updateFilteredCreations() }
        .onChange(of: searchText) { _, _ in updateFilteredCreations() }
        .onChange(of: store.creations.count) { _, _ in updateFilteredCreations() }
    }

    private func updateFilteredCreations() {
        if searchText.isEmpty {
            cachedFilteredCreations = store.creations
        } else {
            cachedFilteredCreations = store.creations.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct CreationListRow: View {
    let creation: Creation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: creation.creationType.icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(creation.name)
                    .font(.subheadline.weight(.medium))
                Text(creation.creationType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if creation.status == .published {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Browser Sessions Section

struct BrowserSessionsListView: View {
    var store: EditorStore
    @Binding var selection: SDSidebarItem?

    var body: some View {
        Group {
            if store.browserSessions.isEmpty {
                ContentUnavailableView("No Browser Sessions", systemImage: "globe", description: Text("Browser sessions will appear here"))
            } else {
                List {
                    ForEach(store.browserSessions) { session in
                        NavigationLink(value: SDSidebarItem.browserSessionDetail(session.id)) {
                            BrowserSessionListRow(session: session)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Browser Sessions")
    }
}

struct BrowserSessionListRow: View {
    let session: BrowserSession

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(session.isActive ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayName)
                    .font(.subheadline.weight(.medium))
                if let url = session.currentUrl {
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Emails Section

struct EmailsListView: View {
    var store: EditorStore
    @Binding var selection: SDSidebarItem?

    var body: some View {
        List {
            if !store.emails.isEmpty {
                Section("Recent Emails") {
                    ForEach(store.emails) { email in
                        NavigationLink(value: SDSidebarItem.emailDetail(email.id)) {
                            EmailListRow(email: email)
                        }
                    }
                }
            }

            if !store.emailCampaigns.isEmpty {
                Section("Campaigns") {
                    ForEach(store.emailCampaigns) { campaign in
                        NavigationLink(value: SDSidebarItem.emailCampaignDetail(campaign.id)) {
                            Text(campaign.name ?? "Campaign")
                                .font(.subheadline)
                        }
                    }
                }
            }

            if store.emails.isEmpty && store.emailCampaigns.isEmpty {
                ContentUnavailableView("No Emails", systemImage: "envelope")
            }
        }
        .listStyle(.inset)
        .navigationTitle("Emails")
    }
}

struct EmailListRow: View {
    let email: ResendEmail

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(email.subject.isEmpty ? "No Subject" : email.subject)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(email.toEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(text: email.statusLabel, color: email.statusColor)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Agents Section

struct AgentsListView: View {
    var store: EditorStore
    @Binding var selection: SDSidebarItem?

    var body: some View {
        Group {
            if store.aiAgents.isEmpty {
                ContentUnavailableView("No AI Agents", systemImage: "cpu", description: Text("Create agents to automate tasks"))
            } else {
                List {
                    ForEach(store.aiAgents) { agent in
                        NavigationLink(value: SDSidebarItem.agentDetail(agent.id)) {
                            AgentListRow(agent: agent)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("AI Agents")
    }
}

struct AgentListRow: View {
    let agent: AIAgent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: agent.displayIcon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName)
                    .font(.subheadline.weight(.medium))
                if let prompt = agent.systemPrompt {
                    Text(String(prompt.prefix(60)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Circle()
                .fill(agent.isActive ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Team Chat

struct TeamChatPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("Team Chat", systemImage: "bubble.left.and.bubble.right", description: Text("Coming soon"))
            .navigationTitle("Team Chat")
    }
}

// MARK: - Queue View

struct SDLocationQueueView: View {
    let locationId: UUID
    @StateObject private var queueStore: LocationQueueStore

    init(locationId: UUID) {
        self.locationId = locationId
        _queueStore = StateObject(wrappedValue: LocationQueueStore.shared(for: locationId))
    }

    var body: some View {
        Group {
            if queueStore.isLoading && queueStore.queue.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if queueStore.queue.isEmpty {
                ContentUnavailableView("No Customers", systemImage: "person.3.sequence", description: Text("Queue is empty"))
            } else {
                List {
                    ForEach(queueStore.queue) { entry in
                        QueueEntryRow(entry: entry)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Queue")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await queueStore.loadQueue() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task(id: locationId) {
            await queueStore.loadQueue()
            queueStore.subscribeToRealtime()
        }
        .onDisappear {
            queueStore.unsubscribeFromRealtime()
        }
    }
}

struct QueueEntryRow: View {
    let entry: QueueEntry

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(entry.position)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.customerName ?? "Customer")
                    .font(.subheadline.weight(.medium))
                if let phone = entry.customerPhone {
                    Text(phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(entry.addedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - CRM Views

struct CRMEmailCampaignsView: View {
    var store: EditorStore
    @Binding var selection: SDSidebarItem?

    var body: some View {
        if store.emailCampaigns.isEmpty {
            ContentUnavailableView("No Email Campaigns", systemImage: "envelope.badge")
        } else {
            List(store.emailCampaigns) { campaign in
                NavigationLink(value: SDSidebarItem.emailCampaignDetail(campaign.id)) {
                    Text(campaign.name ?? "Campaign")
                        .font(.subheadline)
                }
            }
            .listStyle(.inset)
            .navigationTitle("Email Campaigns")
        }
    }
}

struct CRMMetaCampaignsView: View {
    var store: EditorStore
    @Binding var selection: SDSidebarItem?

    var body: some View {
        if store.metaCampaigns.isEmpty {
            ContentUnavailableView("No Meta Campaigns", systemImage: "megaphone")
        } else {
            List(store.metaCampaigns) { campaign in
                NavigationLink(value: SDSidebarItem.metaCampaignDetail(campaign.id)) {
                    Text(campaign.name ?? "Campaign")
                        .font(.subheadline)
                }
            }
            .listStyle(.inset)
            .navigationTitle("Meta Campaigns")
        }
    }
}

struct CRMMetaIntegrationsView: View {
    var store: EditorStore
    @Binding var selection: SDSidebarItem?

    var body: some View {
        if store.metaIntegrations.isEmpty {
            ContentUnavailableView("No Meta Integrations", systemImage: "link")
        } else {
            List(store.metaIntegrations) { integration in
                NavigationLink(value: SDSidebarItem.metaIntegrationDetail(integration.id)) {
                    Text(integration.businessName ?? "Integration")
                        .font(.subheadline)
                }
            }
            .listStyle(.inset)
            .navigationTitle("Meta Integrations")
        }
    }
}
