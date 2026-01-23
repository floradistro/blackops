import SwiftUI
import WebKit
import Supabase
import Foundation

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

    // MARK: - Computed Properties

    private var isBrowserView: Bool {
        if case .browserSession = store.activeTab {
            return true
        }
        return store.selectedBrowserSession != nil
    }

    private var isOnWelcomeScreen: Bool {
        store.activeTab == nil &&
        store.selectedBrowserSession == nil &&
        store.selectedCategory == nil &&
        store.selectedConversation == nil &&
        store.selectedProduct == nil &&
        store.selectedCreation == nil
    }

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

            case .conversation:
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

            case .cart(let queueEntry):
                CartPanel(store: store, queueEntry: queueEntry)
                    .id("cart-\(queueEntry.id)")

            case .customer(let customer):
                Text("Customer detail for \(customer.displayName)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .mcpServer(let server):
                MCPServerDetailView(server: server, store: store)
                    .id("mcp-\(server.id)")

            case .email(let email):
                ResendEmailDetailPanel(email: email, store: store)

            case .emailCampaign(let campaign):
                EmailCampaignDetailPanel(campaign: campaign, store: store)

            case .metaCampaign(let campaign):
                MetaCampaignDetailPanel(campaign: campaign, store: store)

            case .metaIntegration(let integration):
                MetaIntegrationDetailPanel(integration: integration, store: store)

            case .agentBuilder:
                AgentBuilderView(editorStore: store)
                    .id("agentbuilder")

            case .aiAgent(let agent):
                AgentConfigPanel(store: store, agent: agent)
                    .id("aiagent-\(agent.id)")
            }
        } else if let browserSession = store.selectedBrowserSession {
            SafariBrowserWindow(sessionId: browserSession.id)
                .id("browser-\(browserSession.id)")
        } else if let category = store.selectedCategory {
            CategoryConfigView(category: category, store: store)
        } else if store.selectedConversation != nil {
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
        } detail: {
            VStack(spacing: 0) {
                // Minimal tab bar - VS Code style
                if !isOnWelcomeScreen && !store.openTabs.isEmpty {
                    MinimalTabBar(store: store)
                }

                ZStack {
                    VisualEffectBackground(material: .underWindowBackground)
                        .ignoresSafeArea()

                    mainContentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar(.hidden, for: .automatic)
        }
        .navigationSplitViewStyle(.balanced)
    }

    var body: some View {
        navigationContent
            .animation(DesignSystem.Animation.spring, value: sidebarCollapsed)
            .notificationHandlers(
                store: store,
                sidebarCollapsed: $sidebarCollapsed,
                columnVisibility: $columnVisibility,
                showStoreSelectorSheet: $showStoreSelectorSheet,
                showNewMCPServerSheet: $showNewMCPServerSheet,
                showMCPMonitoringSheet: $showMCPMonitoringSheet
            )
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

    // MARK: - Catalog State (Products, Categories & Stores)
    @Published var stores: [Store] = []
    @Published var selectedStore: Store?
    @Published var catalogs: [Catalog] = []
    @Published var selectedCatalog: Catalog?
    @Published var products: [Product] = []
    @Published var categories: [Category] = []
    @Published var pricingSchemas: [PricingSchema] = []
    @Published var selectedProduct: Product?
    @Published var selectedProductIds: Set<UUID> = []
    @Published var isLoadingCatalogs = false

    // MARK: - Chat/Conversations State
    @Published var locations: [Location] = []
    @Published var selectedLocationIds: Set<UUID> = []
    @Published var conversations: [Conversation] = []
    @Published var selectedConversation: Conversation?
    @Published var isLoadingConversations = false

    // MARK: - Category Config State
    @Published var selectedCategory: Category?

    // MARK: - Browser Sessions State
    @Published var browserSessions: [BrowserSession] = []
    @Published var selectedBrowserSession: BrowserSession?
    @Published var sidebarBrowserExpanded = false
    @Published var isLoadingBrowserSessions = false

    // MARK: - Orders State
    @Published var orders: [Order] = []
    @Published var selectedOrder: Order?
    @Published var selectedLocation: Location?
    @Published var sidebarOrdersExpanded = false
    @Published var sidebarLocationsExpanded = false
    @Published var isLoadingOrders = false
    @Published var isLoadingLocations = false

    // Orders Realtime State
    @Published var ordersRealtimeConnected = false
    var ordersRealtimeChannel: RealtimeChannelV2?
    var ordersRealtimeTask: Task<Void, Never>?

    // MARK: - Queue State
    @Published var selectedQueue: Location?
    @Published var sidebarQueuesExpanded = false

    // MARK: - Customers State
    @Published var customers: [Customer] = []
    @Published var selectedCustomer: Customer?
    @Published var selectedCustomerIds: Set<UUID> = []
    @Published var sidebarCustomersExpanded = false
    @Published var customerSearchQuery: String = ""
    @Published var customerStats: CustomerStats?
    @Published var isLoadingCustomers = false

    // MARK: - MCP Servers State
    @Published var mcpServers: [MCPServer] = []
    @Published var selectedMCPServer: MCPServer?
    @Published var selectedMCPServerIds: Set<UUID> = []
    @Published var sidebarMCPServersExpanded = false
    @Published var isLoadingMCPServers = false

    // MARK: - AI Agents State
    @Published var aiAgents: [AIAgent] = []
    @Published var selectedAIAgent: AIAgent?
    @Published var sidebarAgentsExpanded = true
    @Published var isLoadingAgents = false
    var agentBuilderStore: AgentBuilderStore?

    // MARK: - Emails State (Resend)
    @Published var emails: [ResendEmail] = []
    @Published var selectedEmail: ResendEmail?
    @Published var sidebarEmailsExpanded = false
    @Published var isLoadingEmails = false
    @Published var emailTotalCount: Int = 0
    @Published var emailCategoryCounts: [String: Int] = [:]
    @Published var loadedCategories: Set<String> = [] // Track which categories have loaded emails

    // MARK: - CRM/Campaigns State
    @Published var emailCampaigns: [EmailCampaign] = []
    @Published var selectedEmailCampaign: EmailCampaign?
    @Published var metaCampaigns: [MetaCampaign] = []
    @Published var selectedMetaCampaign: MetaCampaign?
    @Published var metaIntegrations: [MetaIntegration] = []
    @Published var selectedMetaIntegration: MetaIntegration?
    @Published var smsCampaigns: [SMSCampaign] = []
    @Published var marketingCampaigns: [MarketingCampaign] = []
    @Published var sidebarCRMExpanded = false
    @Published var sidebarEmailCampaignsExpanded = false
    @Published var sidebarMetaCampaignsExpanded = false
    @Published var sidebarSMSCampaignsExpanded = false
    @Published var isLoadingCampaigns = false

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

    // MARK: - Section Group Collapse State
    @Published var workspaceGroupCollapsed = false
    @Published var contentGroupCollapsed = false
    @Published var operationsGroupCollapsed = false
    @Published var infrastructureGroupCollapsed = true // Start collapsed by default

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

// MARK: - Notification Handlers ViewModifier
// Groups all notification receivers into a single, efficient modifier

struct NotificationHandlersModifier: ViewModifier {
    @ObservedObject var store: EditorStore
    @Binding var sidebarCollapsed: Bool
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var showStoreSelectorSheet: Bool
    @Binding var showNewMCPServerSheet: Bool
    @Binding var showMCPMonitoringSheet: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: sidebarCollapsed) { _, collapsed in
                columnVisibility = collapsed ? .detailOnly : .all
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleSidebar"))) { _ in
                handleToggleSidebar()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SaveDocument"))) { _ in
                handleSaveDocument()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowStoreSelector"))) { _ in
                showStoreSelectorSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowNewStore"))) { _ in
                store.showNewStoreSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowserNewTab"))) { _ in
                handleBrowserCommand { session in
                    BrowserTabManager.forSession(session.id).newTab()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowserReload"))) { _ in
                handleBrowserCommand { session in
                    BrowserTabManager.forSession(session.id).activeTab?.refresh()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowserBack"))) { _ in
                handleBrowserCommand { session in
                    BrowserTabManager.forSession(session.id).activeTab?.goBack()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowserForward"))) { _ in
                handleBrowserCommand { session in
                    BrowserTabManager.forSession(session.id).activeTab?.goForward()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowMCPServers"))) { _ in
                store.sidebarMCPServersExpanded = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshMCPServers"))) { _ in
                Task { await store.loadMCPServers() }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowMCPDocs"))) { _ in
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseTab"))) { _ in
                handleCloseTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PreviousTab"))) { _ in
                handlePreviousTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NextTab"))) { _ in
                handleNextTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectTab1"))) { _ in
                selectTab(at: 0)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectTab2"))) { _ in
                selectTab(at: 1)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectTab3"))) { _ in
                selectTab(at: 2)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectTab4"))) { _ in
                selectTab(at: 3)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectTab5"))) { _ in
                selectTab(at: 4)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectTab6"))) { _ in
                selectTab(at: 5)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectTab7"))) { _ in
                selectTab(at: 6)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectTab8"))) { _ in
                selectTab(at: 7)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectTab9"))) { _ in
                selectLastTab()
            }
    }

    private func handleToggleSidebar() {
        withAnimation(DesignSystem.Animation.spring) {
            sidebarCollapsed.toggle()
        }
    }

    private func handleSaveDocument() {
        if store.hasUnsavedChanges {
            Task { await store.saveCurrentCreation() }
        }
    }

    private func handleBrowserCommand(_ action: (BrowserSession) -> Void) {
        if let session = getCurrentBrowserSession() {
            action(session)
        }
    }

    private func getCurrentBrowserSession() -> BrowserSession? {
        if let session = store.selectedBrowserSession {
            return session
        }
        if let activeTab = store.activeTab {
            if case .browserSession(let session) = activeTab {
                return session
            }
        }
        return nil
    }

    private func handleCloseTab() {
        if let activeTab = store.activeTab {
            store.closeTab(activeTab)
        }
    }

    private func handlePreviousTab() {
        guard let activeTab = store.activeTab,
              let index = store.openTabs.firstIndex(where: { $0.id == activeTab.id }),
              index > 0 else { return }
        store.switchToTab(store.openTabs[index - 1])
    }

    private func handleNextTab() {
        guard let activeTab = store.activeTab,
              let index = store.openTabs.firstIndex(where: { $0.id == activeTab.id }),
              index < store.openTabs.count - 1 else { return }
        store.switchToTab(store.openTabs[index + 1])
    }

    private func selectTab(at index: Int) {
        guard index < store.openTabs.count else { return }
        store.switchToTab(store.openTabs[index])
    }

    private func selectLastTab() {
        if !store.openTabs.isEmpty {
            store.switchToTab(store.openTabs[store.openTabs.count - 1])
        }
    }
}

extension View {
    func notificationHandlers(
        store: EditorStore,
        sidebarCollapsed: Binding<Bool>,
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        showStoreSelectorSheet: Binding<Bool>,
        showNewMCPServerSheet: Binding<Bool>,
        showMCPMonitoringSheet: Binding<Bool>
    ) -> some View {
        self.modifier(NotificationHandlersModifier(
            store: store,
            sidebarCollapsed: sidebarCollapsed,
            columnVisibility: columnVisibility,
            showStoreSelectorSheet: showStoreSelectorSheet,
            showNewMCPServerSheet: showNewMCPServerSheet,
            showMCPMonitoringSheet: showMCPMonitoringSheet
        ))
    }
}
