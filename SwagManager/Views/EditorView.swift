import SwiftUI
import WebKit
import Supabase

// MARK: - JSON Decoder Extension for Supabase
extension JSONDecoder {
    static var supabaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode date: \(dateString)")
            )
        }
        return decoder
    }
}

// MARK: - Main Editor View

struct EditorView: View {
    @StateObject private var store = EditorStore()
    @EnvironmentObject var authManager: AuthManager
    @State private var sidebarCollapsed = false
    @State private var selectedTab: EditorTab = .preview

    private let contentBg = Color(white: 0.08)

    var body: some View {
        HStack(spacing: 0) {
            // Collapsible Sidebar
            if !sidebarCollapsed {
                SidebarPanel(store: store, sidebarCollapsed: $sidebarCollapsed)
                    .frame(width: 220)
                    .background(contentBg)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
            }

            // Main Content Area with Tabs
            VStack(spacing: 0) {
                // Tab Bar (Safari/Xcode style)
                if !store.openTabs.isEmpty {
                    OpenTabBar(store: store)
                }

                // Content based on active tab or selection
                ZStack {
                    if let activeTab = store.activeTab {
                        switch activeTab {
                        case .creation(let creation):
                            // Creation editor
                            switch selectedTab {
                            case .preview:
                                HotReloadRenderer(
                                    code: store.editedCode ?? creation.reactCode ?? "",
                                    creationId: creation.id.uuidString,
                                    refreshTrigger: store.refreshTrigger
                                )
                            case .code:
                                CodeEditorPanel(
                                    code: Binding(
                                        get: { store.editedCode ?? store.selectedCreation?.reactCode ?? "" },
                                        set: { store.editedCode = $0 }
                                    ),
                                    onSave: { Task { await store.saveCurrentCreation() } }
                                )
                            case .details:
                                DetailsPanel(creation: creation, store: store)
                            case .settings:
                                SettingsPanel(creation: creation, store: store)
                            }

                        case .product(let product):
                            // Product editor
                            ProductEditorPanel(product: product, store: store)
                        }
                    } else if let product = store.selectedProduct {
                        // Show product even without tab
                        ProductEditorPanel(product: product, store: store)
                    } else if let creation = store.selectedCreation {
                        // Show creation even without tab
                        switch selectedTab {
                        case .preview:
                            HotReloadRenderer(
                                code: store.editedCode ?? creation.reactCode ?? "",
                                creationId: creation.id.uuidString,
                                refreshTrigger: store.refreshTrigger
                            )
                        case .code:
                            CodeEditorPanel(
                                code: Binding(
                                    get: { store.editedCode ?? creation.reactCode ?? "" },
                                    set: { store.editedCode = $0 }
                                ),
                                onSave: { Task { await store.saveCurrentCreation() } }
                            )
                        case .details:
                            DetailsPanel(creation: creation, store: store)
                        case .settings:
                            SettingsPanel(creation: creation, store: store)
                        }
                    } else {
                        // Welcome state
                        WelcomeView(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(contentBg)
        }
        .background(contentBg)
        .animation(.easeOut(duration: 0.15), value: sidebarCollapsed)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { sidebarCollapsed.toggle() }
                } label: {
                    Image(systemName: sidebarCollapsed ? "sidebar.left" : "sidebar.leading")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
            }

            ToolbarItemGroup(placement: .principal) {
                HStack(spacing: 0) {
                    ForEach(EditorTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeOut(duration: 0.1)) { selectedTab = tab }
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 9))
                                Text(tab.rawValue)
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(selectedTab == tab ? .primary : .tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if let creation = store.selectedCreation {
                    HStack(spacing: 4) {
                        if store.hasUnsavedChanges {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 5, height: 5)
                        }
                        Text(creation.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Button {
                        Task { await store.saveCurrentCreation() }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("s", modifiers: .command)
                }
            }
        }
        .task {
            await store.loadCreations()
            // RLS handles filtering - just load stores
            await store.loadStores()
            await store.loadCatalog()
        }
        .sheet(isPresented: $store.showNewCreationSheet) {
            NewCreationSheet(store: store)
        }
        .sheet(isPresented: $store.showNewCollectionSheet) {
            NewCollectionSheet(store: store)
        }
        .sheet(isPresented: $store.showNewStoreSheet) {
            NewStoreSheet(store: store, authManager: authManager)
        }
        .alert("Error", isPresented: Binding(
            get: { store.error != nil },
            set: { if !$0 { store.error = nil } }
        )) {
            Button("OK") { store.error = nil }
        } message: {
            Text(store.error ?? "")
        }
    }
}

enum EditorTab: String, CaseIterable {
    case preview = "Preview"
    case code = "Code"
    case details = "Details"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .preview: return "play.display"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .details: return "info.circle"
        case .settings: return "gear"
        }
    }
}

// MARK: - Open Tab Model (Safari/Xcode style tabs)

enum OpenTabItem: Identifiable, Hashable {
    case creation(Creation)
    case product(Product)

    var id: String {
        switch self {
        case .creation(let c): return "creation-\(c.id)"
        case .product(let p): return "product-\(p.id)"
        }
    }

    var name: String {
        switch self {
        case .creation(let c): return c.name
        case .product(let p): return p.name
        }
    }

    var icon: String {
        switch self {
        case .creation(let c):
            switch c.creationType {
            case .app: return "app.badge"
            case .display: return "display"
            case .email: return "envelope"
            case .landing: return "globe"
            case .dashboard: return "chart.bar.xaxis"
            case .artifact: return "cube"
            case .store: return "storefront"
            }
        case .product: return "leaf"
        }
    }

    var iconColor: Color {
        switch self {
        case .creation(let c): return c.creationType.color
        case .product: return .green
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: OpenTabItem, rhs: OpenTabItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Editor Store

@MainActor
class EditorStore: ObservableObject {
    // MARK: - Creations State
    @Published var creations: [Creation] = []
    @Published var collections: [CreationCollection] = []
    @Published var collectionItems: [UUID: [UUID]] = [:] // collectionId -> [creationId]
    @Published var selectedCreation: Creation?
    @Published var selectedCreationIds: Set<UUID> = []
    @Published var editedCode: String?

    // MARK: - Catalog State (Products, Categories & Stores)
    @Published var stores: [Store] = []
    @Published var selectedStore: Store?
    @Published var products: [Product] = []
    @Published var categories: [Category] = []
    @Published var selectedProduct: Product?
    @Published var selectedProductIds: Set<UUID> = []

    // MARK: - Tabs (Safari/Xcode style)
    @Published var openTabs: [OpenTabItem] = []
    @Published var activeTab: OpenTabItem?

    // MARK: - UI State
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var refreshTrigger = UUID()
    @Published var error: String?
    @Published var sidebarCreationsExpanded = true
    @Published var sidebarCatalogExpanded = true

    // Sheet states
    @Published var showNewCreationSheet = false
    @Published var showNewCollectionSheet = false
    @Published var showNewStoreSheet = false

    var lastSelectedIndex: Int?

    private let supabase = SupabaseService.shared
    private var realtimeTask: Task<Void, Never>?

    // Default store ID for new items
    let defaultStoreId = UUID(uuidString: "cd2e1122-d511-4edb-be5d-98ef274b4baf")!

    init() {
        startRealtimeSubscription()
    }

    deinit {
        realtimeTask?.cancel()
    }

    // MARK: - Realtime Subscriptions

    private func startRealtimeSubscription() {
        realtimeTask = Task { [weak self] in
            guard let self = self else { return }

            let client = self.supabase.client

            // Subscribe to all changes on one channel
            let channel = client.realtimeV2.channel("swag-manager-changes")

            // Creations table
            let creationsInserts = channel.postgresChange(InsertAction.self, table: "creations")
            let creationsUpdates = channel.postgresChange(UpdateAction.self, table: "creations")
            let creationsDeletes = channel.postgresChange(DeleteAction.self, table: "creations")

            // Collections table
            let collectionsInserts = channel.postgresChange(InsertAction.self, table: "creation_collections")
            let collectionsUpdates = channel.postgresChange(UpdateAction.self, table: "creation_collections")
            let collectionsDeletes = channel.postgresChange(DeleteAction.self, table: "creation_collections")

            // Collection items table
            let collectionItemsInserts = channel.postgresChange(InsertAction.self, table: "creation_collection_items")
            let collectionItemsDeletes = channel.postgresChange(DeleteAction.self, table: "creation_collection_items")

            do {
                await channel.subscribe()
                NSLog("[EditorStore] Realtime: Successfully subscribed to channel")
            }

            // Keep processing events in parallel
            await withTaskGroup(of: Void.self) { group in
                // Handle creations inserts
                group.addTask {
                    for await insert in creationsInserts {
                        NSLog("[EditorStore] Realtime: creation INSERT received")
                        await MainActor.run {
                            if let creation = try? insert.decodeRecord(as: Creation.self, decoder: JSONDecoder.supabaseDecoder) {
                                if !self.creations.contains(where: { $0.id == creation.id }) {
                                    self.creations.insert(creation, at: 0)
                                    NSLog("[EditorStore] Realtime: Added creation '\(creation.name)'")
                                }
                            } else {
                                NSLog("[EditorStore] Realtime: Failed to decode creation, reloading all")
                                Task { await self.loadCreations() }
                            }
                        }
                    }
                }

                // Handle creations updates
                group.addTask {
                    for await update in creationsUpdates {
                        NSLog("[EditorStore] Realtime: creation UPDATE received")
                        await MainActor.run {
                            if let creation = try? update.decodeRecord(as: Creation.self, decoder: JSONDecoder.supabaseDecoder) {
                                if let idx = self.creations.firstIndex(where: { $0.id == creation.id }) {
                                    self.creations[idx] = creation
                                    NSLog("[EditorStore] Realtime: Updated creation '\(creation.name)'")
                                    if self.selectedCreation?.id == creation.id {
                                        self.selectedCreation = creation
                                        // Don't overwrite editedCode if user has local changes
                                        if self.editedCode == nil || !self.hasUnsavedChanges {
                                            self.editedCode = creation.reactCode
                                        }
                                        self.refreshTrigger = UUID()
                                    }
                                }
                            }
                        }
                    }
                }

                // Handle creations deletes
                group.addTask {
                    for await delete in creationsDeletes {
                        NSLog("[EditorStore] Realtime: creation DELETE received")
                        await MainActor.run {
                            let oldRecord = delete.oldRecord
                            if let idString = oldRecord["id"]?.stringValue,
                               let id = UUID(uuidString: idString) {
                                self.creations.removeAll { $0.id == id }
                                self.selectedCreationIds.remove(id)
                                if self.selectedCreation?.id == id {
                                    self.selectedCreation = nil
                                    self.editedCode = nil
                                }
                                NSLog("[EditorStore] Realtime: Removed creation \(idString)")
                            }
                        }
                    }
                }

                // Handle collections inserts
                group.addTask {
                    for await insert in collectionsInserts {
                        NSLog("[EditorStore] Realtime: collection INSERT received")
                        await MainActor.run {
                            if let collection = try? insert.decodeRecord(as: CreationCollection.self, decoder: JSONDecoder.supabaseDecoder) {
                                if !self.collections.contains(where: { $0.id == collection.id }) {
                                    self.collections.insert(collection, at: 0)
                                    NSLog("[EditorStore] Realtime: Added collection '\(collection.name)'")
                                }
                            } else {
                                NSLog("[EditorStore] Realtime: Failed to decode collection, reloading")
                                Task {
                                    self.collections = try await self.supabase.fetchCollections()
                                }
                            }
                        }
                    }
                }

                // Handle collections updates
                group.addTask {
                    for await update in collectionsUpdates {
                        NSLog("[EditorStore] Realtime: collection UPDATE received")
                        await MainActor.run {
                            if let collection = try? update.decodeRecord(as: CreationCollection.self, decoder: JSONDecoder.supabaseDecoder) {
                                if let idx = self.collections.firstIndex(where: { $0.id == collection.id }) {
                                    self.collections[idx] = collection
                                    NSLog("[EditorStore] Realtime: Updated collection '\(collection.name)'")
                                }
                            }
                        }
                    }
                }

                // Handle collections deletes
                group.addTask {
                    for await delete in collectionsDeletes {
                        NSLog("[EditorStore] Realtime: collection DELETE received")
                        await MainActor.run {
                            let oldRecord = delete.oldRecord
                            if let idString = oldRecord["id"]?.stringValue,
                               let id = UUID(uuidString: idString) {
                                self.collections.removeAll { $0.id == id }
                                self.collectionItems.removeValue(forKey: id)
                                NSLog("[EditorStore] Realtime: Removed collection \(idString)")
                            }
                        }
                    }
                }

                // Handle collection items inserts
                group.addTask {
                    for await insert in collectionItemsInserts {
                        NSLog("[EditorStore] Realtime: collection_item INSERT received")
                        await MainActor.run {
                            let record = insert.record
                            if let collectionIdStr = record["collection_id"]?.stringValue,
                               let creationIdStr = record["creation_id"]?.stringValue,
                               let collectionId = UUID(uuidString: collectionIdStr),
                               let creationId = UUID(uuidString: creationIdStr) {
                                if self.collectionItems[collectionId] == nil {
                                    self.collectionItems[collectionId] = []
                                }
                                if !self.collectionItems[collectionId]!.contains(creationId) {
                                    self.collectionItems[collectionId]!.append(creationId)
                                    NSLog("[EditorStore] Realtime: Added item to collection")
                                }
                            }
                        }
                    }
                }

                // Handle collection items deletes
                group.addTask {
                    for await delete in collectionItemsDeletes {
                        NSLog("[EditorStore] Realtime: collection_item DELETE received")
                        await MainActor.run {
                            let oldRecord = delete.oldRecord
                            if let collectionIdStr = oldRecord["collection_id"]?.stringValue,
                               let creationIdStr = oldRecord["creation_id"]?.stringValue,
                               let collectionId = UUID(uuidString: collectionIdStr),
                               let creationId = UUID(uuidString: creationIdStr) {
                                self.collectionItems[collectionId]?.removeAll { $0 == creationId }
                                NSLog("[EditorStore] Realtime: Removed item from collection")
                            }
                        }
                    }
                }
            }
        }
    }

    var hasUnsavedChanges: Bool {
        guard let edited = editedCode, let original = selectedCreation?.reactCode else { return false }
        return edited != original
    }

    var selectedCreations: [Creation] {
        creations.filter { selectedCreationIds.contains($0.id) }
    }

    // Get creations for a specific collection
    func creationsForCollection(_ collectionId: UUID) -> [Creation] {
        guard let creationIds = collectionItems[collectionId] else { return [] }
        return creations.filter { creationIds.contains($0.id) }
    }

    // Get creations not in any collection
    var orphanCreations: [Creation] {
        let allCollectionCreationIds = Set(collectionItems.values.flatMap { $0 })
        return creations.filter { !allCollectionCreationIds.contains($0.id) }
    }

    func loadCreations() async {
        isLoading = true
        do {
            creations = try await supabase.fetchCreations()
        } catch {
            print("Error loading creations: \(error)")
            self.error = "Failed to load creations: \(error.localizedDescription)"
        }

        // Load collections separately so one failure doesn't block the other
        do {
            NSLog("[EditorStore] Fetching collections...")
            collections = try await supabase.fetchCollections()
            NSLog("[EditorStore] Loaded %d collections", collections.count)

            // Load all collection items
            var itemsMap: [UUID: [UUID]] = [:]
            for collection in collections {
                let items = try await supabase.fetchCollectionItems(collectionId: collection.id)
                itemsMap[collection.id] = items.map { $0.creationId }
            }
            collectionItems = itemsMap
            NSLog("[EditorStore] Loaded collection items for %d collections", itemsMap.count)
        } catch {
            NSLog("[EditorStore] Error loading collections: %@", String(describing: error))
            // Don't override error if creations also failed
            if self.error == nil {
                self.error = "Failed to load collections: \(error.localizedDescription)"
            }
        }
        isLoading = false
    }

    func selectCreation(_ creation: Creation, add: Bool = false, range: Bool = false, in list: [Creation] = []) {
        if range, let lastIdx = lastSelectedIndex, let currentIdx = list.firstIndex(where: { $0.id == creation.id }) {
            // Shift+click: select range
            let start = min(lastIdx, currentIdx)
            let end = max(lastIdx, currentIdx)
            for i in start...end {
                selectedCreationIds.insert(list[i].id)
            }
        } else if add {
            // Cmd+click: toggle selection
            if selectedCreationIds.contains(creation.id) {
                selectedCreationIds.remove(creation.id)
                if selectedCreation?.id == creation.id {
                    selectedCreation = selectedCreations.first
                    editedCode = selectedCreation?.reactCode
                }
            } else {
                selectedCreationIds.insert(creation.id)
            }
        } else {
            // Normal click: single select
            selectedCreationIds = [creation.id]
        }

        // Update active creation for editing
        if selectedCreationIds.contains(creation.id) {
            selectedCreation = creation
            editedCode = creation.reactCode
            selectedProduct = nil
            selectedProductIds.removeAll()
            lastSelectedIndex = list.firstIndex(where: { $0.id == creation.id })
            openTab(.creation(creation))
        }
    }

    func clearSelection() {
        selectedCreationIds.removeAll()
        selectedCreation = nil
        editedCode = nil
        lastSelectedIndex = nil
    }

    func saveCurrentCreation() async {
        guard let creation = selectedCreation, let code = editedCode else { return }
        isSaving = true
        do {
            let update = CreationUpdate(reactCode: code)
            let updated = try await supabase.updateCreation(id: creation.id, update: update)
            selectedCreation = updated
            editedCode = updated.reactCode
            refreshTrigger = UUID()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func updateCreationSettings(id: UUID, status: CreationStatus? = nil, isPublic: Bool? = nil, visibility: String? = nil, name: String? = nil, description: String? = nil) async {
        isSaving = true
        do {
            let update = CreationUpdate(name: name, description: description, status: status, isPublic: isPublic, visibility: visibility)
            let updated = try await supabase.updateCreation(id: id, update: update)
            if let idx = creations.firstIndex(where: { $0.id == id }) {
                creations[idx] = updated
            }
            if selectedCreation?.id == id {
                selectedCreation = updated
            }
            refreshTrigger = UUID()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func deleteCreation(_ creation: Creation) async {
        do {
            try await supabase.deleteCreation(id: creation.id)
            if selectedCreation?.id == creation.id {
                selectedCreation = nil
                editedCode = nil
            }
            selectedCreationIds.remove(creation.id)
            await loadCreations()
        } catch {
            print("Delete failed for \(creation.name): \(error)")
            self.error = "Failed to delete '\(creation.name)': \(error.localizedDescription)"
        }
    }

    func deleteSelectedCreations() async {
        let idsToDelete = selectedCreationIds
        var failedCount = 0
        var errors: [String] = []

        for id in idsToDelete {
            do {
                try await supabase.deleteCreation(id: id)
            } catch {
                failedCount += 1
                errors.append(error.localizedDescription)
            }
        }

        // Clear selection
        selectedCreationIds.removeAll()
        selectedCreation = nil
        editedCode = nil
        lastSelectedIndex = nil

        // Reload once at the end
        await loadCreations()

        // Report errors if any
        if failedCount > 0 {
            self.error = "Failed to delete \(failedCount) item(s): \(errors.first ?? "Unknown error")"
        }
    }

    func triggerRefresh() {
        refreshTrigger = UUID()
    }

    // MARK: - Create Functions

    func createCreation(name: String, type: CreationType, description: String?) async {
        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let insert = CreationInsert(
            creationType: type,
            name: name,
            slug: slug,
            description: description,
            status: .draft,
            reactCode: defaultReactCode(for: type, name: name)
        )

        do {
            let created = try await supabase.createCreation(insert)
            await loadCreations()
            selectCreation(created, in: creations)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createCollection(name: String, description: String?) async {
        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let insert = CollectionInsert(
            storeId: defaultStoreId,
            name: name,
            slug: slug,
            description: description,
            isPublic: false
        )

        do {
            _ = try await supabase.createCollection(insert)
            collections = try await supabase.fetchCollections()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteCollection(_ collection: CreationCollection) async {
        do {
            try await supabase.deleteCollection(id: collection.id)
            collections = try await supabase.fetchCollections()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func defaultReactCode(for type: CreationType, name: String) -> String {
        """
        const App = () => {
          return (
            <div className="min-h-screen bg-black text-white flex items-center justify-center">
              <div className="text-center">
                <h1 className="text-4xl font-bold mb-4">\(name)</h1>
                <p className="text-gray-400">Start building your \(type.displayName.lowercased())</p>
              </div>
            </div>
          );
        };
        """
    }

    // MARK: - Catalog (Products, Categories & Stores)

    func loadStores() async {
        do {
            // Check if user is authenticated first
            let session = try? await supabase.client.auth.session
            NSLog("[EditorStore] Auth session: %@", session != nil ? "authenticated" : "NOT authenticated")

            // RLS automatically filters to stores the user owns/works at
            stores = try await supabase.fetchStores()
            NSLog("[EditorStore] Loaded %d stores", stores.count)
            // Auto-select first store if none selected
            if selectedStore == nil, let first = stores.first {
                selectedStore = first
                NSLog("[EditorStore] Auto-selected store: %@", first.storeName)
            }
        } catch {
            NSLog("[EditorStore] Error loading stores: %@", String(describing: error))
            self.error = "Failed to load stores: \(error.localizedDescription)"
        }
    }

    func selectStore(_ store: Store) async {
        selectedStore = store
        // Reload catalog for new store
        await loadCatalog()
    }

    func createStore(name: String, email: String, ownerUserId: UUID?) async {
        do {
            let slug = name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

            let insert = StoreInsert(
                storeName: name,
                slug: slug,
                email: email,
                ownerUserId: ownerUserId,
                status: "active",
                storeType: "standard"
            )

            let newStore = try await supabase.createStore(insert)
            stores.append(newStore)
            selectedStore = newStore
            await loadCatalog()
            NSLog("[EditorStore] Created store: %@", name)
        } catch {
            NSLog("[EditorStore] Error creating store: %@", String(describing: error))
            self.error = "Failed to create store: \(error.localizedDescription)"
        }
    }

    /// Current store ID for catalog queries
    var currentStoreId: UUID {
        selectedStore?.id ?? defaultStoreId
    }

    func loadCatalog() async {
        do {
            categories = try await supabase.fetchCategories(storeId: currentStoreId)
            products = try await supabase.fetchProducts(storeId: currentStoreId)
            NSLog("[EditorStore] Loaded %d categories, %d products for store %@", categories.count, products.count, selectedStore?.storeName ?? "default")
        } catch {
            NSLog("[EditorStore] Error loading catalog: %@", String(describing: error))
            if self.error == nil {
                self.error = "Failed to load catalog: \(error.localizedDescription)"
            }
        }
    }

    func productsForCategory(_ categoryId: UUID) -> [Product] {
        products.filter { $0.primaryCategoryId == categoryId }
    }

    var uncategorizedProducts: [Product] {
        products.filter { $0.primaryCategoryId == nil }
    }

    // MARK: - Category Hierarchy Helpers

    /// Top-level categories (no parent)
    var topLevelCategories: [Category] {
        categories.filter { $0.parentId == nil }
    }

    /// Get child categories for a given parent
    func childCategories(of parentId: UUID) -> [Category] {
        categories.filter { $0.parentId == parentId }
    }

    /// Check if category has children
    func hasChildCategories(_ categoryId: UUID) -> Bool {
        categories.contains { $0.parentId == categoryId }
    }

    /// Get all descendant category IDs (recursive)
    func allDescendantCategoryIds(of parentId: UUID) -> Set<UUID> {
        var result = Set<UUID>()
        let children = childCategories(of: parentId)
        for child in children {
            result.insert(child.id)
            result.formUnion(allDescendantCategoryIds(of: child.id))
        }
        return result
    }

    /// Get products in a category and all its subcategories
    func productsInCategoryTree(_ categoryId: UUID) -> [Product] {
        var categoryIds = Set([categoryId])
        categoryIds.formUnion(allDescendantCategoryIds(of: categoryId))
        return products.filter { product in
            guard let catId = product.primaryCategoryId else { return false }
            return categoryIds.contains(catId)
        }
    }

    /// Count of direct products in category (not including subcategories)
    func directProductCount(_ categoryId: UUID) -> Int {
        products.filter { $0.primaryCategoryId == categoryId }.count
    }

    /// Total count including all subcategory products
    func totalProductCount(_ categoryId: UUID) -> Int {
        productsInCategoryTree(categoryId).count
    }

    func selectProduct(_ product: Product) {
        selectedProduct = product
        selectedProductIds = [product.id]
        selectedCreation = nil
        selectedCreationIds.removeAll()
        openTab(.product(product))
    }

    func deleteProduct(_ product: Product) async {
        do {
            try await supabase.deleteProduct(id: product.id)
            if selectedProduct?.id == product.id {
                selectedProduct = nil
                closeTab(.product(product))
            }
            selectedProductIds.remove(product.id)
            await loadCatalog()
        } catch {
            self.error = "Failed to delete '\(product.name)': \(error.localizedDescription)"
        }
    }

    func updateProductField(id: UUID, field: String, value: Any?) async {
        isSaving = true
        do {
            var update = ProductUpdate()
            switch field {
            case "name": update.name = value as? String
            case "description": update.description = value as? String
            case "sku": update.sku = value as? String
            case "status": update.status = value as? String
            case "price": update.price = value as? Double
            case "regularPrice": update.regularPrice = value as? Double
            case "salePrice": update.salePrice = value as? Double
            case "stockQuantity": update.stockQuantity = value as? Double
            case "stockStatus": update.stockStatus = value as? String
            default: break
            }
            let updated = try await supabase.updateProduct(id: id, update: update)
            if let idx = products.firstIndex(where: { $0.id == id }) {
                products[idx] = updated
            }
            if selectedProduct?.id == id {
                selectedProduct = updated
                // Update in open tabs
                if let tabIdx = openTabs.firstIndex(where: {
                    if case .product(let p) = $0 { return p.id == id }
                    return false
                }) {
                    openTabs[tabIdx] = .product(updated)
                    if case .product = activeTab { activeTab = .product(updated) }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    // MARK: - Tab Management

    func openTab(_ item: OpenTabItem) {
        if !openTabs.contains(where: { $0.id == item.id }) {
            openTabs.append(item)
        }
        activeTab = item
    }

    func closeTab(_ item: OpenTabItem) {
        openTabs.removeAll { $0.id == item.id }
        if activeTab?.id == item.id {
            activeTab = openTabs.last
            // Update selection based on active tab
            if let tab = activeTab {
                switch tab {
                case .creation(let c):
                    selectedCreation = c
                    editedCode = c.reactCode
                    selectedProduct = nil
                case .product(let p):
                    selectedProduct = p
                    selectedCreation = nil
                    editedCode = nil
                }
            } else {
                selectedCreation = nil
                selectedProduct = nil
                editedCode = nil
            }
        }
    }

    func switchToTab(_ item: OpenTabItem) {
        activeTab = item
        switch item {
        case .creation(let c):
            selectedCreation = c
            editedCode = c.reactCode
            selectedProduct = nil
        case .product(let p):
            selectedProduct = p
            selectedCreation = nil
            editedCode = nil
        }
    }
}

// MARK: - Open Tab Bar (Safari/Xcode style)

struct OpenTabBar: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(store.openTabs) { tab in
                    OpenTabButton(
                        tab: tab,
                        isActive: store.activeTab?.id == tab.id,
                        hasUnsavedChanges: tabHasUnsavedChanges(tab),
                        onSelect: { store.switchToTab(tab) },
                        onClose: { store.closeTab(tab) }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 28)
        .background(Color(white: 0.06))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func tabHasUnsavedChanges(_ tab: OpenTabItem) -> Bool {
        if case .creation(let c) = tab, c.id == store.selectedCreation?.id {
            return store.hasUnsavedChanges
        }
        return false
    }
}

struct OpenTabButton: View {
    let tab: OpenTabItem
    let isActive: Bool
    let hasUnsavedChanges: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tab.icon)
                .font(.system(size: 9))
                .foregroundStyle(tab.iconColor)

            Text(tab.name)
                .font(.system(size: 11))
                .lineLimit(1)

            if hasUnsavedChanges {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isActive ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? Color.white.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isActive ? Color.white.opacity(0.1) : Color.clear, lineWidth: 1)
        )
        .foregroundStyle(isActive ? .primary : .secondary)
        .onHover { isHovering = $0 }
        .onTapGesture { onSelect() }
    }
}

// MARK: - Product Editor Panel

struct ProductEditorPanel: View {
    let product: Product
    @ObservedObject var store: EditorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    if let imageUrl = product.featuredImage, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "leaf")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.tertiary)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.title2.bold())
                        if let sku = product.sku {
                            Text("SKU: \(sku)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 8) {
                            Text(product.displayPrice)
                                .font(.headline)
                                .foregroundStyle(.green)
                            Text(product.stockStatusLabel)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(product.stockStatusColor.opacity(0.2))
                                .foregroundStyle(product.stockStatusColor)
                                .clipShape(Capsule())
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Details Section
                GroupBox("Details") {
                    VStack(alignment: .leading, spacing: 12) {
                        ProductFieldRow(label: "Name", value: product.name)
                        ProductFieldRow(label: "SKU", value: product.sku ?? "-")
                        ProductFieldRow(label: "Status", value: product.status ?? "draft")
                        ProductFieldRow(label: "Type", value: product.type ?? "simple")
                    }
                }

                // Pricing Section
                GroupBox("Pricing") {
                    VStack(alignment: .leading, spacing: 12) {
                        ProductFieldRow(label: "Regular Price", value: product.regularPrice.map { String(format: "$%.2f", $0) } ?? "-")
                        ProductFieldRow(label: "Sale Price", value: product.salePrice.map { String(format: "$%.2f", $0) } ?? "-")
                        ProductFieldRow(label: "Cost Price", value: product.costPrice.map { String(format: "$%.2f", $0) } ?? "-")
                    }
                }

                // Inventory Section
                GroupBox("Inventory") {
                    VStack(alignment: .leading, spacing: 12) {
                        ProductFieldRow(label: "Stock Status", value: product.stockStatusLabel)
                        ProductFieldRow(label: "Stock Quantity", value: product.stockQuantity.map { String(format: "%.0f", $0) } ?? "-")
                        ProductFieldRow(label: "Manage Stock", value: (product.manageStock ?? false) ? "Yes" : "No")
                    }
                }

                // Description
                if let description = product.description, !description.isEmpty {
                    GroupBox("Description") {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .background(Color(white: 0.08))
    }
}

struct ProductFieldRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12))
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Select an item from the sidebar")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Or create something new")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            HStack(spacing: 12) {
                Button {
                    store.showNewCreationSheet = true
                } label: {
                    Label("New Creation", systemImage: "plus.square")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.showNewCollectionSheet = true
                } label: {
                    Label("New Collection", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)

            // Quick stats
            if !store.creations.isEmpty || !store.products.isEmpty {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.vertical, 12)

                    HStack(spacing: 24) {
                        VStack {
                            Text("\(store.creations.count)")
                                .font(.title2.bold())
                            Text("Creations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text("\(store.products.count)")
                                .font(.title2.bold())
                            Text("Products")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text("\(store.categories.count)")
                                .font(.title2.bold())
                            Text("Categories")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.08))
    }
}

// MARK: - Sidebar Panel

struct SidebarPanel: View {
    @ObservedObject var store: EditorStore
    @Binding var sidebarCollapsed: Bool
    @State private var searchText = ""
    @State private var expandedCollectionIds: Set<UUID> = []
    @State private var expandedCategoryIds: Set<UUID> = []

    var filteredCreations: [Creation] {
        if searchText.isEmpty { return store.creations }
        return store.creations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredOrphanCreations: [Creation] {
        if searchText.isEmpty { return store.orphanCreations }
        return store.orphanCreations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func filteredCreationsForCollection(_ collectionId: UUID) -> [Creation] {
        let creations = store.creationsForCollection(collectionId)
        if searchText.isEmpty { return creations }
        return creations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Store Switcher (Top-level environment)
            StoreEnvironmentHeader(store: store)

            Divider()
                .background(Color.white.opacity(0.1))

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(white: 0.12))
            .cornerRadius(4)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // Content tree (only show if store is selected)
            if store.selectedStore == nil && store.stores.isEmpty {
                // No stores - prompt to create
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "storefront")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No Store Selected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Create a store to get started")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Button {
                        store.showNewStoreSheet = true
                    } label: {
                        Label("Create Store", systemImage: "plus")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if store.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // MARK: CATALOG Section
                        TreeSectionHeader(
                            title: "CATALOG",
                            isExpanded: $store.sidebarCatalogExpanded,
                            count: store.products.count
                        )

                        if store.sidebarCatalogExpanded {
                            // Show only top-level categories first
                            ForEach(store.topLevelCategories) { category in
                                CategoryHierarchyView(
                                    category: category,
                                    store: store,
                                    expandedCategoryIds: $expandedCategoryIds,
                                    indentLevel: 0
                                )
                            }

                            // Uncategorized products at the bottom
                            if !store.uncategorizedProducts.isEmpty {
                                ForEach(store.uncategorizedProducts) { product in
                                    ProductTreeItem(
                                        product: product,
                                        isSelected: store.selectedProductIds.contains(product.id),
                                        isActive: store.selectedProduct?.id == product.id,
                                        indentLevel: 0
                                    )
                                    .onTapGesture {
                                        store.selectProduct(product)
                                    }
                                    .contextMenu {
                                        Button("Delete", role: .destructive) {
                                            Task { await store.deleteProduct(product) }
                                        }
                                    }
                                }
                            }

                            // Empty state for catalog
                            if store.categories.isEmpty && store.products.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("No products yet")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }

                        // MARK: CREATIONS Section
                        TreeSectionHeader(
                            title: "CREATIONS",
                            isExpanded: $store.sidebarCreationsExpanded,
                            count: store.creations.count
                        )
                        .padding(.top, 8)

                        if store.sidebarCreationsExpanded {
                            // Collections as folders with their creations inside
                            ForEach(store.collections) { collection in
                                let isExpanded = expandedCollectionIds.contains(collection.id)
                                let collectionCreations = filteredCreationsForCollection(collection.id)

                                CollectionTreeItem(
                                    collection: collection,
                                    isExpanded: isExpanded,
                                    itemCount: collectionCreations.count,
                                    onToggle: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            if expandedCollectionIds.contains(collection.id) {
                                                expandedCollectionIds.remove(collection.id)
                                            } else {
                                                expandedCollectionIds.insert(collection.id)
                                            }
                                        }
                                    }
                                )
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        Task { await store.deleteCollection(collection) }
                                    }
                                }

                                if isExpanded {
                                    ForEach(collectionCreations) { creation in
                                        CreationTreeItem(
                                            creation: creation,
                                            isSelected: store.selectedCreationIds.contains(creation.id),
                                            isActive: store.selectedCreation?.id == creation.id,
                                            indentLevel: 1
                                        )
                                        .onTapGesture {
                                            store.selectCreation(creation, in: store.creations)
                                        }
                                        .contextMenu {
                                            Button("Delete", role: .destructive) {
                                                Task { await store.deleteCreation(creation) }
                                            }
                                        }
                                    }
                                }
                            }

                            // Orphan creations (not in any collection)
                            ForEach(filteredOrphanCreations) { creation in
                                CreationTreeItem(
                                    creation: creation,
                                    isSelected: store.selectedCreationIds.contains(creation.id),
                                    isActive: store.selectedCreation?.id == creation.id,
                                    indentLevel: 0
                                )
                                .onTapGesture {
                                    store.selectCreation(creation, in: store.creations)
                                }
                                .contextMenu {
                                    if store.selectedCreationIds.count > 1 {
                                        Button("Delete \(store.selectedCreationIds.count) items", role: .destructive) {
                                            Task { await store.deleteSelectedCreations() }
                                        }
                                    } else {
                                        Button("Delete", role: .destructive) {
                                            Task { await store.deleteCreation(creation) }
                                        }
                                    }
                                }
                            }

                            // Empty state for creations
                            if store.creations.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 4) {
                                        Text("No creations yet")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                        Button {
                                            store.showNewCreationSheet = true
                                        } label: {
                                            Text("Create one")
                                                .font(.system(size: 10))
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.blue)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(Color(white: 0.03))
    }
}

// MARK: - Store Environment Header (Slack/Discord style workspace switcher)

struct StoreEnvironmentHeader: View {
    @ObservedObject var store: EditorStore
    @State private var isHovering = false

    var body: some View {
        Menu {
            // Current stores
            if !store.stores.isEmpty {
                Section("Your Stores") {
                    ForEach(store.stores) { s in
                        Button {
                            Task { await store.selectStore(s) }
                        } label: {
                            HStack {
                                if let logoUrl = s.logoUrl, let url = URL(string: logoUrl) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "storefront.fill")
                                    }
                                    .frame(width: 16, height: 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                } else {
                                    Image(systemName: "storefront.fill")
                                        .frame(width: 16, height: 16)
                                }
                                Text(s.storeName)
                                Spacer()
                                if store.selectedStore?.id == s.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Divider()
            }

            // Create new store
            Button {
                store.showNewStoreSheet = true
            } label: {
                Label("Create New Store", systemImage: "plus.circle")
            }

            // Store settings (if store selected)
            if store.selectedStore != nil {
                Divider()
                Button {
                    // TODO: Open store settings
                } label: {
                    Label("Store Settings", systemImage: "gear")
                }
            }
        } label: {
            HStack(spacing: 8) {
                // Store icon/logo
                if let selectedStore = store.selectedStore {
                    if let logoUrl = selectedStore.logoUrl, let url = URL(string: logoUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            storeIconPlaceholder
                        }
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        storeIconPlaceholder
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(selectedStore.storeName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(selectedStore.storeType?.capitalized ?? "Store")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    storeIconPlaceholder

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Select Store")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("No store selected")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isHovering ? Color.white.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var storeIconPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.green.opacity(0.2))
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: "storefront.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            )
    }
}


// MARK: - Category Hierarchy View (Recursive)

struct CategoryHierarchyView: View {
    let category: Category
    @ObservedObject var store: EditorStore
    @Binding var expandedCategoryIds: Set<UUID>
    var indentLevel: Int = 0

    @State private var isHovering = false

    private var isExpanded: Bool {
        expandedCategoryIds.contains(category.id)
    }

    private var childCategories: [Category] {
        store.childCategories(of: category.id)
    }

    private var directProducts: [Product] {
        store.productsForCategory(category.id)
    }

    private var hasChildren: Bool {
        !childCategories.isEmpty || !directProducts.isEmpty
    }

    private var totalCount: Int {
        store.totalProductCount(category.id)
    }

    private var directCount: Int {
        store.directProductCount(category.id)
    }

    private var subCategoryCount: Int {
        childCategories.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header row
            HStack(spacing: 4) {
                // Chevron - only show if has children
                if hasChildren {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }

                // Folder icon
                Image(systemName: category.icon ?? (isExpanded ? "folder.fill" : "folder"))
                    .font(.system(size: 10))
                    .foregroundStyle(isHovering ? .green : .green.opacity(0.8))
                    .frame(width: 14)

                Text(category.name)
                    .font(.system(size: 11))
                    .lineLimit(1)

                Spacer()

                // Show subcategory count on hover, otherwise total product count
                if isHovering && subCategoryCount > 0 {
                    Text("\(subCategoryCount) sub")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 2)
                }

                // Show total count (including subcategories)
                if totalCount > 0 {
                    Text("\(totalCount)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 4)
                }
            }
            .padding(.leading, CGFloat(8 + indentLevel * 16))
            .padding(.trailing, 4)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color.white.opacity(0.04) : Color.clear)
            )
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if expandedCategoryIds.contains(category.id) {
                        expandedCategoryIds.remove(category.id)
                    } else {
                        expandedCategoryIds.insert(category.id)
                    }
                }
            }

            // Expanded content: subcategories first, then products
            if isExpanded {
                // Child categories (recursive)
                ForEach(childCategories) { childCategory in
                    CategoryHierarchyView(
                        category: childCategory,
                        store: store,
                        expandedCategoryIds: $expandedCategoryIds,
                        indentLevel: indentLevel + 1
                    )
                }

                // Direct products in this category
                ForEach(directProducts) { product in
                    ProductTreeItem(
                        product: product,
                        isSelected: store.selectedProductIds.contains(product.id),
                        isActive: store.selectedProduct?.id == product.id,
                        indentLevel: indentLevel + 1
                    )
                    .onTapGesture {
                        store.selectProduct(product)
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            Task { await store.deleteProduct(product) }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Category Tree Item (Simple - for non-recursive use)

struct CategoryTreeItem: View {
    let category: Category
    let isExpanded: Bool
    var itemCount: Int = 0
    var indentLevel: Int = 0
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            Image(systemName: category.icon ?? (isExpanded ? "folder.fill" : "folder"))
                .font(.system(size: 10))
                .foregroundStyle(.green)
                .frame(width: 14)

            Text(category.name)
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer()

            if itemCount > 0 {
                Text("\(itemCount)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 4)
            }
        }
        .padding(.leading, CGFloat(8 + indentLevel * 16))
        .padding(.trailing, 4)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}

// MARK: - Product Tree Item

struct ProductTreeItem: View {
    let product: Product
    let isSelected: Bool
    let isActive: Bool
    var indentLevel: Int = 0

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "leaf")
                .font(.system(size: 9))
                .foregroundStyle(.green)
                .frame(width: 14)

            Text(product.name)
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer()

            // Price on hover
            if isHovering || isActive {
                Text(product.displayPrice)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            // Stock indicator
            Circle()
                .fill(product.stockStatusColor)
                .frame(width: 6, height: 6)
        }
        .padding(.leading, CGFloat(8 + indentLevel * 16))
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? Color.accentColor.opacity(0.3) :
                      isSelected ? Color.white.opacity(0.08) :
                      isHovering ? Color.white.opacity(0.04) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

// MARK: - Tree Section Header

struct TreeSectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("(\(count))")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - Collection Tree Item

struct CollectionTreeItem: View {
    let collection: CreationCollection
    let isExpanded: Bool
    var itemCount: Int = 0
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // Disclosure indicator
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            // Folder icon
            Image(systemName: isExpanded ? "folder.fill" : "folder")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .frame(width: 16)

            Text(collection.name)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            // Item count badge
            if itemCount > 0 {
                Text("\(itemCount)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}

// MARK: - Creation Tree Item

struct CreationTreeItem: View {
    let creation: Creation
    let isSelected: Bool
    let isActive: Bool
    var indentLevel: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            // Indent spacer based on level
            Spacer()
                .frame(width: CGFloat(12 + indentLevel * 16))

            // Type icon
            Image(systemName: creation.creationType.icon)
                .font(.system(size: 10))
                .foregroundStyle(creation.creationType.color)
                .frame(width: 16)

            Text(creation.name)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            // Status indicator
            if let status = creation.status {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? Color.accentColor.opacity(0.3) :
                      isSelected ? Color.white.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

struct CollectionListItem: View {
    let collection: CreationCollection

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .frame(width: 16)

            Text(collection.name)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            if collection.isPublic == true {
                Image(systemName: "globe")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .cornerRadius(4)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isSelected ? Color.accentColor : Color(white: 0.15))
                .foregroundStyle(isSelected ? .white : .secondary)
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Store Picker Row

struct StorePickerRow: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        Menu {
            ForEach(store.stores) { s in
                Button {
                    Task { await store.selectStore(s) }
                } label: {
                    HStack {
                        Text(s.storeName)
                        if store.selectedStore?.id == s.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "storefront")
                    .font(.system(size: 9))
                    .foregroundStyle(.green)

                Text(store.selectedStore?.storeName ?? "Select Store")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(white: 0.12))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}

struct CreationListItem: View {
    let creation: Creation
    let isSelected: Bool
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: creation.creationType.icon)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 16)

            Text(creation.name)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)

            Spacer()

            Circle()
                .fill(creation.status == .published ? Color.green : Color.orange)
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Editor Tab Bar (VSCode-style)

struct EditorTabBar: View {
    let creation: Creation?
    @Binding var selectedTab: EditorTab
    @Binding var sidebarCollapsed: Bool
    let hasUnsavedChanges: Bool
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Show sidebar button (only when collapsed)
            if sidebarCollapsed {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { sidebarCollapsed = false }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 20)
            }

            // Tabs - VSCode file tab style
            HStack(spacing: 0) {
                ForEach(EditorTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        hasChanges: tab == .code && hasUnsavedChanges
                    ) {
                        withAnimation(.easeOut(duration: 0.1)) { selectedTab = tab }
                    }
                }
            }

            Spacer()

            // File name + modified indicator
            if let creation = creation {
                HStack(spacing: 4) {
                    if hasUnsavedChanges {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                    }
                    Text(creation.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .padding(.trailing, 8)

                // Save button
                Button {
                    onSave()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(hasUnsavedChanges ? .primary : .tertiary)
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 32)
        .background(Color(white: 0.11))
    }
}

struct TabButton: View {
    let tab: EditorTab
    let isSelected: Bool
    let hasChanges: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10))
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .medium))
                if hasChanges {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                }
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ?
                Color(white: 0.18) :
                Color.clear
            )
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hot Reload Renderer

struct HotReloadRenderer: View {
    let code: String
    let creationId: String
    let refreshTrigger: UUID

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var currentCode: String = ""
    @State private var hasInitialized = false
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HotReloadWebView(
                html: buildRenderHTML(code: currentCode),
                isLoading: $isLoading,
                loadError: $loadError
            )
            .id(currentCode.hashValue)
            .opacity(opacity)

            if isLoading && !hasInitialized {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .colorScheme(.dark)
                    Text("Rendering...")
                        .foregroundStyle(.white)
                }
            }

            if currentCode.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)
                    Text("No code to preview")
                        .foregroundStyle(.gray)
                }
            }

            if let error = loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Render Error")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .onAppear {
            currentCode = code
        }
        .onChange(of: code) { oldCode, newCode in
            if oldCode != newCode && !newCode.isEmpty {
                hasInitialized = true
                loadError = nil
                withAnimation(.easeOut(duration: 0.1)) { opacity = 0.7 }
                currentCode = newCode
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeIn(duration: 0.15)) { opacity = 1.0 }
                }
            }
        }
        .onChange(of: refreshTrigger) { _, _ in
            loadError = nil
            withAnimation(.easeOut(duration: 0.1)) { opacity = 0.7 }
            let temp = currentCode
            currentCode = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                currentCode = temp
                withAnimation(.easeIn(duration: 0.15)) { opacity = 1.0 }
            }
        }
    }

    private func buildRenderHTML(code: String) -> String {
        let safeCode = code
            .replacingOccurrences(of: "\\(", with: "\\\\(")

        let codeWithoutImports = safeCode
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("import ") }
            .joined(separator: "\n")

        // Extract LOCATION_ID from code if present
        var locationIdInit = ""
        if let range = code.range(of: #"(?:const|let|var)\s+LOCATION_ID\s*=\s*["\']([^"\']+)["\']"#, options: .regularExpression) {
            let match = code[range]
            if let idRange = match.range(of: #"["\']([^"\']+)["\']"#, options: .regularExpression) {
                let idWithQuotes = String(match[idRange])
                let locationId = idWithQuotes.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                locationIdInit = "window.LOCATION_ID = '\(locationId)'; nativeLog('Pre-set LOCATION_ID: ' + window.LOCATION_ID);"
            }
        }

        // Extract STORE_ID from code if present
        var storeIdInit = ""
        if let range = code.range(of: #"(?:const|let|var)\s+STORE_ID\s*=\s*["\']([^"\']+)["\']"#, options: .regularExpression) {
            let match = code[range]
            if let idRange = match.range(of: #"["\']([^"\']+)["\']"#, options: .regularExpression) {
                let idWithQuotes = String(match[idRange])
                let storeId = idWithQuotes.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                storeIdInit = "window.STORE_ID = '\(storeId)'; nativeLog('Pre-set STORE_ID: ' + window.STORE_ID);"
            }
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">

            <!-- React 18 (dev mode for better errors) -->
            <script src="https://unpkg.com/react@18/umd/react.development.js" crossorigin></script>
            <script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js" crossorigin></script>

            <!-- Babel for JSX -->
            <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>

            <!-- Tailwind CSS -->
            <script src="https://cdn.tailwindcss.com"></script>

            <!-- Animation - Framer Motion -->
            <script src="https://unpkg.com/framer-motion@11/dist/framer-motion.js" crossorigin></script>

            <!-- GSAP -->
            <script src="https://unpkg.com/gsap@3/dist/gsap.min.js" crossorigin></script>

            <!-- 3D -->
            <script src="https://unpkg.com/three@0.160.0/build/three.min.js" crossorigin></script>

            <!-- Charts -->
            <script src="https://unpkg.com/recharts@2.10.3/umd/Recharts.js" crossorigin></script>

            <!-- React Router -->
            <script src="https://unpkg.com/react-router-dom@6/dist/umd/react-router-dom.production.min.js" crossorigin></script>

            <!-- Lucide Icons -->
            <script src="https://unpkg.com/lucide@latest/dist/umd/lucide.min.js" crossorigin></script>

            <!-- Fonts -->
            <link rel="preconnect" href="https://fonts.googleapis.com">
            <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
            <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&family=JetBrains+Mono:wght@400;500;600&family=Space+Grotesk:wght@400;500;600;700&display=swap" rel="stylesheet">

            <script>
                tailwind.config = {
                    theme: {
                        extend: {
                            fontFamily: {
                                sans: ['Inter', '-apple-system', 'BlinkMacSystemFont', 'sans-serif'],
                                mono: ['JetBrains Mono', 'SF Mono', 'monospace'],
                                display: ['Space Grotesk', 'Inter', 'sans-serif'],
                            },
                        },
                    },
                };
            </script>

            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                html, body, #root {
                    width: 100%; height: 100%;
                    background: #000; color: #fff;
                    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
                    overflow-x: hidden;
                    -webkit-font-smoothing: antialiased;
                    -moz-osx-font-smoothing: grayscale;
                }
                .error-boundary {
                    display: flex; flex-direction: column;
                    align-items: center; justify-content: center;
                    height: 100%; color: #ff6b6b; padding: 20px;
                    text-align: center; background: #000;
                }
                .error-boundary pre {
                    background: #1a1a1a; padding: 16px; border-radius: 8px;
                    max-width: 90%; overflow-x: auto; margin-top: 16px;
                    font-family: 'JetBrains Mono', monospace; font-size: 12px;
                    text-align: left; white-space: pre-wrap; word-break: break-word;
                }
            </style>
        </head>
        <body>
            <div id="root"><div style="display:flex;align-items:center;justify-content:center;height:100%;color:#666">Loading...</div></div>
            <!-- Global library setup (AFTER CDN loads, BEFORE Babel) -->
            <script>
                // Console bridge to Swift
                window.nativeLog = function(msg) {
                    try { window.webkit.messageHandlers.consoleLog.postMessage(String(msg)); } catch(e) { console.log(msg); }
                };
                window.onerror = function(msg, url, line, col, error) {
                    var fullMsg = error ? (error.stack || error.message || msg) : msg;
                    nativeLog('ERROR: ' + fullMsg);
                    return true; // Don't show error in UI for CDN errors
                };

                nativeLog('Setting up libraries...');

                try {
                    // Framer Motion
                    if (window.Motion) {
                        nativeLog('Motion found');
                        window.motion = window.Motion.motion;
                        window.AnimatePresence = window.Motion.AnimatePresence;
                        window.useAnimation = window.Motion.useAnimation;
                        window.useMotionValue = window.Motion.useMotionValue;
                        window.useTransform = window.Motion.useTransform;
                        window.useSpring = window.Motion.useSpring;
                        window.useInView = window.Motion.useInView;
                        window.useScroll = window.Motion.useScroll;
                    }
                } catch(e) { nativeLog('Motion setup error: ' + e.message); }

                try {
                    // Recharts
                    if (window.Recharts) {
                        nativeLog('Recharts found');
                        window.LineChart = window.Recharts.LineChart;
                        window.BarChart = window.Recharts.BarChart;
                        window.PieChart = window.Recharts.PieChart;
                        window.AreaChart = window.Recharts.AreaChart;
                        window.XAxis = window.Recharts.XAxis;
                        window.YAxis = window.Recharts.YAxis;
                        window.CartesianGrid = window.Recharts.CartesianGrid;
                        window.Tooltip = window.Recharts.Tooltip;
                        window.Legend = window.Recharts.Legend;
                        window.Line = window.Recharts.Line;
                        window.Bar = window.Recharts.Bar;
                        window.Pie = window.Recharts.Pie;
                        window.Area = window.Recharts.Area;
                        window.Cell = window.Recharts.Cell;
                        window.ResponsiveContainer = window.Recharts.ResponsiveContainer;
                        nativeLog('ResponsiveContainer: ' + !!window.ResponsiveContainer);
                    } else {
                        nativeLog('Recharts NOT found');
                    }
                } catch(e) { nativeLog('Recharts setup error: ' + e.message); }

                try {
                    // React Router - skip if causing issues
                    if (window.ReactRouterDOM) {
                        nativeLog('ReactRouterDOM found');
                        window.HashRouter = window.ReactRouterDOM.HashRouter;
                        window.BrowserRouter = window.ReactRouterDOM.BrowserRouter;
                        window.Routes = window.ReactRouterDOM.Routes;
                        window.Route = window.ReactRouterDOM.Route;
                        window.Link = window.ReactRouterDOM.Link;
                        window.Navigate = window.ReactRouterDOM.Navigate;
                        window.Outlet = window.ReactRouterDOM.Outlet;
                        window.useNavigate = window.ReactRouterDOM.useNavigate;
                        window.useLocation = window.ReactRouterDOM.useLocation;
                        window.useParams = window.ReactRouterDOM.useParams;
                        window.Router = window.HashRouter;
                    }
                } catch(e) { nativeLog('Router setup error: ' + e.message); }

                nativeLog('Library setup complete');
            </script>
            <script type="text/babel" data-presets="react">
                nativeLog('Babel executing...');

                // ========== SUPABASE CONFIG ==========
                const SUPABASE_URL = 'https://uaednwpxursknmwdeejn.supabase.co';
                const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';
                const POLL_INTERVAL = 5000;

                // ========== WHALE STORE HOOKS ==========
                window.useStore = {
                    // Generic query hook
                    useQuery: function(table, options) {
                        options = options || {};
                        const [data, setData] = React.useState([]);
                        const [loading, setLoading] = React.useState(true);
                        const [error, setError] = React.useState(null);

                        React.useEffect(function() {
                            async function fetchData() {
                                try {
                                    var url = SUPABASE_URL + '/rest/v1/' + table + '?select=' + encodeURIComponent(options.select || '*');
                                    if (options.filter) url += '&' + options.filter;
                                    if (options.order) url += '&order=' + options.order;
                                    if (options.limit) url += '&limit=' + options.limit;

                                    nativeLog('Fetching: ' + table);
                                    var res = await fetch(url, {
                                        headers: {
                                            'apikey': SUPABASE_KEY,
                                            'Authorization': 'Bearer ' + SUPABASE_KEY,
                                            'Content-Type': 'application/json'
                                        }
                                    });
                                    var json = await res.json();
                                    nativeLog('Response for ' + table + ': ' + (Array.isArray(json) ? json.length + ' items' : JSON.stringify(json).substring(0, 100)));
                                    if (Array.isArray(json)) {
                                        setData(json);
                                        setError(null);
                                    } else if (json.message) {
                                        nativeLog('Error: ' + json.message);
                                        setError(json.message);
                                    } else if (json.error) {
                                        setError(json.error);
                                    }
                                } catch (e) {
                                    nativeLog('Fetch error: ' + e.message);
                                    setError(e.message);
                                } finally {
                                    setLoading(false);
                                }
                            }
                            fetchData();
                            var interval = setInterval(fetchData, options.pollInterval || POLL_INTERVAL);
                            return function() { clearInterval(interval); };
                        }, [table, JSON.stringify(options)]);

                        return { data: data, loading: loading, error: error, refetch: function() {} };
                    },

                    // Products with inventory - uses RPC for location-specific (real-time), view for global
                    productsWithInventory: function(storeId, locationId) {
                        var locId = locationId || window.LOCATION_ID || null;
                        nativeLog('productsWithInventory called, locId=' + locId);
                        if (locId) {
                            // Use RPC for real-time location inventory
                            return window.useStore.productsForLocation(locId);
                        }
                        // Fallback to view for global queries
                        return window.useStore.useQuery('v_products_with_inventory', {
                            select: '*',
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Products - same as productsWithInventory
                    useProducts: function(storeId, locationId) {
                        var locId = locationId || window.LOCATION_ID || null;
                        nativeLog('useProducts called, locId=' + locId);
                        if (locId) {
                            return window.useStore.productsForLocation(locId);
                        }
                        return window.useStore.useQuery('v_products_with_inventory', {
                            select: '*',
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Products for specific location - uses RPC (real-time inventory)
                    productsForLocation: function(locationId) {
                        var [data, setData] = React.useState([]);
                        var [loading, setLoading] = React.useState(true);
                        var [error, setError] = React.useState(null);

                        React.useEffect(function() {
                            if (!locationId) { setLoading(false); return; }
                            async function fetchProducts() {
                                try {
                                    nativeLog('RPC: get_products_for_location(' + locationId + ')');
                                    var url = SUPABASE_URL + '/rest/v1/rpc/get_products_for_location';
                                    var res = await fetch(url, {
                                        method: 'POST',
                                        headers: {
                                            'apikey': SUPABASE_KEY,
                                            'Authorization': 'Bearer ' + SUPABASE_KEY,
                                            'Content-Type': 'application/json'
                                        },
                                        body: JSON.stringify({ p_location_id: locationId })
                                    });
                                    var json = await res.json();
                                    nativeLog('RPC response: ' + (Array.isArray(json) ? json.length + ' products' : JSON.stringify(json).substring(0, 100)));
                                    if (Array.isArray(json)) {
                                        // Filter out products with tiny quantities (< 1 unit) - these are "ghost products"
                                        // that show up in inventory but aren't really sellable
                                        var filtered = json.filter(function(p) {
                                            return (p.quantity || 0) >= 1;
                                        });
                                        nativeLog('Filtered from ' + json.length + ' to ' + filtered.length + ' products (removed qty < 1)');

                                        // Add stock_by_location compatibility for existing creation code
                                        // RPC returns 'quantity' for this location, convert to stock_by_location format
                                        var enhanced = filtered.map(function(p) {
                                            var stockByLoc = {};
                                            stockByLoc[locationId] = p.quantity || 0;
                                            return Object.assign({}, p, { stock_by_location: stockByLoc });
                                        });
                                        setData(enhanced);
                                    } else if (json.message || json.error) {
                                        setError(json.message || json.error);
                                    }
                                } catch (e) {
                                    nativeLog('RPC error: ' + e.message);
                                    setError(e.message);
                                } finally {
                                    setLoading(false);
                                }
                            }
                            fetchProducts();
                            var interval = setInterval(fetchProducts, POLL_INTERVAL);
                            return function() { clearInterval(interval); };
                        }, [locationId]);

                        return { data: data, loading: loading, error: error };
                    },

                    // Orders
                    useOrders: function(storeId, days) {
                        days = days || 30;
                        var since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
                        return window.useStore.useQuery('orders', {
                            select: '*,order_items(*,product:products(name,sku))',
                            filter: storeId ? 'store_id=eq.' + storeId + '&created_at=gte.' + since : 'created_at=gte.' + since,
                            order: 'created_at.desc'
                        });
                    },

                    // Orders with items
                    ordersWithItems: function(storeId, days) {
                        return window.useStore.useOrders(storeId, days);
                    },

                    // Stores
                    useStores: function() {
                        return window.useStore.useQuery('stores', { order: 'name.asc' });
                    },

                    // Store locations
                    storeLocations: function(storeId) {
                        return window.useStore.useQuery('locations', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Creations
                    useCreations: function(type) {
                        return window.useStore.useQuery('creations', {
                            filter: type ? 'creation_type=eq.' + type : undefined,
                            order: 'created_at.desc'
                        });
                    },

                    // Collections
                    useCollections: function() {
                        return window.useStore.useQuery('creation_collections', { order: 'created_at.desc' });
                    },

                    // Customers
                    customers: function(storeId) {
                        return window.useStore.useQuery('customers', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'created_at.desc'
                        });
                    },

                    // Revenue stats
                    revenueStats: function(storeId, days) {
                        return window.useStore.useOrders(storeId, days);
                    },

                    // Store (single store by ID)
                    store: function(storeId) {
                        var [data, setData] = React.useState(null);
                        var [loading, setLoading] = React.useState(true);
                        var [error, setError] = React.useState(null);

                        React.useEffect(function() {
                            if (!storeId) { setLoading(false); return; }
                            async function fetchStore() {
                                try {
                                    var url = SUPABASE_URL + '/rest/v1/stores?id=eq.' + storeId + '&select=*';
                                    var res = await fetch(url, {
                                        headers: {
                                            'apikey': SUPABASE_KEY,
                                            'Authorization': 'Bearer ' + SUPABASE_KEY,
                                        }
                                    });
                                    var json = await res.json();
                                    setData(json && json[0] ? json[0] : null);
                                } catch (e) {
                                    setError(e.message);
                                } finally {
                                    setLoading(false);
                                }
                            }
                            fetchStore();
                        }, [storeId]);

                        return { data: data, loading: loading, error: error };
                    },

                    // Location (single location by ID)
                    location: function(locationId) {
                        var [data, setData] = React.useState(null);
                        var [loading, setLoading] = React.useState(true);
                        var [error, setError] = React.useState(null);

                        React.useEffect(function() {
                            if (!locationId) { setLoading(false); return; }
                            async function fetchLocation() {
                                try {
                                    var url = SUPABASE_URL + '/rest/v1/locations?id=eq.' + locationId + '&select=*';
                                    var res = await fetch(url, {
                                        headers: {
                                            'apikey': SUPABASE_KEY,
                                            'Authorization': 'Bearer ' + SUPABASE_KEY,
                                        }
                                    });
                                    var json = await res.json();
                                    setData(json && json[0] ? json[0] : null);
                                } catch (e) {
                                    setError(e.message);
                                } finally {
                                    setLoading(false);
                                }
                            }
                            fetchLocation();
                        }, [locationId]);

                        return { data: data, loading: loading, error: error };
                    },

                    // Product (single product by ID)
                    product: function(productId) {
                        var [data, setData] = React.useState(null);
                        var [loading, setLoading] = React.useState(true);

                        React.useEffect(function() {
                            if (!productId) { setLoading(false); return; }
                            async function fetchProduct() {
                                try {
                                    var url = SUPABASE_URL + '/rest/v1/products?id=eq.' + productId + '&select=*,variants(*,inventory(*))';
                                    var res = await fetch(url, {
                                        headers: {
                                            'apikey': SUPABASE_KEY,
                                            'Authorization': 'Bearer ' + SUPABASE_KEY,
                                        }
                                    });
                                    var json = await res.json();
                                    setData(json && json[0] ? json[0] : null);
                                } catch (e) {}
                                finally { setLoading(false); }
                            }
                            fetchProduct();
                        }, [productId]);

                        return { data: data, loading: loading };
                    },

                    // Categories
                    categories: function(storeId) {
                        return window.useStore.useQuery('categories', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Inventory
                    inventory: function(locationId) {
                        return window.useStore.useQuery('inventory', {
                            select: '*,variant:variants(*,product:products(*))',
                            filter: locationId ? 'location_id=eq.' + locationId : undefined,
                            order: 'updated_at.desc'
                        });
                    },

                    // Locations
                    locations: function(storeId) {
                        return window.useStore.useQuery('locations', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Variants
                    variants: function(productId) {
                        return window.useStore.useQuery('variants', {
                            select: '*,inventory(*)',
                            filter: productId ? 'product_id=eq.' + productId : undefined,
                            order: 'created_at.desc'
                        });
                    },

                    // Staff/Employees
                    staff: function(storeId) {
                        return window.useStore.useQuery('staff', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Discounts/Promos
                    discounts: function(storeId) {
                        return window.useStore.useQuery('discounts', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'created_at.desc'
                        });
                    },

                    // Taxes
                    taxes: function(storeId) {
                        return window.useStore.useQuery('taxes', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Analytics/Stats
                    analytics: function(storeId, days) {
                        return window.useStore.useOrders(storeId, days || 30);
                    },
                };

                // Global aliases for useStore
                var useStore = window.useStore;
                var useQuery = window.useStore.useQuery;
                var useProducts = window.useStore.useProducts;
                var useOrders = window.useStore.useOrders;
                var useStores = window.useStore.useStores;
                var useCreations = window.useStore.useCreations;
                var useCollections = window.useStore.useCollections;
                var productsForLocation = window.useStore.productsForLocation;

                // Stub component for when libraries don't load
                var StubComponent = function(props) { return React.createElement('div', { style: { padding: '20px', background: '#1a1a1a', borderRadius: '8px', color: '#888', textAlign: 'center' } }, 'Loading chart...'); };

                // Recharts aliases (ensure available in babel scope)
                var LineChart = window.LineChart || (window.Recharts && window.Recharts.LineChart) || StubComponent;
                var BarChart = window.BarChart || (window.Recharts && window.Recharts.BarChart) || StubComponent;
                var PieChart = window.PieChart || (window.Recharts && window.Recharts.PieChart) || StubComponent;
                var AreaChart = window.AreaChart || (window.Recharts && window.Recharts.AreaChart) || StubComponent;
                var XAxis = window.XAxis || (window.Recharts && window.Recharts.XAxis) || function() { return null; };
                var YAxis = window.YAxis || (window.Recharts && window.Recharts.YAxis) || function() { return null; };
                var CartesianGrid = window.CartesianGrid || (window.Recharts && window.Recharts.CartesianGrid) || function() { return null; };
                var Tooltip = window.Tooltip || (window.Recharts && window.Recharts.Tooltip) || function() { return null; };
                var Legend = window.Legend || (window.Recharts && window.Recharts.Legend) || function() { return null; };
                var Line = window.Line || (window.Recharts && window.Recharts.Line) || function() { return null; };
                var Bar = window.Bar || (window.Recharts && window.Recharts.Bar) || function() { return null; };
                var Pie = window.Pie || (window.Recharts && window.Recharts.Pie) || function() { return null; };
                var Area = window.Area || (window.Recharts && window.Recharts.Area) || function() { return null; };
                var Cell = window.Cell || (window.Recharts && window.Recharts.Cell) || function() { return null; };
                var ResponsiveContainer = window.ResponsiveContainer || (window.Recharts && window.Recharts.ResponsiveContainer) || function(props) { return props.children; };
                var RadialBarChart = (window.Recharts && window.Recharts.RadialBarChart) || StubComponent;
                var RadialBar = (window.Recharts && window.Recharts.RadialBar) || function() { return null; };
                var ComposedChart = (window.Recharts && window.Recharts.ComposedChart) || StubComponent;
                var Scatter = (window.Recharts && window.Recharts.Scatter) || function() { return null; };

                // Framer Motion aliases (with div fallback if not loaded)
                var motion = window.motion || { div: 'div', span: 'span', p: 'p', button: 'button', a: 'a', ul: 'ul', li: 'li', img: 'img', h1: 'h1', h2: 'h2', h3: 'h3', section: 'section', article: 'article', header: 'header', footer: 'footer', nav: 'nav', main: 'main' };
                var AnimatePresence = window.AnimatePresence || function(props) { return props.children; };
                var useAnimation = window.useAnimation || function() { return {}; };
                var useMotionValue = window.useMotionValue || function(v) { return { get: function() { return v; }, set: function() {} }; };
                var useTransform = window.useTransform || function(v) { return v; };
                var useSpring = window.useSpring || function(v) { return v; };
                var useInView = window.useInView || function() { return true; };
                var useScroll = window.useScroll || function() { return { scrollY: 0, scrollX: 0 }; };

                // Router aliases
                var HashRouter = window.HashRouter;
                var BrowserRouter = window.BrowserRouter;
                var Routes = window.Routes;
                var Route = window.Route;
                var Link = window.Link;
                var Navigate = window.Navigate;
                var Outlet = window.Outlet;
                var useNavigate = window.useNavigate;
                var useLocation = window.useLocation;
                var useParams = window.useParams;
                var Router = window.Router;

                // ========== UTILITY FUNCTIONS ==========
                const formatCurrency = (amount, currency = 'USD') => {
                    return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(amount || 0);
                };

                const formatNumber = (num) => {
                    return new Intl.NumberFormat('en-US').format(num || 0);
                };

                const formatDate = (date) => {
                    return new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
                };

                // ========== LOCATION INVENTORY HELPERS ==========
                // Get stock quantity for a specific location from stock_by_location JSONB
                const getStockForLocation = (product, locationId) => {
                    if (!product || !locationId) return 0;
                    // If product has quantity field (from RPC), use it directly
                    if (typeof product.quantity === 'number') return product.quantity;
                    // Otherwise check stock_by_location JSONB (from view)
                    if (product.stock_by_location && product.stock_by_location[locationId]) {
                        return product.stock_by_location[locationId];
                    }
                    return 0;
                };

                // Filter products to only those with stock at location
                const filterByLocationStock = (products, locationId, minQty = 0) => {
                    if (!products || !locationId) return products || [];
                    return products.filter(p => getStockForLocation(p, locationId) > minQty);
                };

                // Check if product is in stock at location
                const isInStockAt = (product, locationId) => {
                    return getStockForLocation(product, locationId) > 0;
                };

                // Get location name by ID from product
                const getLocationName = (product, locationId) => {
                    if (!product || !product.location_ids || !product.location_names) return '';
                    const idx = product.location_ids.indexOf(locationId);
                    return idx >= 0 ? product.location_names[idx] : '';
                };

                const formatRelativeTime = (date) => {
                    const now = new Date();
                    const diff = now - new Date(date);
                    const minutes = Math.floor(diff / 60000);
                    const hours = Math.floor(minutes / 60);
                    const days = Math.floor(hours / 24);
                    if (days > 0) return days + 'd ago';
                    if (hours > 0) return hours + 'h ago';
                    if (minutes > 0) return minutes + 'm ago';
                    return 'now';
                };

                // ========== ERROR BOUNDARY ==========
                class ErrorBoundary extends React.Component {
                    constructor(props) { super(props); this.state = { hasError: false, error: null }; }
                    static getDerivedStateFromError(error) { return { hasError: true, error }; }
                    componentDidCatch(error, info) { nativeLog('React Error: ' + error.message); }
                    render() {
                        if (this.state.hasError) {
                            return React.createElement('div', { className: 'error-boundary' },
                                React.createElement('h2', { style: { fontSize: '24px', marginBottom: '8px' } }, 'Render Error'),
                                React.createElement('pre', null, this.state.error?.message || 'Unknown error'),
                                React.createElement('button', {
                                    onClick: () => this.setState({ hasError: false, error: null }),
                                    style: { marginTop: '16px', padding: '8px 16px', background: '#333', border: 'none', borderRadius: '6px', color: '#fff', cursor: 'pointer' }
                                }, 'Try Again')
                            );
                        }
                        return this.props.children;
                    }
                }

                // ========== PRE-SET IDS FROM CODE ==========
                \(locationIdInit)
                \(storeIdInit)

                // ========== USER CODE ==========
                nativeLog('Executing user code...');
                try {
                    \(codeWithoutImports)

                    // Auto-export LOCATION_ID to window if defined
                    if (typeof LOCATION_ID !== 'undefined') {
                        window.LOCATION_ID = LOCATION_ID;
                        nativeLog('Exported LOCATION_ID to window: ' + LOCATION_ID);
                    }
                    // Also export STORE_ID if defined
                    if (typeof STORE_ID !== 'undefined') {
                        window.STORE_ID = STORE_ID;
                        nativeLog('Exported STORE_ID to window: ' + STORE_ID);
                    }

                    nativeLog('User code executed, rendering...');
                    const rootEl = document.getElementById('root');
                    const root = ReactDOM.createRoot(rootEl);

                    if (typeof App !== 'undefined') {
                        nativeLog('Rendering App component');
                        root.render(React.createElement(ErrorBoundary, null, React.createElement(App)));
                    } else if (typeof Main !== 'undefined') {
                        nativeLog('Rendering Main component');
                        root.render(React.createElement(ErrorBoundary, null, React.createElement(Main)));
                    } else if (typeof Component !== 'undefined') {
                        nativeLog('Rendering Component');
                        root.render(React.createElement(ErrorBoundary, null, React.createElement(Component)));
                    } else if (typeof Page !== 'undefined') {
                        nativeLog('Rendering Page component');
                        root.render(React.createElement(ErrorBoundary, null, React.createElement(Page)));
                    } else if (typeof Dashboard !== 'undefined') {
                        nativeLog('Rendering Dashboard component');
                        root.render(React.createElement(ErrorBoundary, null, React.createElement(Dashboard)));
                    } else {
                        nativeLog('No component found!');
                        rootEl.innerHTML = '<div class="error-boundary"><h2>No Component Found</h2><p style="color:#888;margin-top:8px">Export: App, Main, Component, Page, or Dashboard</p></div>';
                    }
                    nativeLog('Render complete');
                } catch (e) {
                    nativeLog('Parse error: ' + e.message + '\\n' + e.stack);
                    document.getElementById('root').innerHTML = '<div class="error-boundary"><h2>Parse Error</h2><pre>' + e.message + '\\n\\n' + (e.stack || '') + '</pre></div>';
                }
            </script>
        </body>
        </html>
        """
    }
}

struct HotReloadWebView: NSViewRepresentable {
    let html: String
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        // Add script message handler for console logs
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "consoleLog")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        isLoading = true
        // Load HTML with HTTPS base URL to allow CDN script loading
        webView.loadHTMLString(html, baseURL: URL(string: "https://unpkg.com/"))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: HotReloadWebView

        init(_ parent: HotReloadWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "consoleLog", let msg = message.body as? String {
                print("[WebView] \(msg)")
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.loadError = error.localizedDescription
            }
        }
    }
}

// MARK: - Code Editor Panel

struct CodeEditorPanel: View {
    @Binding var code: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("React Code")
                    .font(.headline)
                Spacer()
                Text("\(code.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Editor
            TextEditor(text: $code)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
        }
    }
}

// MARK: - Details Panel

struct DetailsPanel: View {
    let creation: Creation
    @ObservedObject var store: EditorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: creation.creationType.icon)
                            .font(.title)
                            .foregroundStyle(Color.accentColor)
                        Text(creation.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }

                    Text(creation.description ?? "No description")
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatBox(title: "Views", value: "\(creation.viewCount ?? 0)", icon: "eye")
                    StatBox(title: "Installs", value: "\(creation.installCount ?? 0)", icon: "arrow.down.circle")
                    StatBox(title: "Version", value: creation.version ?? "1.0.0", icon: "tag")
                }

                Divider()

                // Metadata
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)

                    MetaRow(label: "ID", value: creation.id.uuidString)
                    MetaRow(label: "Slug", value: creation.slug)
                    MetaRow(label: "Type", value: creation.creationType.displayName)
                    MetaRow(label: "Status", value: creation.status?.displayName ?? "Draft")
                    MetaRow(label: "Visibility", value: creation.visibility ?? "private")

                    if let url = creation.deployedUrl {
                        MetaRow(label: "URL", value: url)
                    }

                    if let created = creation.createdAt {
                        MetaRow(label: "Created", value: created.formatted())
                    }
                }
            }
            .padding(24)
        }
        .background(Color(white: 0.11))
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

struct MetaRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.system(size: 13))
    }
}

// MARK: - Settings Panel

struct SettingsPanel: View {
    let creation: Creation
    @ObservedObject var store: EditorStore

    @State private var selectedStatus: CreationStatus = .draft
    @State private var isPublic: Bool = false
    @State private var selectedVisibility: String = "private"

    var body: some View {
        Form {
            Section("Visibility") {
                Picker("Status", selection: $selectedStatus) {
                    ForEach(CreationStatus.allCases, id: \.self) { status in
                        HStack {
                            Circle()
                                .fill(status.color)
                                .frame(width: 8, height: 8)
                            Text(status.displayName)
                        }
                        .tag(status)
                    }
                }
                .onChange(of: selectedStatus) { _, newStatus in
                    Task {
                        await store.updateCreationSettings(id: creation.id, status: newStatus)
                    }
                }

                Toggle("Public", isOn: $isPublic)
                    .onChange(of: isPublic) { _, newValue in
                        Task {
                            await store.updateCreationSettings(id: creation.id, isPublic: newValue)
                        }
                    }

                Picker("Visibility", selection: $selectedVisibility) {
                    Text("Private").tag("private")
                    Text("Public").tag("public")
                    Text("Unlisted").tag("unlisted")
                }
                .onChange(of: selectedVisibility) { _, newValue in
                    Task {
                        await store.updateCreationSettings(id: creation.id, visibility: newValue)
                    }
                }
            }

            Section("Deployment") {
                if let url = creation.deployedUrl {
                    LabeledContent("URL", value: url)
                }
                if let repo = creation.githubRepo {
                    LabeledContent("GitHub", value: repo)
                }
            }

            Section("Info") {
                LabeledContent("ID", value: creation.id.uuidString)
                LabeledContent("Type", value: creation.creationType.displayName)
                if let created = creation.createdAt {
                    LabeledContent("Created", value: created.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            selectedStatus = creation.status ?? .draft
            isPublic = creation.isPublic ?? false
            selectedVisibility = creation.visibility ?? "private"
        }
        .onChange(of: creation.id) { _, _ in
            selectedStatus = creation.status ?? .draft
            isPublic = creation.isPublic ?? false
            selectedVisibility = creation.visibility ?? "private"
        }
    }
}

// MARK: - Empty State

struct EmptyEditorView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No Selection")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Select a creation from the sidebar")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.11))
    }
}

// MARK: - New Creation Sheet

struct NewCreationSheet: View {
    @ObservedObject var store: EditorStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedType: CreationType = .app
    @State private var description = ""
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Creation")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(white: 0.15))

            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("My New Creation", text: $name)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(white: 0.18))
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Type")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                        ForEach(CreationType.allCases, id: \.self) { type in
                            Button {
                                selectedType = type
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 16))
                                    Text(type.displayName)
                                        .font(.system(size: 10))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedType == type ? Color.blue.opacity(0.3) : Color(white: 0.18))
                                .foregroundStyle(selectedType == type ? .primary : .secondary)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(selectedType == type ? Color.blue : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Description (optional)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("", text: $description)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(white: 0.18))
                        .cornerRadius(6)
                }
            }
            .padding()

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    isCreating = true
                    Task {
                        await store.createCreation(
                            name: name,
                            type: selectedType,
                            description: description.isEmpty ? nil : description
                        )
                        isCreating = false
                        dismiss()
                    }
                } label: {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 60)
                    } else {
                        Text("Create")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || isCreating)
            }
            .padding()
            .background(Color(white: 0.15))
        }
        .frame(width: 400, height: 450)
        .background(Color(white: 0.12))
    }
}

// MARK: - New Collection Sheet

struct NewCollectionSheet: View {
    @ObservedObject var store: EditorStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Collection")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(white: 0.15))

            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("My Collection", text: $name)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(white: 0.18))
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Description (optional)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("", text: $description)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(white: 0.18))
                        .cornerRadius(6)
                }
            }
            .padding()

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    isCreating = true
                    Task {
                        await store.createCollection(
                            name: name,
                            description: description.isEmpty ? nil : description
                        )
                        isCreating = false
                        dismiss()
                    }
                } label: {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 60)
                    } else {
                        Text("Create")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || isCreating)
            }
            .padding()
            .background(Color(white: 0.15))
        }
        .frame(width: 350, height: 250)
        .background(Color(white: 0.12))
    }
}

// MARK: - New Store Sheet

struct NewStoreSheet: View {
    @ObservedObject var store: EditorStore
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Store")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(white: 0.15))

            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Store Name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("My Store", text: $name)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(white: 0.18))
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Contact Email")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("store@example.com", text: $email)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(white: 0.18))
                        .cornerRadius(6)
                }

                Text("The store will be your workspace for managing products, creations, and settings.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding()

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    isCreating = true
                    Task {
                        await store.createStore(
                            name: name,
                            email: email.isEmpty ? (authManager.currentUser?.email ?? "no-email@example.com") : email,
                            ownerUserId: authManager.currentUser?.id
                        )
                        isCreating = false
                        dismiss()
                    }
                } label: {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 60)
                    } else {
                        Text("Create Store")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || isCreating)
            }
            .padding()
            .background(Color(white: 0.15))
        }
        .frame(width: 350, height: 280)
        .background(Color(white: 0.12))
        .onAppear {
            // Pre-fill email from current user
            if let userEmail = authManager.currentUser?.email {
                email = userEmail
            }
        }
    }
}
