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
    @State private var showNewMCPServerSheet = false
    @State private var showMCPMonitoringSheet = false

    // MARK: - Main Content View

    @ViewBuilder
    private var mainContentView: some View {
        if let activeTab = store.activeTab {
            switch activeTab {
            case .creation(let creation):
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
                ProductEditorPanel(product: product, store: store)

            case .conversation(let conversation):
                TeamChatView(store: store)

            case .category(let category):
                CategoryConfigView(category: category, store: store)

            case .browserSession(let session):
                SafariBrowserWindow(sessionId: session.id)
                    .id("browser-\(session.id)")

            case .order(let order):
                OrderDetailPanel(order: order, store: store)

            case .location(let location):
                LocationDetailPanel(location: location, store: store)

            case .queue(let location):
                Text("Queue view for \(location.name)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id("queue-\(location.id)")

            case .customer(let customer):
                Text("Customer detail for \(customer.displayName)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .mcpServer(let server):
                MCPServerDetailView(server: server, store: store)

            case .email(let email):
                ResendEmailDetailPanel(email: email, store: store)
            }
        } else if let browserSession = store.selectedBrowserSession {
            SafariBrowserWindow(sessionId: browserSession.id)
                .id("browser-\(browserSession.id)")
        } else if let category = store.selectedCategory {
            CategoryConfigView(category: category, store: store)
        } else if let conversation = store.selectedConversation {
            TeamChatView(store: store)
        } else if let product = store.selectedProduct {
            ProductEditorPanel(product: product, store: store)
        } else if let creation = store.selectedCreation {
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
            WelcomeView(store: store)
        }
    }

    // MARK: - Main Navigation View (unzoomed)

    @ViewBuilder
    private var navigationContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarPanel(store: store, sidebarCollapsed: $sidebarCollapsed)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
                .toolbarBackground(.hidden, for: .windowToolbar)
        } detail: {
            ZStack {
                VisualEffectBackground(material: .underWindowBackground)
                    .ignoresSafeArea()

                mainContentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    FloatingContextBar(store: store)
                }

                if case .browserSession = store.activeTab {
                    UnifiedToolbarContent(store: store)
                } else if store.selectedBrowserSession != nil {
                    UnifiedToolbarContent(store: store)
                }
            }
            .toolbarBackground(.hidden, for: .windowToolbar)
        }
        .navigationSplitViewStyle(.balanced)
    }

    var body: some View {
        navigationContent
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowMCPServers"))) { _ in
            store.sidebarMCPServersExpanded = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshMCPServers"))) { _ in
            Task {
                await store.loadMCPServers()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowMCPDocs"))) { _ in
            // Open MCP documentation URL
            if let url = URL(string: "https://modelcontextprotocol.io/docs") {
                NSWorkspace.shared.open(url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewMCPServer"))) { _ in
            showNewMCPServerSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MonitorMCPServers"))) { _ in
            showMCPMonitoringSheet = true
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
        .sheet(isPresented: $showNewMCPServerSheet) {
            Text("MCP Editor")
                .frame(minWidth: 700, minHeight: 600)
        }
        .sheet(isPresented: $showMCPMonitoringSheet) {
            Text("MCP Monitoring")
                .frame(minWidth: 900, minHeight: 700)
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

    // MARK: - Catalog State (Pgerroducts, Categories & Stores)
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

    // MARK: - Orders State
    @Published var orders: [Order] = []
    @Published var selectedOrder: Order?
    @Published var selectedLocation: Location?
    @Published var sidebarOrdersExpanded = false
    @Published var sidebarLocationsExpanded = false

    // MARK: - Queue State
    @Published var selectedQueue: Location?
    @Published var sidebarQueuesExpanded = false

    // MARK: - Customers State
    @Published var customers: [Customer] = []
    @Published var selectedCustomer: Customer?
    @Published var sidebarCustomersExpanded = false
    @Published var customerSearchQuery: String = ""
    @Published var customerStats: CustomerStats?

    // MARK: - MCP Servers State
    @Published var mcpServers: [MCPServer] = []
    @Published var selectedMCPServer: MCPServer?
    @Published var sidebarMCPServersExpanded = false

    // MARK: - Emails State (Resend)
    @Published var emails: [ResendEmail] = []
    @Published var selectedEmail: ResendEmail?
    @Published var sidebarEmailsExpanded = false

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


