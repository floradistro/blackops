import SwiftUI
import WebKit
import Supabase
import Foundation
import AppKit

// MARK: - Label Printer Settings (stub - file not in Xcode project)
// TODO: Add LabelPrinterSettings.swift to Xcode project membership

final class LabelPrinterSettings: ObservableObject {
    @MainActor static let shared = LabelPrinterSettings()

    @Published var isAutoPrintEnabled: Bool = false
    @Published var printerName: String? = nil
    @Published var startPosition: Int = 0
    @Published var selectedRegisterId: UUID? = nil
    @Published var selectedRegisterName: String? = nil

    var isReadyToAutoPrint: Bool { isAutoPrintEnabled && printerName != nil }
    var isPrinterConfigured: Bool { printerName != nil }
    var autoPrintEnabled: Bool { isAutoPrintEnabled }

    private init() {
        self.isAutoPrintEnabled = UserDefaults.standard.bool(forKey: "labelAutoPrintEnabled")
        self.printerName = UserDefaults.standard.string(forKey: "labelPrinterName")
        self.startPosition = UserDefaults.standard.integer(forKey: "labelStartPosition")
        if let idString = UserDefaults.standard.string(forKey: "posSelectedRegisterId") {
            self.selectedRegisterId = UUID(uuidString: idString)
        }
        self.selectedRegisterName = UserDefaults.standard.string(forKey: "posSelectedRegisterName")
    }

    func selectRegister(_ register: Register) {
        selectedRegisterId = register.id
        selectedRegisterName = register.displayName
    }

    func clearRegister() {
        selectedRegisterId = nil
        selectedRegisterName = nil
    }
}

// MARK: - POS Settings View (stub)
struct POSSettingsView: View {
    @ObservedObject var store: EditorStore
    let locationId: UUID

