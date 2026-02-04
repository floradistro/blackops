import SwiftUI
import SwiftData

// MARK: - Detail Wrappers
// Clean, comprehensive detail views following Apple HIG

// MARK: - Order Detail

struct OrderDetailWrapper: View {
    let orderId: UUID
    var store: EditorStore
    @Query private var orders: [SDOrder]

    init(orderId: UUID, store: EditorStore) {
        self.orderId = orderId
        self.store = store
        _orders = Query(filter: #Predicate<SDOrder> { $0.id == orderId })
    }

    var body: some View {
        if let sdOrder = orders.first {
            if let order = store.orders.first(where: { $0.id == orderId }) {
                OrderDetailView(order: order, store: store)
            } else {
                SDOrderDetailView(order: sdOrder)
            }
        } else if let order = store.orders.first(where: { $0.id == orderId }) {
            OrderDetailView(order: order, store: store)
        } else {
            ContentUnavailableView("Order not found", systemImage: "bag")
        }
    }
}

// MARK: - Order Detail View (Full Order model)

struct OrderDetailView: View {
    let order: Order
    var store: EditorStore
    @State private var orderItems: [OrderItem] = []
    @State private var isLoadingItems = true

    var body: some View {
        SettingsContainer {
            // Header
            SettingsDetailHeader(
                title: order.orderNumber,
                subtitle: order.shippingName ?? order.channel.label,
                icon: "bag"
            )

            // Status row
            HStack(spacing: 12) {
                SettingsStatCard(label: "Status", value: order.statusLabel, color: order.statusColor)
                SettingsStatCard(label: "Payment", value: order.paymentStatus?.capitalized ?? "—")
                SettingsStatCard(label: "Total", value: order.displayTotal)
            }

            // Customer
            if order.shippingName != nil || order.customerId != nil {
                SettingsGroup(header: "Customer") {
                    if let name = order.shippingName {
                        SettingsRow(label: "Name", value: name)
                    }
                    if let city = order.shippingCity, let state = order.shippingState {
                        SettingsRow(label: "Location", value: "\(city), \(state)")
                            .settingsDivider()
                    }
                }
            }

            // Items
            SettingsGroup(header: "Items (\(orderItems.count))") {
                if isLoadingItems {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else if orderItems.isEmpty {
                    Text("No items")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ForEach(Array(orderItems.enumerated()), id: \.element.id) { index, item in
                        OrderItemSettingsRow(item: item)
                            .settingsDivider(if: index > 0, leadingInset: 56)
                    }
                }
            }

            // Pricing
            SettingsGroup(header: "Pricing") {
                SettingsRow(label: "Subtotal", value: formatCurrency(order.subtotal))
                if let tax = order.taxAmount, tax > 0 {
                    SettingsRow(label: "Tax", value: formatCurrency(tax))
                        .settingsDivider()
                }
                if let discount = order.discountAmount, discount > 0 {
                    SettingsRow(label: "Discount", value: "-\(formatCurrency(discount))")
                        .settingsDivider()
                }
                SettingsDivider()
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(formatCurrency(order.totalAmount))
                        .font(.title3.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            // Payment
            SettingsGroup(header: "Payment") {
                if let method = order.paymentMethodTitle ?? order.paymentMethod {
                    SettingsRow(label: "Method", value: method)
                }
                SettingsBadgeRow(label: "Status", badge: order.paymentStatus?.capitalized ?? "Unknown", badgeColor: order.paymentStatusColor)
                    .settingsDivider()
                if let paidDate = order.paidDate {
                    SettingsRow(label: "Paid", value: paidDate.formatted(date: .abbreviated, time: .shortened))
                        .settingsDivider()
                }
            }

            // Fulfillment
            SettingsGroup(header: "Fulfillment") {
                SettingsRow(label: "Type", value: order.fulfillmentType.label)
                SettingsBadgeRow(label: "Status", badge: order.fulfillmentStatus?.capitalized ?? "Unfulfilled", badgeColor: order.fulfillmentStatusColor)
                    .settingsDivider()
                if let carrier = order.fulfillmentCarrier {
                    SettingsRow(label: "Carrier", value: carrier)
                        .settingsDivider()
                }
                if let tracking = order.fulfillmentTrackingNumber {
                    SettingsRow(label: "Tracking", value: tracking, mono: true)
                        .settingsDivider()
                }
            }

            // Notes
            if order.customerNote != nil || order.staffNotes != nil {
                SettingsGroup(header: "Notes") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let note = order.customerNote, !note.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Customer Note")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(note)
                                    .font(.subheadline)
                            }
                        }
                        if let staff = order.staffNotes, !staff.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Staff Notes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(staff)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(12)
                }
            }

            // Timeline
            SettingsGroup(header: "Timeline") {
                if let created = order.createdAt {
                    SettingsRow(label: "Created", value: created.formatted(date: .abbreviated, time: .shortened))
                }
                if let prepared = order.preparedAt {
                    SettingsRow(label: "Prepared", value: prepared.formatted(date: .abbreviated, time: .shortened))
                        .settingsDivider()
                }
                if let completed = order.completedAt {
                    SettingsRow(label: "Completed", value: completed.formatted(date: .abbreviated, time: .shortened))
                        .settingsDivider()
                }
            }
        }
        .navigationTitle("Order \(order.orderNumber)")
        .task {
            await loadOrderItems()
        }
    }

