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
    var realtimeTask: Task<Void, Never>?

    // Default store ID for new items
    let defaultStoreId = UUID(uuidString: "cd2e1122-d511-4edb-be5d-98ef274b4baf")!

    init() {
        startRealtimeSubscription()
    }

    deinit {
        realtimeTask?.cancel()
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