    var body: some View {
        VStack(spacing: 16) {
            Text("POS Settings")
                .font(.headline)
            Text("Register & Printer configuration")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}

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

    // MARK: - Main Navigation View (chromeless)

    @ViewBuilder
    private var navigationContent: some View {
        HStack(spacing: 0) {
            // Sidebar
            if columnVisibility != .detailOnly {
                SidebarPanel(store: store, sidebarCollapsed: $sidebarCollapsed)
                    .frame(width: 240)

                // Sidebar border
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1)
            }

            // Main content
            VStack(spacing: 0) {
                // Tab bar with traffic light space
                if !store.openTabs.isEmpty {
                    MinimalTabBar(store: store)
                } else if !isOnWelcomeScreen {
                    // Empty draggable area for traffic lights
                    Color.clear
                        .frame(height: 36)
                        .background(Color(nsColor: .windowBackgroundColor))
                }

                // Content
                ZStack {
                    VisualEffectBackground(material: .underWindowBackground)
                        .ignoresSafeArea()

                    mainContentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .ignoresSafeArea()
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
        withAnimation(.easeOut(duration: 0.2)) {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
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

// MARK: - Native Editor View
// Sleek, minimal macOS-native navigation using NavigationSplitView
// Tabs integrated into system toolbar for true native feel

struct NativeEditorView: View {
    @StateObject private var store = EditorStore()
    @EnvironmentObject var authManager: AuthManager

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText = ""
    @State private var selectedTab: EditorTab = .preview

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Native Sidebar
            NativeSidebarContent(store: store, searchText: $searchText)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 320)
        } detail: {
            // Detail Area - content only, tabs are in toolbar
            nativeMainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(store.activeTab?.id ?? "welcome")
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: columnVisibility)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
        .toolbar {
            // Leading: Store selector
            ToolbarItem(placement: .navigation) {
                NativeStoreSelector(store: store)
            }

            // Center: Integrated tab bar
            ToolbarItem(placement: .principal) {
                ToolbarTabBar(store: store)
            }

            // Trailing: Actions
            ToolbarItemGroup(placement: .primaryAction) {
                // Context actions for active tab
                if let activeTab = store.activeTab {
                    ToolbarContextActions(tab: activeTab, store: store)
                }

                Menu {
                    Button("New Creation...") { store.showNewCreationSheet = true }
                    Button("New Collection...") { store.showNewCollectionSheet = true }
                    Divider()
                    Button("New Category...") { store.showNewCategorySheet = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .menuStyle(.borderlessButton)
            }
        }
        .toolbarBackground(.visible, for: .windowToolbar)
        .environmentObject(store)
        .task {
            await store.loadCreations()
            await store.loadStores()
            await store.loadCatalog()
        }
        .sheet(isPresented: $store.showNewCreationSheet) { NewCreationSheet(store: store) }
        .sheet(isPresented: $store.showNewCollectionSheet) { NewCollectionSheet(store: store) }
        .sheet(isPresented: $store.showNewStoreSheet) { NewStoreSheet(store: store, authManager: authManager) }
        .sheet(isPresented: $store.showNewCatalogSheet) { NewCatalogSheet(store: store) }
        .sheet(isPresented: $store.showNewCategorySheet) { NewCategorySheet(store: store) }
        .alert("Error", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }

    @ViewBuilder
    private var nativeMainContent: some View {
        if let activeTab = store.activeTab {
            nativeContentForTab(activeTab)
        } else if let creation = store.selectedCreation {
            nativeCreationContent(creation)
        } else {
            WelcomeView(store: store)
        }
    }

    @ViewBuilder
    private func nativeContentForTab(_ tab: OpenTabItem) -> some View {
        switch tab {
        case .creation(let creation): nativeCreationContent(creation)
        case .product(let product): ProductEditorPanel(product: product, store: store)
        case .conversation(let conv):
            TeamChatView(store: store)
                .onAppear { store.selectedConversation = conv }
        case .category(let category): CategoryConfigView(category: category, store: store)
        case .browserSession(let session): SafariBrowserWindow(sessionId: session.id)
        case .order(let order): OrderDetailPanel(order: order, store: store)
        case .location(let location): LocationDetailPanel(location: location, store: store)
        case .queue(let location): Text("Queue: \(location.name)")
        case .cart(let entry): CartPanel(store: store, queueEntry: entry)
        case .customer(let customer): Text("Customer: \(customer.displayName)").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .mcpServer(let server): MCPServerDetailView(server: server, store: store)
        case .email(let email): ResendEmailDetailPanel(email: email, store: store)
        case .emailCampaign(let campaign): EmailCampaignDetailPanel(campaign: campaign, store: store)
        case .metaCampaign(let campaign): MetaCampaignDetailPanel(campaign: campaign, store: store)
        case .metaIntegration(let integration): MetaIntegrationDetailPanel(integration: integration, store: store)
        case .agentBuilder: AgentBuilderView(editorStore: store)
        case .aiAgent(let agent): AgentConfigPanel(store: store, agent: agent)
        }
    }

    @ViewBuilder
    private func nativeCreationContent(_ creation: Creation) -> some View {
        switch selectedTab {
        case .preview: HotReloadRenderer(code: store.editedCode ?? creation.reactCode ?? "", creationId: creation.id.uuidString, refreshTrigger: store.refreshTrigger)
        case .code: CodeEditorPanel(code: Binding(get: { store.editedCode ?? creation.reactCode ?? "" }, set: { store.editedCode = $0 }), onSave: { Task { await store.saveCurrentCreation() } })
        case .details: DetailsPanel(creation: creation, store: store)
        case .settings: SettingsPanel(creation: creation, store: store)
        }
    }
}

// MARK: - Native Store Selector with Smooth Animations

private struct NativeStoreSelector: View {
    @ObservedObject var store: EditorStore
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var chevronRotation: Double = 0

    var body: some View {
        Menu {
            ForEach(store.stores) { storeItem in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        store.selectedStore = storeItem
                    }
                } label: {
                    HStack {
                        Text(storeItem.storeName)
                        if store.selectedStore?.id == storeItem.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            if !store.stores.isEmpty { Divider() }
            Button("New Store...") { store.showNewStoreSheet = true }
        } label: {
            HStack(spacing: 4) {
                Text(store.selectedStore?.storeName ?? "Select Store")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.95 : 0.8))
                    .contentTransition(.interpolate)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.6 : 0.4))
                    .rotationEffect(.degrees(isPressed ? 180 : 0))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(isHovered ? 0.08 : 0))
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .menuStyle(.borderlessButton)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: store.selectedStore?.id)
    }
}

// MARK: - Toolbar Integrated Tab Bar
// Safari/Finder-style tabs in the system toolbar

struct ToolbarTabBar: View {
    @ObservedObject var store: EditorStore
    @Namespace private var tabNamespace

    var body: some View {
        Group {
            if store.openTabs.isEmpty {
                // Empty state - show app name or nothing
                Text("SwagManager")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.6))
            } else {
                // Tab bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(store.openTabs) { tab in
                            ToolbarTab(
                                tab: tab,
                                isActive: store.activeTab?.id == tab.id,
                                hasUnsavedChanges: tabHasChanges(tab),
                                namespace: tabNamespace,
                                onSelect: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        store.switchToTab(tab)
                                    }
                                },
                                onClose: {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                                        store.closeTab(tab)
                                    }
                                },
                                onCloseOthers: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        store.openTabs.filter { $0.id != tab.id }.forEach { store.closeTab($0) }
                                    }
                                },
                                onCloseAll: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        store.openTabs.forEach { store.closeTab($0) }
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.85).combined(with: .opacity),
                                removal: .scale(scale: 0.85).combined(with: .opacity)
                            ))
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxWidth: 500) // Limit width so it doesn't take over toolbar
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: store.openTabs.map(\.id))
            }
        }
    }

    private func tabHasChanges(_ tab: OpenTabItem) -> Bool {
        if case .creation(let c) = tab, c.id == store.selectedCreation?.id { return store.hasUnsavedChanges }
        return false
    }
}