    private func loadOrderItems() async {
        isLoadingItems = true
        do {
            let response = try await SupabaseService.shared.client
                .from("order_items")
                .select()
                .eq("order_id", value: order.id.uuidString)
                .execute()
            orderItems = try JSONDecoder.supabaseDecoder.decode([OrderItem].self, from: response.data)
        } catch {
            print("Failed to load order items: \(error)")
        }
        isLoadingItems = false
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = order.currency ?? "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Order Item Settings Row

struct OrderItemSettingsRow: View {
    let item: OrderItem

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.productImage ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .quaternaryLabelColor))
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let tier = item.tierName {
                        Text(tier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("×\(item.displayQuantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(item.displayTotal)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// SD Order Detail (SwiftData version)
struct SDOrderDetailView: View {
    let order: SDOrder

    var body: some View {
        SettingsContainer {
            // Header
            SettingsDetailHeader(
                title: order.orderNumber,
                subtitle: order.displayTitle,
                icon: "bag"
            )

            // Stats
            HStack(spacing: 12) {
                SettingsStatCard(label: "Status", value: order.status.capitalized)
                SettingsStatCard(label: "Total", value: order.displayTotal)
            }

            // Details
            SettingsGroup(header: "Details") {
                SettingsRow(label: "Order Number", value: order.orderNumber, mono: true)
                SettingsRow(label: "Created", value: order.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .settingsDivider()
                SettingsRow(label: "Channel", value: order.channel.capitalized)
                    .settingsDivider()
                if let location = order.location {
                    SettingsRow(label: "Location", value: location.name)
                        .settingsDivider()
                }
            }

            // Payment
            SettingsGroup(header: "Payment") {
                SettingsBadgeRow(label: "Status", badge: order.paymentStatus?.capitalized ?? "Unknown", badgeColor: .secondary)
            }

            // Notes
            if let note = order.customerNote, !note.isEmpty {
                SettingsGroup(header: "Customer Note") {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
            }
        }
        .navigationTitle("Order \(order.orderNumber)")
    }
}

// MARK: - Order Item Row

struct OrderItemRow: View {
    let item: OrderItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Image
            AsyncImage(url: URL(string: item.productImage ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .quaternaryLabelColor))
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    if let sku = item.productSku {
                        Text(sku)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let tier = item.tierName {
                        Text(tier)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .quaternaryLabelColor))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Quantity & Price
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.displayTotal)
                    .font(.subheadline.weight(.medium))
                Text("\(item.displayQuantity) × \(item.displayPrice)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Product Detail

struct ProductDetailWrapper: View {
    let productId: UUID
    var store: EditorStore

    var body: some View {
        if let product = store.products.first(where: { $0.id == productId }) {
            ProductDetailView(product: product, store: store)
        } else {
            ContentUnavailableView("Product not found", systemImage: "cube.box")
        }
    }
}

struct ProductDetailView: View {
    let product: Product
    var store: EditorStore

    @State private var fieldSchemas: [FieldSchema] = []
    @State private var isLoadingSchemas = true

    var body: some View {
        SettingsContainer {
            // Header
            SettingsDetailHeader(
                title: product.name,
                subtitle: product.sku,
                image: product.featuredImage
            )

            // Status row
            HStack(spacing: 12) {
                SettingsStatCard(label: "Status", value: product.status?.capitalized ?? "Draft")
                SettingsStatCard(label: "Stock", value: product.stockQuantity.map { "\($0)" } ?? "N/A")
                SettingsStatCard(label: "Price", value: product.displayPrice)
            }

            // Pricing Tiers
            if let schema = product.pricingSchema, !schema.tiers.isEmpty {
                SettingsGroup(header: "Pricing Tiers") {
                    ForEach(Array(schema.tiers.enumerated()), id: \.element.id) { index, tier in
                        SettingsRow(label: tier.label, value: tier.formattedPrice)
                            .settingsDivider(if: index > 0)
                    }
                }
            }

            // Description
            if let desc = product.description ?? product.shortDescription, !desc.isEmpty {
                SettingsGroup(header: "Description") {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
            }

            // Product Details
            SettingsGroup(header: "Product Details") {
                categoryRow
                SettingsRow(label: "Type", value: product.type?.capitalized ?? "Simple")
                    .settingsDivider()
                SettingsRow(label: "Visibility", value: product.productVisibility?.capitalized ?? "Visible")
                    .settingsDivider()
                if product.hasVariations == true {
                    SettingsRow(label: "Variations", value: "Yes")
                        .settingsDivider()
                }
            }

            // Field Schemas (Dynamic fields from category)
            ForEach(fieldSchemas) { schema in
                SettingsGroup(header: schema.name) {
                    ForEach(Array(schema.fields.enumerated()), id: \.element.fieldId) { index, field in
                        let key = field.key ?? field.name ?? ""
                        let value = getFieldValue(for: key)
                        let displayValue = value.map { formatFieldValue($0, type: field.fieldType, unit: field.unit) } ?? "—"

                        SettingsRow(label: field.displayLabel, value: displayValue)
                            .settingsDivider(if: index > 0)
                    }
                }
            }

            // Inventory
            SettingsGroup(header: "Inventory") {
                SettingsRow(label: "Quantity", value: product.stockQuantity.map { "\($0)" } ?? "N/A")
                SettingsRow(label: "Status", value: product.stockStatusLabel)
                    .settingsDivider()
                if let cost = product.costPrice {
                    SettingsRow(label: "Cost Price", value: String(format: "$%.2f", NSDecimalNumber(decimal: cost).doubleValue))
                        .settingsDivider()
                }
            }

            // Metadata
            SettingsGroup(header: "Metadata") {
                SettingsRow(label: "Product ID", value: String(product.id.uuidString.prefix(8)).uppercased(), mono: true)
                if let created = product.createdAt {
                    SettingsRow(label: "Created", value: created)
                        .settingsDivider()
                }
                if let updated = product.updatedAt {
                    SettingsRow(label: "Updated", value: updated)
                        .settingsDivider()
                }
            }
        }
        .navigationTitle(product.name)
        .id(product.id)
        .task(id: product.id) {
            fieldSchemas = []
            isLoadingSchemas = true
            await loadFieldSchemas()
        }
    }

    @ViewBuilder
    private var categoryRow: some View {
        if let categoryId = product.primaryCategoryId,
           let category = store.categories.first(where: { $0.id == categoryId }) {
            SettingsRow(label: "Category", value: category.name)
        } else {
            SettingsRow(label: "Category", value: "Uncategorized")
        }
    }

    private func loadFieldSchemas() async {
        guard let categoryId = product.primaryCategoryId else {
            isLoadingSchemas = false
            return
        }
        do {
            fieldSchemas = try await SupabaseService.shared.fetchFieldSchemasForCategory(categoryId: categoryId)
            print("[ProductDetail] Loaded \(fieldSchemas.count) field schemas for category \(categoryId)")
            for schema in fieldSchemas {
                print("[ProductDetail] Schema: \(schema.name) with \(schema.fields.count) fields")
            }
        } catch {
            print("[ProductDetail] Failed to load field schemas: \(error)")
        }
        isLoadingSchemas = false
    }

    private func getFieldValue(for key: String) -> AnyCodable? {
        guard let fields = product.customFields else { return nil }
        if let value = fields[key] { return value }
        let alternateKeys: [String: [String]] = [
            "d9_percentage": ["d9_thc_percentage"],
            "nose": ["aroma"],
            "aroma": ["nose"]
        ]
        if let alternates = alternateKeys[key] {
            for altKey in alternates {
                if let value = fields[altKey] { return value }
            }
        }
        return nil
    }

    private func formatFieldValue(_ value: AnyCodable, type: String, unit: String?) -> String {
        switch type {
        case "number":
            let num: Double? = {
                if let d = value.value as? Double { return d }
                if let i = value.value as? Int { return Double(i) }
                if let s = value.value as? String { return Double(s) }
                return nil
            }()
            if let num = num {
                let truncated = (num * 100).rounded(.towardZero) / 100
                let formatted = String(format: "%.2f", truncated)
                    .replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
                return unit != nil ? "\(formatted)\(unit!)" : formatted
            }
        case "boolean":
            if let bool = value.value as? Bool { return bool ? "Yes" : "No" }
        case "select", "multiselect":
            if let arr = value.value as? [String] { return arr.joined(separator: ", ") }
        default: break
        }
        if let str = value.value as? String { return str }
        return "\(value.value)"
    }
}

// MARK: - Location Detail

struct LocationDetailWrapper: View {
    let locationId: UUID
    var store: EditorStore
    @Query private var locations: [SDLocation]

    init(locationId: UUID, store: EditorStore) {
        self.locationId = locationId
        self.store = store
        _locations = Query(filter: #Predicate<SDLocation> { $0.id == locationId })
    }

    var body: some View {
        if let sdLocation = locations.first {
            LocationDetailView(location: sdLocation, store: store)
        } else {
            ContentUnavailableView("Location not found", systemImage: "mappin")
        }
    }
}

struct LocationDetailView: View {
    let location: SDLocation
    var store: EditorStore

    var body: some View {
        SettingsContainer {
            // Header
            SettingsDetailHeader(
                title: location.name,
                subtitle: location.isActive ? "Active Location" : "Inactive Location",
                icon: "building.2"
            )

            // Stats
            HStack(spacing: 12) {
                SettingsStatCard(label: "Active Orders", value: "\(location.activeOrderCount)")
                SettingsStatCard(label: "Status", value: location.isActive ? "Active" : "Inactive")
            }

            // Address
            if location.address != nil || location.city != nil {
                SettingsGroup(header: "Address") {
                    VStack(alignment: .leading, spacing: 4) {
                        if let address = location.address {
                            Text(address)
                                .font(.subheadline)
                        }
                        if let city = location.city, let state = location.state {
                            Text("\(city), \(state)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                }
            }

            // Quick Actions
            SettingsGroup(header: "Actions") {
                SettingsLink(
                    label: "View Queue",
                    value: "\(location.activeOrderCount) orders",
                    destination: SDSidebarItem.queue(location.id)
                )
            }

            // Metadata
            SettingsGroup(header: "Metadata") {
                SettingsRow(label: "Location ID", value: String(location.id.uuidString.prefix(8)).uppercased(), mono: true)
            }
        }
        .navigationTitle(location.name)
    }
}

// MARK: - Customer Detail

struct CustomerDetailWrapper: View {
    let customerId: UUID
    var store: EditorStore

    var body: some View {
        if let customer = store.customers.first(where: { $0.id == customerId }) {
            CustomerDetailView(customer: customer, store: store)
        } else {
            ContentUnavailableView("Customer not found", systemImage: "person")
        }
    }
}

struct CustomerDetailView: View {
    let customer: Customer
    var store: EditorStore
    @State private var customerOrders: [Order] = []

    var body: some View {
        SettingsContainer {
            // Header with avatar
            VStack(spacing: 12) {
                Circle()
                    .fill(Color(nsColor: .tertiaryLabelColor))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Text(customer.initials)
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.white)
                    }

                Text(customer.displayName)
                    .font(.title2.weight(.semibold))

                if let tier = customer.loyaltyTier {
                    Text(tier.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)

            // Stats
            HStack(spacing: 12) {
                SettingsStatCard(label: "Total Spent", value: customer.formattedTotalSpent)
                SettingsStatCard(label: "Orders", value: "\(customer.totalOrders ?? 0)")
                SettingsStatCard(label: "Points", value: "\(customer.loyaltyPoints ?? 0)")
            }

            // Contact
            SettingsGroup(header: "Contact") {
                if let email = customer.email {
                    SettingsRow(label: "Email", value: email)
                }
                if let phone = customer.phone {
                    SettingsRow(label: "Phone", value: phone)
                        .settingsDivider()
                }
                if let dob = customer.dateOfBirth {
                    SettingsRow(label: "Birthday", value: dob)
                        .settingsDivider()
                }
            }

            // Address
            if customer.streetAddress != nil || customer.city != nil {
                SettingsGroup(header: "Address") {
                    VStack(alignment: .leading, spacing: 4) {
                        if let street = customer.streetAddress {
                            Text(street)
                                .font(.subheadline)
                        }
                        if let city = customer.city, let state = customer.state {
                            Text("\(city), \(state) \(customer.postalCode ?? "")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                }
            }

            // Account Settings
            SettingsGroup(header: "Account") {
                SettingsRow(label: "Loyalty Tier", value: customer.loyaltyTier?.capitalized ?? "None")
                SettingsBadgeRow(label: "ID Verified", badge: customer.idVerified == true ? "Verified" : "Not Verified", badgeColor: customer.idVerified == true ? .green : .orange)
                    .settingsDivider()
                SettingsBadgeRow(label: "Status", badge: customer.isActive != false ? "Active" : "Inactive", badgeColor: customer.isActive != false ? .green : .secondary)
                    .settingsDivider()
            }

            // Consent
            SettingsGroup(header: "Marketing Consent") {
                SettingsRow(label: "Email", value: customer.emailConsent == true ? "Opted In" : "Opted Out")
                SettingsRow(label: "SMS", value: customer.smsConsent == true ? "Opted In" : "Opted Out")
                    .settingsDivider()
            }

            // Recent Orders
            if !customerOrders.isEmpty {
                SettingsGroup(header: "Recent Orders") {
                    ForEach(Array(customerOrders.prefix(5).enumerated()), id: \.element.id) { index, order in
                        SettingsLink(
                            label: order.orderNumber,
                            value: order.displayTotal,
                            destination: SDSidebarItem.orderDetail(order.id)
                        )
                        .settingsDivider(if: index > 0)
                    }
                }
            }

            // Metadata
            SettingsGroup(header: "Metadata") {
                SettingsRow(label: "Customer ID", value: String(customer.id.uuidString.prefix(8)).uppercased(), mono: true)
                if let created = customer.createdAt {
                    SettingsRow(label: "Member Since", value: created.formatted(date: .abbreviated, time: .omitted))
                        .settingsDivider()
                }
            }
        }
        .navigationTitle("Customer")
        .task {
            customerOrders = store.orders.filter { $0.customerId == customer.id }
        }
    }
}

// MARK: - Creation Detail

struct CreationDetailWrapper: View {
    let creationId: UUID
    var store: EditorStore

    var body: some View {
        if let creation = store.creations.first(where: { $0.id == creationId }) {
            CreationEditorView(creation: creation, store: store)
        } else {
            ContentUnavailableView("Creation not found", systemImage: "wand.and.stars")
        }
    }
}

struct CreationEditorView: View {
    let creation: Creation
    var store: EditorStore
    @State private var selectedTab: CreationTab = .preview

    enum CreationTab: String, CaseIterable {
        case preview = "Preview"
        case code = "Code"
        case details = "Details"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(CreationTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.subheadline.weight(selectedTab == tab ? .medium : .regular))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Content
            switch selectedTab {
            case .preview:
                HotReloadRenderer(
                    code: store.editedCode ?? creation.reactCode ?? "",
                    creationId: creation.id.uuidString,
                    refreshTrigger: store.refreshTrigger
                )
            case .code:
                ScrollView {
                    Text(store.editedCode ?? creation.reactCode ?? "")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            case .details:
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        DetailSection(title: "Details") {
                            VStack(alignment: .leading, spacing: 8) {
                                DetailRow(label: "Name", value: creation.name)
                                DetailRow(label: "Type", value: creation.creationType.displayName)
                                DetailRow(label: "Status", value: creation.status?.rawValue.capitalized ?? "Draft")
                                DetailRow(label: "Slug", value: creation.slug, mono: true)
                                if let desc = creation.description {
                                    DetailRow(label: "Description", value: desc)
                                }
                            }
                        }

                        DetailSection(title: "Metadata") {
                            VStack(alignment: .leading, spacing: 8) {
                                DetailRow(label: "ID", value: String(creation.id.uuidString.prefix(8)).uppercased(), mono: true)
                                DetailRow(label: "Public", value: creation.isPublic == true ? "Yes" : "No")
                                DetailRow(label: "Featured", value: creation.isFeatured == true ? "Yes" : "No")
                                if let created = creation.createdAt {
                                    DetailRow(label: "Created", value: created.formatted(date: .abbreviated, time: .shortened))
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(creation.name)
        .onAppear {
            store.selectedCreation = creation
            store.editedCode = creation.reactCode
        }
    }
}

// MARK: - Browser Session Detail

struct BrowserSessionWrapper: View {
    let sessionId: UUID
    var store: EditorStore

    var body: some View {
        if let session = store.browserSessions.first(where: { $0.id == sessionId }) {
            BrowserSessionView(session: session, store: store)
        } else {
            ContentUnavailableView("Session not found", systemImage: "globe")
        }
    }
}

// MARK: - Email Detail

struct EmailDetailWrapper: View {
    let emailId: UUID
    var store: EditorStore

    var body: some View {
        if let email = store.emails.first(where: { $0.id == emailId }) {
            EmailDetailView(email: email)
        } else {
            ContentUnavailableView("Email not found", systemImage: "envelope")
        }
    }
}

struct EmailDetailView: View {
    let email: ResendEmail

    var body: some View {
        SettingsContainer {
            // Header
            SettingsDetailHeader(
                title: email.subject.isEmpty ? "No Subject" : email.subject,
                subtitle: "To: \(email.toEmail)",
                icon: "envelope"
            )

            // Status
            HStack(spacing: 12) {
                SettingsStatCard(label: "Status", value: email.statusLabel, color: email.statusColor)
            }

            // Details
            SettingsGroup(header: "Details") {
                SettingsRow(label: "To", value: email.toEmail)
                SettingsRow(label: "From", value: email.fromEmail)
                    .settingsDivider()
                SettingsBadgeRow(label: "Status", badge: email.statusLabel, badgeColor: email.statusColor)
                    .settingsDivider()
            }

            // Metadata
            SettingsGroup(header: "Metadata") {
                SettingsRow(label: "Email ID", value: String(email.id.uuidString.prefix(8)).uppercased(), mono: true)
            }
        }
        .navigationTitle("Email")
    }
}

// MARK: - Campaign Wrappers

struct EmailCampaignWrapper: View {
    let campaignId: UUID
    var store: EditorStore

    var body: some View {
        if let campaign = store.emailCampaigns.first(where: { $0.id == campaignId }) {
            EmailCampaignDetailPanel(campaign: campaign, store: store)
        } else {
            ContentUnavailableView("Campaign not found", systemImage: "envelope.badge")
        }
    }
}

struct MetaCampaignWrapper: View {
    let campaignId: UUID
    var store: EditorStore

    var body: some View {
        if let campaign = store.metaCampaigns.first(where: { $0.id == campaignId }) {
            MetaCampaignDetailPanel(campaign: campaign, store: store)
        } else {
            ContentUnavailableView("Campaign not found", systemImage: "megaphone")
        }
    }
}

struct MetaIntegrationWrapper: View {
    let integrationId: UUID
    var store: EditorStore

    var body: some View {
        if let integration = store.metaIntegrations.first(where: { $0.id == integrationId }) {
            MetaIntegrationDetailPanel(integration: integration, store: store)
        } else {
            ContentUnavailableView("Integration not found", systemImage: "link")
        }
    }
}

// MARK: - Agent Detail

struct AgentDetailWrapper: View {
    let agentId: UUID
    var store: EditorStore
    @Binding var selection: SDSidebarItem?

    var body: some View {
        if let agent = store.aiAgents.first(where: { $0.id == agentId }) {
            AgentConfigPanel(store: store, agent: agent, selection: $selection)
        } else {
            ContentUnavailableView("Agent not found", systemImage: "cpu")
        }
    }
}

// MARK: - Shared Components

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content()
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var mono: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(mono ? .system(.body, design: .monospaced) : .body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

struct DetailBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PricingRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(bold ? .headline : .body)
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(color)
        }
    }
}

struct StatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
