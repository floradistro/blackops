import SwiftUI
import WebKit
import Supabase

// MARK: - Main Editor View
// Refactored following Apple engineering standards - extracted utilities and store extensions
// JSONDecoder extension moved to Utilities/SupabaseDecoder.swift
// EditorStore methods moved to Stores/EditorStore+*.swift extensions

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

                case .order(let order):
                    OrderDetailPanel(order: order, store: store)

                case .location(let location):
                    LocationDetailPanel(location: location, store: store)

                case .queue(let location):
                    LocationQueueView(locationId: location.id)
                        .id("queue-\(location.id)")

                case .customer(let customer):
                    CustomerDetailPanel(customer: customer, store: store)

                case .mcpServer(let server):
                    MCPServerDetailPanel(server: server, store: store)
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

    // MARK: - MCP Servers State
    @Published var mcpServers: [MCPServer] = []
    @Published var selectedMCPServer: MCPServer?
    @Published var sidebarMCPExpanded = false

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

    // Additional EditorStore methods extracted to extensions:
    // - EditorStore+Zoom.swift: Zoom in/out/reset functions
    // - EditorStore+Creation.swift: Creation and collection management
    // - EditorStore+Conversations.swift: Conversations and locations
    // - EditorStore+BrowserSessions.swift: Browser session management
}