// MARK: - Individual Toolbar Tab

struct ToolbarTab: View {
    let tab: OpenTabItem
    let isActive: Bool
    let hasUnsavedChanges: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void
    let onClose: () -> Void
    var onCloseOthers: (() -> Void)? = nil
    var onCloseAll: (() -> Void)? = nil

    @State private var isHovered = false
    @State private var isCloseHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Icon
                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(isActive ? 0.8 : 0.5))

                // Title
                Text(tab.name)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(Color.primary.opacity(isActive ? 0.9 : 0.65))
                    .lineLimit(1)
                    .frame(maxWidth: 100)

                // Close / Unsaved indicator
                ZStack {
                    if hasUnsavedChanges && !isHovered {
                        Circle()
                            .fill(Color.orange.opacity(0.8))
                            .frame(width: 6, height: 6)
                    } else if isHovered || isActive {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.primary.opacity(isCloseHovered ? 0.8 : 0.4))
                                .frame(width: 14, height: 14)
                                .background(
                                    Circle()
                                        .fill(Color.primary.opacity(isCloseHovered ? 0.12 : 0))
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { isCloseHovered = $0 }
                    }
                }
                .frame(width: 14, height: 14)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.1))
                        .matchedGeometryEffect(id: "activeToolbarTab", in: namespace)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
        .contextMenu {
            Button("Close") { onClose() }
            if let closeOthers = onCloseOthers {
                Button("Close Others") { closeOthers() }
            }
            if let closeAll = onCloseAll {
                Button("Close All") { closeAll() }
            }
        }
    }
}

// MARK: - Toolbar Context Actions
// Shows relevant actions based on active tab type

struct ToolbarContextActions: View {
    let tab: OpenTabItem
    @ObservedObject var store: EditorStore

