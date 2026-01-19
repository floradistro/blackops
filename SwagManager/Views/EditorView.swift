import SwiftUI
import WebKit
import Supabase
import Darwin
// import SwiftTerm // TODO: Add SwiftTerm package in Xcode: File > Add Package Dependencies > https://github.com/migueldeicaza/SwiftTerm.git

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

// MARK: - App Theme (Dark)



// MARK: - Main Editor View

struct EditorView: View {
    @StateObject private var store = EditorStore()
    @EnvironmentObject var authManager: AuthManager
    @State private var sidebarCollapsed = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedTab: EditorTab = .preview
    @State private var showStoreSelectorSheet = false

    // MARK: - Main Content View

    @ViewBuilder
    private var mainContentView: some View {
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

                case .conversation(let conversation):
                    // Chat conversation
                    TeamChatView(store: store)

                case .category(let category):
                    // Category config editor
                    CategoryConfigView(category: category, store: store)

                case .browserSession(let session):
                    // Safari-style browser
                    SafariBrowserWindow(sessionId: session.id)
                        .id("browser-\(session.id)")
                }
            } else if let browserSession = store.selectedBrowserSession {
                // Safari-style browser
                SafariBrowserWindow(sessionId: browserSession.id)
                    .id("browser-\(browserSession.id)")
            } else if let category = store.selectedCategory {
                // Show category config even without tab
                CategoryConfigView(category: category, store: store)
            } else if let conversation = store.selectedConversation {
                // Show conversation even without tab
                TeamChatView(store: store)
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
        .scaleEffect(store.zoomLevel)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            SidebarPanel(store: store, sidebarCollapsed: $sidebarCollapsed)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
                .toolbarBackground(.hidden, for: .windowToolbar)
        } detail: {
            // Main Content Area
            ZStack {
                // Unified glass background for all content
                VisualEffectBackground(material: .underWindowBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    mainContentView
                }
            }
            .toolbar {
                UnifiedToolbarContent(store: store)
            }
            .toolbarBackground(.hidden, for: .windowToolbar)
        }
        .navigationSplitViewStyle(.balanced)
        .animation(DesignSystem.Animation.spring, value: sidebarCollapsed)
        .onChange(of: sidebarCollapsed) { _, collapsed in
            columnVisibility = collapsed ? .detailOnly : .all
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleSidebar"))) { _ in
            withAnimation(DesignSystem.Animation.spring) {
                sidebarCollapsed.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SaveDocument"))) { _ in
            if store.hasUnsavedChanges {
                Task { await store.saveCurrentCreation() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowStoreSelector"))) { _ in
            showStoreSelectorSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowNewStore"))) { _ in
            store.showNewStoreSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ZoomIn"))) { _ in
            store.zoomIn()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ZoomOut"))) { _ in
            store.zoomOut()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ZoomReset"))) { _ in
            store.resetZoom()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowserNewTab"))) { _ in
            if let session = store.selectedBrowserSession ?? (store.activeTab?.isBrowserSession == true ? (store.activeTab as? OpenTabItem).flatMap { tab in
                if case .browserSession(let s) = tab { return s } else { return nil }
            } : nil) {
                BrowserTabManager.forSession(session.id).newTab()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowserReload"))) { _ in
            if let session = store.selectedBrowserSession ?? (store.activeTab?.isBrowserSession == true ? (store.activeTab as? OpenTabItem).flatMap { tab in
                if case .browserSession(let s) = tab { return s } else { return nil }
            } : nil) {
                BrowserTabManager.forSession(session.id).activeTab?.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowserBack"))) { _ in
            if let session = store.selectedBrowserSession ?? (store.activeTab?.isBrowserSession == true ? (store.activeTab as? OpenTabItem).flatMap { tab in
                if case .browserSession(let s) = tab { return s } else { return nil }
            } : nil) {
                BrowserTabManager.forSession(session.id).activeTab?.goBack()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowserForward"))) { _ in
            if let session = store.selectedBrowserSession ?? (store.activeTab?.isBrowserSession == true ? (store.activeTab as? OpenTabItem).flatMap { tab in
                if case .browserSession(let s) = tab { return s } else { return nil }
            } : nil) {
                BrowserTabManager.forSession(session.id).activeTab?.goForward()
            }
        }
        // Store selector sheet removed during refactoring
        // .sheet(isPresented: $showStoreSelectorSheet) {
        //     StoreSelectorSheet(store: store)
        // }
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
        .sheet(isPresented: $store.showNewCatalogSheet) {
            NewCatalogSheet(store: store)
        }
        .sheet(isPresented: $store.showNewCategorySheet) {
            NewCategorySheet(store: store)
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
    @Published var catalogs: [Catalog] = []
    @Published var selectedCatalog: Catalog?
    @Published var products: [Product] = []
    @Published var categories: [Category] = []
    @Published var selectedProduct: Product?
    @Published var selectedProductIds: Set<UUID> = []

    // MARK: - Chat/Conversations State
    @Published var locations: [Location] = []
    @Published var conversations: [Conversation] = []
    @Published var selectedConversation: Conversation?

    // MARK: - Category Config State
    @Published var selectedCategory: Category?

    // MARK: - Browser Sessions State
    @Published var browserSessions: [BrowserSession] = []
    @Published var selectedBrowserSession: BrowserSession?
    @Published var sidebarBrowserExpanded = false

    // MARK: - Tabs (Safari/Xcode style)
    @Published var openTabs: [OpenTabItem] = []
    @Published var activeTab: OpenTabItem?

    // MARK: - UI State
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var refreshTrigger = UUID()
    @Published var error: String?
    @Published var sidebarCreationsExpanded = false
    @Published var sidebarCatalogExpanded = false
    @Published var sidebarChatExpanded = false
    @Published var zoomLevel: CGFloat = 1.0

    // Sheet states
    @Published var showNewCreationSheet = false
    @Published var showNewCollectionSheet = false
    @Published var showNewStoreSheet = false
    @Published var showNewCatalogSheet = false
    @Published var showNewCategorySheet = false

    var lastSelectedIndex: Int?

    let supabase = SupabaseService.shared
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

            // Browser sessions table
            let browserSessionsInserts = channel.postgresChange(InsertAction.self, table: "browser_sessions")
            let browserSessionsUpdates = channel.postgresChange(UpdateAction.self, table: "browser_sessions")
            let browserSessionsDeletes = channel.postgresChange(DeleteAction.self, table: "browser_sessions")

            do {
                try await channel.subscribeWithError()
                NSLog("[EditorStore] Realtime: Successfully subscribed to channel")
            } catch {
                NSLog("[EditorStore] Realtime: Failed to subscribe - \(error.localizedDescription)")
                return // Don't try to use the channel if subscription failed
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

                // Handle browser sessions inserts
                group.addTask {
                    for await insert in browserSessionsInserts {
                        NSLog("[EditorStore] Realtime: browser_session INSERT received")
                        await MainActor.run {
                            if let session = try? insert.decodeRecord(as: BrowserSession.self, decoder: JSONDecoder.supabaseDecoder) {
                                // Only add if it belongs to current store
                                if session.storeId == self.selectedStore?.id {
                                    if !self.browserSessions.contains(where: { $0.id == session.id }) {
                                        self.browserSessions.insert(session, at: 0)
                                        NSLog("[EditorStore] Realtime: Added browser session '\(session.displayName)'")
                                    }
                                }
                            } else {
                                NSLog("[EditorStore] Realtime: Failed to decode browser session")
                            }
                        }
                    }
                }

                // Handle browser sessions updates
                group.addTask {
                    for await update in browserSessionsUpdates {
                        NSLog("[EditorStore] Realtime: browser_session UPDATE received")
                        await MainActor.run {
                            if let session = try? update.decodeRecord(as: BrowserSession.self, decoder: JSONDecoder.supabaseDecoder) {
                                if let idx = self.browserSessions.firstIndex(where: { $0.id == session.id }) {
                                    self.browserSessions[idx] = session
                                    NSLog("[EditorStore] Realtime: Updated browser session '\(session.displayName)'")
                                    // Update selected if this is the selected one
                                    if self.selectedBrowserSession?.id == session.id {
                                        self.selectedBrowserSession = session
                                    }
                                    // Update in open tabs
                                    if let tabIndex = self.openTabs.firstIndex(where: {
                                        if case .browserSession(let s) = $0, s.id == session.id { return true }
                                        return false
                                    }) {
                                        self.openTabs[tabIndex] = .browserSession(session)
                                    }
                                    if case .browserSession(let s) = self.activeTab, s.id == session.id {
                                        self.activeTab = .browserSession(session)
                                    }
                                }
                            }
                        }
                    }
                }

                // Handle browser sessions deletes
                group.addTask {
                    for await delete in browserSessionsDeletes {
                        NSLog("[EditorStore] Realtime: browser_session DELETE received")
                        await MainActor.run {
                            let oldRecord = delete.oldRecord
                            if let idString = oldRecord["id"]?.stringValue,
                               let id = UUID(uuidString: idString) {
                                self.browserSessions.removeAll { $0.id == id }
                                if self.selectedBrowserSession?.id == id {
                                    self.selectedBrowserSession = nil
                                }
                                // Close tab if open
                                self.openTabs.removeAll {
                                    if case .browserSession(let s) = $0, s.id == id { return true }
                                    return false
                                }
                                if case .browserSession(let s) = self.activeTab, s.id == id {
                                    self.activeTab = self.openTabs.first
                                }
                                NSLog("[EditorStore] Realtime: Removed browser session \(idString)")
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

    // MARK: - Zoom Functions

    func zoomIn() {
        zoomLevel = min(zoomLevel + 0.1, 3.0)
    }

    func zoomOut() {
        zoomLevel = max(zoomLevel - 0.1, 0.5)
    }

    func resetZoom() {
        zoomLevel = 1.0
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
        // Clear old data
        selectedCatalog = nil
        catalogs = []
        categories = []
        products = []
        conversations = []
        locations = []
        // Reload all data for new store
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
                ownerUserId: nil,  // DB trigger will auto-set from logged-in user
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

    // MARK: - Catalogs

    func loadCatalogs() async {
        do {
            NSLog("[EditorStore] Loading catalogs for store: %@ (%@)", selectedStore?.storeName ?? "unknown", currentStoreId.uuidString)
            catalogs = try await supabase.fetchCatalogs(storeId: currentStoreId)
            NSLog("[EditorStore] Found %d catalogs for store %@:", catalogs.count, selectedStore?.storeName ?? "unknown")
            for cat in catalogs {
                NSLog("[EditorStore]   - %@ (id: %@, store_id: %@)", cat.name, cat.id.uuidString, cat.storeId.uuidString)
            }

            // Auto-create default catalog if none exist but categories do
            if catalogs.isEmpty {
                NSLog("[EditorStore] No catalogs found, checking for orphan categories...")
                let orphanCategories = try await supabase.fetchCategories(storeId: currentStoreId, catalogId: nil)
                let orphanCount = orphanCategories.filter { $0.catalogId == nil }.count
                NSLog("[EditorStore] Found %d total categories, %d without catalog_id", orphanCategories.count, orphanCount)

                if orphanCount > 0 {
                    NSLog("[EditorStore] Creating default Distro catalog and migrating %d categories...", orphanCount)
                    await createDefaultCatalogAndMigrate()
                    return // createDefaultCatalogAndMigrate will reload catalogs
                }
            } else if let defaultCatalog = catalogs.first(where: { $0.isDefault == true }) ?? catalogs.first {
                // Catalogs exist - assign ALL categories for this store to the default catalog
                // This ensures categories don't belong to other/orphaned catalogs
                let allCategories = try await supabase.fetchCategories(storeId: currentStoreId, catalogId: nil)
                let wrongCatalogCount = allCategories.filter { $0.catalogId != defaultCatalog.id }.count
                if wrongCatalogCount > 0 {
                    NSLog("[EditorStore] Found %d categories not in default catalog, migrating to %@...", wrongCatalogCount, defaultCatalog.name)
                    _ = try await supabase.assignCategoriesToCatalog(storeId: currentStoreId, catalogId: defaultCatalog.id, onlyOrphans: false)
                    NSLog("[EditorStore] Migrated %d categories to %@", wrongCatalogCount, defaultCatalog.name)
                }
            }

            // Don't auto-select - let user expand catalog to see contents
            NSLog("[EditorStore] Loaded %d catalogs for store %@", catalogs.count, selectedStore?.storeName ?? "default")
        } catch {
            NSLog("[EditorStore] Error loading catalogs: %@", String(describing: error))
            // Don't show error if table doesn't exist yet
        }
    }

    private func createDefaultCatalogAndMigrate() async {
        guard let ownerUserId = selectedStore?.ownerUserId else {
            NSLog("[EditorStore] Cannot create catalog: store owner_user_id is nil")
            return
        }

        do {
            // First check if catalog already exists
            catalogs = try await supabase.fetchCatalogs(storeId: currentStoreId)

            if let existingCatalog = catalogs.first {
                // Use existing catalog for migration but don't auto-select
                NSLog("[EditorStore] Found existing catalog: %@ (id: %@)", existingCatalog.name, existingCatalog.id.uuidString)

                // Migrate orphan categories
                let migratedCount = try await supabase.assignCategoriesToCatalog(storeId: currentStoreId, catalogId: existingCatalog.id)
                if migratedCount > 0 {
                    NSLog("[EditorStore] Migrated %d categories to %@", migratedCount, existingCatalog.name)
                }
                return
            }

            NSLog("[EditorStore] Creating default Distro catalog for store: %@", currentStoreId.uuidString)

            // Create default "Distro" catalog
            let insert = CatalogInsert(
                storeId: currentStoreId,
                ownerUserId: ownerUserId,
                name: "Distro",
                slug: "distro-\(Int(Date().timeIntervalSince1970))",
                description: "Main product catalog",
                vertical: "cannabis",
                isActive: true,
                isDefault: true
            )

            let newCatalog = try await supabase.createCatalog(insert)
            NSLog("[EditorStore] Created catalog: %@ (id: %@)", newCatalog.name, newCatalog.id.uuidString)

            // Migrate orphan categories
            let migratedCount = try await supabase.assignCategoriesToCatalog(storeId: currentStoreId, catalogId: newCatalog.id)
            NSLog("[EditorStore] Migrated %d categories", migratedCount)

            catalogs = [newCatalog]
            // Don't auto-select - keep collapsed
        } catch {
            NSLog("[EditorStore] Error in createDefaultCatalogAndMigrate: %@", String(describing: error))
            // Don't show error to user - just load what we have
            await loadCatalogData()
        }
    }

    func selectCatalog(_ catalog: Catalog) async {
        selectedCatalog = catalog
        await loadCatalogData()
    }

    func createCatalog(name: String, vertical: String?, isDefault: Bool = false) async {
        guard let ownerUserId = selectedStore?.ownerUserId else {
            NSLog("[EditorStore] Cannot create catalog: store owner_user_id is nil")
            self.error = "Cannot create catalog: store owner not found"
            return
        }

        do {
            let slug = name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

            let insert = CatalogInsert(
                storeId: currentStoreId,
                ownerUserId: ownerUserId,
                name: name,
                slug: slug,
                description: nil,
                vertical: vertical,
                isActive: true,
                isDefault: isDefault
            )

            let newCatalog = try await supabase.createCatalog(insert)
            await loadCatalogs()
            selectedCatalog = newCatalog
            await loadCatalogData()
            NSLog("[EditorStore] Created catalog: %@", name)
        } catch {
            NSLog("[EditorStore] Error creating catalog: %@", String(describing: error))
            self.error = "Failed to create catalog: \(error.localizedDescription)"
        }
    }

    func deleteCatalog(_ catalog: Catalog) async {
        do {
            try await supabase.deleteCatalog(id: catalog.id)
            if selectedCatalog?.id == catalog.id {
                selectedCatalog = nil
            }
            await loadCatalogs()
            await loadCatalogData()
            NSLog("[EditorStore] Deleted catalog: %@", catalog.name)
        } catch {
            NSLog("[EditorStore] Error deleting catalog: %@", String(describing: error))
            self.error = "Failed to delete catalog: \(error.localizedDescription)"
        }
    }

    // MARK: - Load Catalog Data (Categories & Products)

    func loadCatalog() async {
        await loadCatalogs()
        await loadCatalogData()
        await loadConversations()
    }

    func loadCatalogData() async {
        do {
            categories = try await supabase.fetchCategories(storeId: currentStoreId, catalogId: selectedCatalog?.id)
            products = try await supabase.fetchProducts(storeId: currentStoreId)
            NSLog("[EditorStore] Loaded %d categories, %d products for store %@, catalog %@", categories.count, products.count, selectedStore?.storeName ?? "default", selectedCatalog?.name ?? "all")
        } catch {
            NSLog("[EditorStore] Error loading catalog data: %@", String(describing: error))
            if self.error == nil {
                self.error = "Failed to load catalog: \(error.localizedDescription)"
            }
        }
    }

    func createCategory(name: String, parentId: UUID? = nil) async {
        do {
            let slug = name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

            let insert = CategoryInsert(
                name: name,
                slug: slug,
                description: nil,
                parentId: parentId,
                catalogId: selectedCatalog?.id,
                storeId: currentStoreId,
                displayOrder: categories.count,
                isActive: true
            )

            _ = try await supabase.createCategory(insert)
            await loadCatalogData()
            NSLog("[EditorStore] Created category: %@", name)
        } catch {
            NSLog("[EditorStore] Error creating category: %@", String(describing: error))
            self.error = "Failed to create category: \(error.localizedDescription)"
        }
    }

    func deleteCategory(_ category: Category) async {
        do {
            try await supabase.deleteCategory(id: category.id)
            await loadCatalogData()
            NSLog("[EditorStore] Deleted category: %@", category.name)
        } catch {
            NSLog("[EditorStore] Error deleting category: %@", String(describing: error))
            self.error = "Failed to delete category: \(error.localizedDescription)"
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
        selectedCategory = nil
        openTab(.product(product))
    }

    func selectCategory(_ category: Category) {
        selectedCategory = category
        selectedProduct = nil
        selectedProductIds.removeAll()
        selectedCreation = nil
        selectedCreationIds.removeAll()
        selectedConversation = nil
        openTab(.category(category))
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
            case "stockQuantity":
                if let doubleVal = value as? Double {
                    update.stockQuantity = Int(doubleVal)
                }
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
                    selectedConversation = nil
                case .product(let p):
                    selectedProduct = p
                    selectedCreation = nil
                    selectedConversation = nil
                    editedCode = nil
                case .conversation(let c):
                    selectedConversation = c
                    selectedCreation = nil
                    selectedProduct = nil
                    selectedCategory = nil
                    editedCode = nil
                case .category(let c):
                    selectedCategory = c
                    selectedCreation = nil
                    selectedProduct = nil
                    selectedConversation = nil
                    editedCode = nil
                case .browserSession(let s):
                    selectedBrowserSession = s
                    selectedCreation = nil
                    selectedProduct = nil
                    selectedConversation = nil
                    selectedCategory = nil
                    editedCode = nil
                }
            } else {
                selectedCreation = nil
                selectedProduct = nil
                selectedConversation = nil
                selectedCategory = nil
                selectedBrowserSession = nil
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
            selectedConversation = nil
            selectedCategory = nil
            selectedBrowserSession = nil
        case .product(let p):
            selectedProduct = p
            selectedCreation = nil
            selectedConversation = nil
            selectedCategory = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .conversation(let c):
            selectedConversation = c
            selectedCreation = nil
            selectedProduct = nil
            selectedCategory = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .category(let c):
            selectedCategory = c
            selectedCreation = nil
            selectedProduct = nil
            selectedConversation = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .browserSession(let s):
            selectedBrowserSession = s
            selectedCreation = nil
            selectedProduct = nil
            selectedConversation = nil
            selectedCategory = nil
            editedCode = nil
        }
    }

    func closeOtherTabs(except tab: OpenTabItem) {
        openTabs = openTabs.filter { $0.id == tab.id }
        activeTab = tab
        switch tab {
        case .creation(let c):
            selectedCreation = c
            editedCode = c.reactCode
            selectedProduct = nil
            selectedConversation = nil
            selectedCategory = nil
            selectedBrowserSession = nil
        case .product(let p):
            selectedProduct = p
            selectedCreation = nil
            selectedConversation = nil
            selectedCategory = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .conversation(let c):
            selectedConversation = c
            selectedCreation = nil
            selectedProduct = nil
            selectedCategory = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .category(let c):
            selectedCategory = c
            selectedCreation = nil
            selectedProduct = nil
            selectedConversation = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .browserSession(let s):
            selectedBrowserSession = s
            selectedCreation = nil
            selectedProduct = nil
            selectedConversation = nil
            selectedCategory = nil
            editedCode = nil
        }
    }

    func closeAllTabs() {
        openTabs.removeAll()
        activeTab = nil
        selectedCreation = nil
        selectedProduct = nil
        selectedConversation = nil
        selectedCategory = nil
        selectedBrowserSession = nil
        editedCode = nil
    }

    func closeTabsToRight(of tab: OpenTabItem) {
        guard let index = openTabs.firstIndex(where: { $0.id == tab.id }) else { return }
        openTabs = Array(openTabs.prefix(through: index))
        // If active tab was closed, switch to the reference tab
        if let active = activeTab, !openTabs.contains(where: { $0.id == active.id }) {
            switchToTab(tab)
        }
    }

    // MARK: - Conversations & Locations

    func loadConversations() async {
        guard let store = selectedStore else {
            NSLog("[EditorStore] No store selected, cannot load conversations")
            return
        }

        do {
            // Load locations first
            NSLog("[EditorStore] Loading locations for store: \(store.id)")
            locations = try await supabase.fetchLocations(storeId: store.id)
            NSLog("[EditorStore] Loaded \(locations.count) locations")

            // Load conversations
            NSLog("[EditorStore] Loading conversations for store: \(store.id)")
            conversations = try await supabase.fetchAllConversationsForStoreLocations(storeId: store.id, fetchLocations: { [weak self] storeId in
                guard let self = self else { return [] }
                return try await self.supabase.fetchLocations(storeId: storeId)
            })
            NSLog("[EditorStore] Loaded \(conversations.count) conversations")
        } catch {
            NSLog("[EditorStore] Failed to load conversations: \(error)")
            self.error = "Failed to load conversations: \(error.localizedDescription)"
        }
    }

    func openConversation(_ conversation: Conversation) {
        selectedConversation = conversation
        selectedCreation = nil
        selectedProduct = nil
        editedCode = nil
        openTab(.conversation(conversation))
    }

    func openLocationChat(_ location: Location) {
        // Find existing conversation for this location, or create a placeholder
        if let existingConvo = conversations.first(where: { $0.locationId == location.id }) {
            openConversation(existingConvo)
        } else {
            // Create a virtual conversation for this location (will be created on first message)
            let virtualConvo = Conversation(
                id: UUID(),
                storeId: selectedStore?.id,
                userId: nil,
                title: location.name,
                status: "new",
                messageCount: 0,
                chatType: "location",
                locationId: location.id,
                metadata: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            openConversation(virtualConvo)
        }
    }

    // MARK: - Browser Sessions

    func loadBrowserSessions() async {
        guard let store = selectedStore else {
            NSLog("[EditorStore] No store selected, cannot load browser sessions")
            return
        }

        do {
            NSLog("[EditorStore] Loading browser sessions for store: \(store.id)")
            browserSessions = try await supabase.fetchBrowserSessions(storeId: store.id)
            NSLog("[EditorStore] Loaded \(browserSessions.count) browser sessions")
        } catch {
            NSLog("[EditorStore] Failed to load browser sessions: \(error)")
            self.error = "Failed to load browser sessions: \(error.localizedDescription)"
        }
    }

    func openBrowserSession(_ session: BrowserSession) {
        selectedBrowserSession = session
        selectedCreation = nil
        selectedProduct = nil
        selectedConversation = nil
        editedCode = nil
        openTab(.browserSession(session))
    }

    func createNewBrowserSession() async {
        guard let store = selectedStore else {
            NSLog("[EditorStore] No store selected, cannot create browser session")
            return
        }

        do {
            let name = "Browser Session \(Date().formatted(date: .omitted, time: .shortened))"
            let newSession = try await supabase.createBrowserSession(storeId: store.id, name: name)

            // Add to list
            browserSessions.insert(newSession, at: 0)

            // Open the new session
            openBrowserSession(newSession)

            NSLog("[EditorStore] Created new browser session: \(newSession.id)")
        } catch {
            NSLog("[EditorStore] Failed to create browser session: \(error)")
            self.error = "Failed to create browser session: \(error.localizedDescription)"
        }
    }

    func closeBrowserSession(_ session: BrowserSession) async {
        do {
            try await supabase.closeBrowserSession(id: session.id)

            // Update in list
            if let index = browserSessions.firstIndex(where: { $0.id == session.id }) {
                var updatedSession = session
                updatedSession.status = "closed"
                browserSessions[index] = updatedSession
            }

            // Close tab if open
            closeTab(.browserSession(session))

            // Clean up the tab manager for this session
            BrowserTabManager.removeSession(session.id)

            // Deselect if selected
            if selectedBrowserSession?.id == session.id {
                selectedBrowserSession = nil
            }

            NSLog("[EditorStore] Closed browser session: \(session.id)")
        } catch {
            NSLog("[EditorStore] Failed to close browser session: \(error)")
            self.error = "Failed to close browser session: \(error.localizedDescription)"
        }
    }

    func refreshBrowserSession(_ session: BrowserSession) async {
        do {
            if let updated = try await supabase.fetchBrowserSession(id: session.id) {
                // Update in array
                if let index = browserSessions.firstIndex(where: { $0.id == session.id }) {
                    browserSessions[index] = updated
                }
                // Update selected if this is the selected one
                if selectedBrowserSession?.id == session.id {
                    selectedBrowserSession = updated
                }
                // Update in open tabs
                if let tabIndex = openTabs.firstIndex(where: {
                    if case .browserSession(let s) = $0, s.id == session.id { return true }
                    return false
                }) {
                    openTabs[tabIndex] = .browserSession(updated)
                }
                if case .browserSession(let s) = activeTab, s.id == session.id {
                    activeTab = .browserSession(updated)
                }
            }
        } catch {
            NSLog("[EditorStore] Failed to refresh browser session: \(error)")
        }
    }
}