    var body: some View {
        Group {
            switch tab {
            case .creation:
                Button {
                    Task { await store.saveCurrentCreation() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12))
                }
                .help("Save")
                .disabled(!store.hasUnsavedChanges)

            case .browserSession:
                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("BrowserReload"), object: nil)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .help("Reload")

            case .product:
                Button {
                    // Refresh product
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .help("Refresh")

            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Slim Tab Bar (28pt - thinner than default) with Smooth Animations
// Kept for fallback / old EditorView

struct SlimTabBar: View {
    @ObservedObject var store: EditorStore
    @Namespace private var tabAnimation

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(store.openTabs) { tab in
                        SlimTab(
                            tab: tab,
                            isActive: store.activeTab?.id == tab.id,
                            hasUnsavedChanges: tabHasChanges(tab),
                            namespace: tabAnimation,
                            onSelect: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    store.switchToTab(tab)
                                }
                            },
                            onClose: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    store.closeTab(tab)
                                }
                            }
                        )
                        .id(tab.id)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal, 8)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.openTabs.map(\.id))
            }
            .onChange(of: store.activeTab?.id) { _, newId in
                if let id = newId {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 28)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1), alignment: .bottom)
    }

    private func tabHasChanges(_ tab: OpenTabItem) -> Bool {
        if case .creation(let c) = tab, c.id == store.selectedCreation?.id { return store.hasUnsavedChanges }
        return false
    }
}

// MARK: - Slim Tab with Smooth Hover & Spring Animations

struct SlimTab: View {
    let tab: OpenTabItem
    let isActive: Bool
    let hasUnsavedChanges: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @State private var isCloseHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(isActive ? 0.7 : 0.4))
                    .symbolEffect(.bounce.byLayer, value: isActive)
                Text(tab.name)
                    .font(.system(size: 11, weight: isActive ? .medium : .regular))
                    .foregroundStyle(Color.primary.opacity(isActive ? 0.85 : 0.55))
                    .lineLimit(1)
                ZStack {
                    if hasUnsavedChanges && !isHovered {
                        Circle()
                            .fill(Color.primary.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .transition(.scale.combined(with: .opacity))
                    } else if isHovered || isActive {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(Color.primary.opacity(isCloseHovered ? 0.7 : 0.4))
                                .frame(width: 14, height: 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.primary.opacity(isCloseHovered ? 0.1 : 0))
                                )
                                .scaleEffect(isCloseHovered ? 1.1 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                isCloseHovered = hovering
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 14, height: 14)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: hasUnsavedChanges)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background {
                ZStack {
                    // Active indicator with matched geometry
                    if isActive {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.primary.opacity(0.08))
                            .matchedGeometryEffect(id: "activeTab", in: namespace)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 2)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.primary.opacity(0.04))
                            .padding(.vertical, 3)
                            .padding(.horizontal, 2)
                    }
                }
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
        .contextMenu {
            Button("Close") { onClose() }
            Divider()
            Button("Close Others") { }
            Button("Close All") { }
        }
    }
}

// MARK: - Native Sidebar Content

struct NativeSidebarContent: View {
    @ObservedObject var store: EditorStore
    @Binding var searchText: String

    // Spring animation for disclosure groups - the "mac magic"
    private let disclosureAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.1)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                // WORKSPACE
                SidebarSectionHeader(title: "WORKSPACE")

                ExpandableSection(
                    title: "Queues",
                    icon: "line.3.horizontal",
                    count: store.locations.count,
                    isExpanded: $store.sidebarQueuesExpanded
                ) {
                    ForEach(store.locations) { loc in
                        NativeSidebarQueueRow(location: loc, store: store)
                    }
                }

                ExpandableSection(
                    title: "Locations",
                    icon: "mappin.and.ellipse",
                    count: store.orders.count,
                    isLoading: store.isLoadingOrders,
                    isExpanded: $store.sidebarLocationsExpanded
                ) {
                    ForEach(store.locations) { loc in
                        NativeSidebarLocationRow(location: loc, store: store)
                    }
                }

                Divider().padding(.vertical, 8)

                // CONTENT
                SidebarSectionHeader(title: "CONTENT")

                ExpandableSection(
                    title: "Catalog",
                    icon: "square.grid.2x2",
                    count: store.products.count,
                    isExpanded: $store.sidebarCatalogExpanded
                ) {
                    ForEach(store.categories) { cat in
                        NativeSidebarCategoryRow(category: cat, store: store)
                    }
                }

                ExpandableSection(
                    title: "Creations",
                    icon: "doc.text",
                    count: store.creations.count,
                    isExpanded: $store.sidebarCreationsExpanded
                ) {
                    ForEach(filteredCreations) { creation in
                        NativeSidebarCreationRow(creation: creation, store: store)
                    }
                }

                ExpandableSection(
                    title: "Team Chat",
                    icon: "bubble.left.and.bubble.right",
                    count: store.conversations.count,
                    isExpanded: $store.sidebarChatExpanded
                ) {
                    ForEach(store.conversations) { conv in
                        SidebarItemButton(icon: "bubble.left", title: conv.title ?? "Chat") {
                            store.openTab(.conversation(conv))
                        }
                    }
                }

                Divider().padding(.vertical, 8)

                // OPERATIONS
                SidebarSectionHeader(title: "OPERATIONS")

                ExpandableSection(
                    title: "Browser",
                    icon: "globe",
                    count: store.browserSessions.count,
                    isExpanded: $store.sidebarBrowserExpanded
                ) {
                    ForEach(store.browserSessions) { session in
                        SidebarItemButton(icon: "safari", title: session.name ?? "Browser") {
                            store.openTab(.browserSession(session))
                        }
                    }
                    SidebarItemButton(icon: "plus", title: "New Session", isSubtle: true) {
                        Task { await store.createNewBrowserSession() }
                    }
                }

                Divider().padding(.vertical, 8)

                // INFRASTRUCTURE
                SidebarSectionHeader(title: "INFRASTRUCTURE")

                ExpandableSection(
                    title: "Agents",
                    icon: "cpu",
                    count: store.aiAgents.count,
                    isExpanded: $store.sidebarAgentsExpanded
                ) {
                    ForEach(store.aiAgents) { agent in
                        SidebarItemButton(icon: "cpu", title: agent.name ?? "Agent", showDot: agent.isActive, dotColor: .green) {
                            store.openTab(.aiAgent(agent))
                        }
                    }
                }

                SidebarItemButton(icon: "hammer", title: "Agent Builder") {
                    store.openTab(.agentBuilder)
                }
                .padding(.leading, 4)

                ExpandableSection(
                    title: "MCP Servers",
                    icon: "server.rack",
                    count: store.mcpServers.count,
                    isExpanded: $store.sidebarMCPServersExpanded
                ) {
                    ForEach(store.mcpServers) { server in
                        SidebarItemButton(icon: "server.rack", title: server.name, showDot: server.isActive == true, dotColor: .green) {
                            store.openTab(.mcpServer(server))
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
        }
        .scrollContentBackground(.hidden)
        .task { await loadData() }
        .onChange(of: store.selectedStore?.id) { _, _ in Task { await loadData() } }
    }

    private var filteredCreations: [Creation] {
        searchText.isEmpty ? store.creations : store.creations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func loadData() async {
        guard store.selectedStore != nil else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await store.loadBrowserSessions() }
            group.addTask { await store.loadOrders() }
            group.addTask { await store.loadLocations() }
            group.addTask { await store.loadAIAgents() }
            group.addTask { await store.loadMCPServers() }
        }
    }
}

// MARK: - Native Sidebar Helper Views

// MARK: Custom expandable section with double-click and large hit area
// Replaces DisclosureGroup for better UX - entire row is clickable, double-click expands
private struct ExpandableSection<Content: View>: View {
    let title: String
    let icon: String
    let count: Int
    var isLoading: Bool = false
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false
    @State private var isPressed = false

    private let animation: Animation = .spring(response: 0.3, dampingFraction: 0.8)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - entire row is clickable
            HStack(spacing: 8) {
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.6 : 0.35))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(animation, value: isExpanded)
                    .frame(width: 12)

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.7 : 0.5))
                    .symbolEffect(.pulse, isActive: isLoading)
                    .frame(width: 16)

                // Title
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.95 : 0.8))

                Spacer(minLength: 4)

                // Count/Loading
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .contentTransition(.numericText())
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
            )
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
            }
            .onTapGesture(count: 2) {
                // Double-click to expand/collapse
                withAnimation(animation) { isExpanded.toggle() }
            }
            .onTapGesture(count: 1) {
                // Single click also toggles (fallback)
                withAnimation(animation) { isExpanded.toggle() }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in withAnimation(.spring(response: 0.08, dampingFraction: 0.6)) { isPressed = true } }
                    .onEnded { _ in withAnimation(.spring(response: 0.12, dampingFraction: 0.6)) { isPressed = false } }
            )

            // Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    content()
                }
                .padding(.leading, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(animation, value: isExpanded)
    }
}

// MARK: Section header for sidebar groups
private struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.primary.opacity(0.35))
            .padding(.leading, 12)
            .padding(.top, 4)
            .padding(.bottom, 2)
    }
}

// MARK: Reusable sidebar item button with generous hit area
private struct SidebarItemButton: View {
    let icon: String?
    let title: String
    var badge: String? = nil
    var showDot: Bool = false
    var dotColor: Color = .primary
    var isSubtle: Bool = false
    let action: () -> Void

    init(icon: String?, title: String, badge: String? = nil, showDot: Bool = false, dotColor: Color = .primary, isSubtle: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.badge = badge
        self.showDot = showDot
        self.dotColor = dotColor
        self.isSubtle = isSubtle
        self.action = action
    }

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(isSubtle ? 0.35 : isHovered ? 0.6 : 0.45))
                        .frame(width: 14)
                }
                if showDot {
                    Circle()
                        .fill(dotColor.opacity(0.6))
                        .frame(width: 6, height: 6)
                }
                Text(title)
                    .font(.system(size: 12, weight: isHovered ? .medium : .regular))
                    .foregroundStyle(Color.primary.opacity(isSubtle ? 0.5 : isHovered ? 0.9 : 0.75))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.45))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
            )
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.08, dampingFraction: 0.6)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.12, dampingFraction: 0.6)) { isPressed = false } }
        )
    }
}

// Reusable animated sidebar row with hover, press, and selection states
// Generous hit targets for comfortable clicking (minimum 28pt height per Apple HIG)
private struct AnimatedSidebarRow: View {
    let icon: String
    let title: String
    var isActive: Bool = false
    var isSubtle: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(isSubtle ? 0.4 : isHovered ? 0.7 : 0.5))
                    .symbolEffect(.bounce.byLayer, value: isPressed)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: isHovered ? .medium : .regular))
                    .foregroundStyle(Color.primary.opacity(isSubtle ? 0.5 : isHovered ? 0.9 : 0.75))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if isActive {
                    Circle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.1, dampingFraction: 0.6)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) { isPressed = false }
                }
        )
        .listRowBackground(Color.clear)
    }
}

private struct NativeSidebarLabel: View {
    let title: String
    let icon: String
    let count: Int
    var isLoading: Bool = false

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(isHovered ? 0.7 : 0.5))
                .symbolEffect(.pulse, isActive: isLoading)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 16)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primary.opacity(isHovered ? 0.95 : 0.8))
            Spacer(minLength: 4)
            if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 14, height: 14)
                    .transition(.scale.combined(with: .opacity))
            } else if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 24)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: count)
        .onHover { isHovered = $0 }
    }
}

private struct NativeSidebarQueueRow: View {
    let location: Location
    @ObservedObject var store: EditorStore
    @StateObject private var queueStore: LocationQueueStore

    @State private var isExpanded = false
    @State private var isHovered = false

    init(location: Location, store: EditorStore) {
        self.location = location
        self.store = store
        self._queueStore = StateObject(wrappedValue: LocationQueueStore.shared(for: location.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header row - full width clickable
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.3))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)
                Image(systemName: "person.3")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.6 : 0.45))
                    .frame(width: 14)
                Text(location.name)
                    .font(.system(size: 12, weight: isHovered ? .medium : .regular))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.9 : 0.75))
                Spacer(minLength: 4)
                if queueStore.count > 0 {
                    Text("\(queueStore.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(isHovered ? 0.05 : 0)))
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture(count: 2) { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }
            .onTapGesture(count: 1) { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }

            // Expanded content
            if isExpanded {
                ForEach(queueStore.queue) { entry in
                    SidebarItemButton(
                        icon: nil,
                        title: entry.customerFirstName.map { "\($0) \(entry.customerLastName ?? "")" } ?? "Guest",
                        badge: entry.cartItemCount > 0 ? "\(entry.cartItemCount)" : nil,
                        showDot: entry.cartItemCount > 0,
                        dotColor: .blue
                    ) {
                        store.openTab(.cart(entry))
                    }
                    .padding(.leading, 16)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
        .task { await queueStore.loadQueue(); queueStore.subscribeToRealtime() }
    }
}

private struct NativeSidebarLocationRow: View {
    let location: Location
    @ObservedObject var store: EditorStore

    @State private var isExpanded = false
    @State private var isHovered = false

    var orders: [Order] { store.ordersForLocation(location.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.3))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.6 : 0.45))
                    .frame(width: 14)
                Text(location.name)
                    .font(.system(size: 12, weight: isHovered ? .medium : .regular))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.9 : 0.75))
                if location.isActive == true {
                    Circle().fill(Color.green.opacity(0.6)).frame(width: 5, height: 5)
                }
                Spacer(minLength: 4)
                Text("\(orders.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(isHovered ? 0.05 : 0)))
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture(count: 2) { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }
            .onTapGesture(count: 1) { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }

            // Expanded content
            if isExpanded {
                ForEach(orders.prefix(10)) { order in
                    SidebarItemButton(icon: nil, title: order.displayTitle, badge: order.displayTotal, showDot: true, dotColor: .orange) {
                        store.openOrder(order)
                    }
                    .padding(.leading, 16)
                }
                if orders.count > 10 {
                    Text("\(orders.count - 10) more...")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .padding(.vertical, 4)
                        .padding(.leading, 40)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }
}

private struct NativeSidebarCategoryRow: View {
    let category: Category
    @ObservedObject var store: EditorStore

    @State private var isExpanded = false
    @State private var isHovered = false

    var products: [Product] { store.products.filter { $0.primaryCategoryId == category.id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.3))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.6 : 0.45))
                    .frame(width: 14)
                Text(category.name)
                    .font(.system(size: 12, weight: isHovered ? .medium : .regular))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.9 : 0.75))
                Spacer(minLength: 4)
                Text("\(products.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(isHovered ? 0.05 : 0)))
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture(count: 2) { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }
            .onTapGesture(count: 1) { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }

            // Expanded content
            if isExpanded {
                ForEach(products) { product in
                    SidebarItemButton(icon: "tag", title: product.name, badge: product.displayPrice) {
                        store.openTab(.product(product))
                    }
                    .padding(.leading, 16)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }
}

private struct NativeSidebarCreationRow: View {
    let creation: Creation
    @ObservedObject var store: EditorStore

    @State private var isHovered = false
    @State private var isPressed = false

    private var isSelected: Bool { store.selectedCreation?.id == creation.id }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                store.openTab(.creation(creation))
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: creation.creationType.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(isSelected ? 0.8 : isHovered ? 0.65 : 0.5))
                    .symbolEffect(.bounce.byLayer, value: isSelected)
                    .frame(width: 16)
                Text(creation.name)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(Color.primary.opacity(isSelected ? 0.95 : isHovered ? 0.85 : 0.75))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Circle()
                    .fill(creation.status == .published ? Color.green.opacity(0.6) : Color.primary.opacity(0.2))
                    .frame(width: 6, height: 6)
                    .scaleEffect(isHovered ? 1.2 : 1.0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(isSelected ? 0.1 : isHovered ? 0.05 : 0))
            )
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.08, dampingFraction: 0.6)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.12, dampingFraction: 0.6)) { isPressed = false } }
        )
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
    }
}
