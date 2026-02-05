import SwiftUI
import SwiftData

// MARK: - Apple-Style Content View
// Settings-style navigation: flat sidebar + drill-down detail with back navigation
// Sidebar shows top-level sections, detail view uses NavigationStack for breadcrumb nav

struct AppleContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store = EditorStore()
    @State private var syncService = SyncService.shared

    @State private var selectedItem: SDSidebarItem? = nil
    @State private var navigationPath = NavigationPath()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showAIChat = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            MainSidebar(selection: $selectedItem, store: store, syncService: syncService)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        } detail: {
            NavigationStack(path: $navigationPath) {
                MainDetailView(selection: $selectedItem, store: store)
                    .navigationDestination(for: SDSidebarItem.self) { item in
                        DetailDestination(item: item, store: store, selection: $selectedItem)
                    }
            }
        }
        .inspector(isPresented: $showAIChat) {
            AIChatPane()
                .environment(store)
                .inspectorColumnWidth(min: 320, ideal: 420, max: 600)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                StoreDropdown(store: store)
            }

            ToolbarItem(placement: .primaryAction) {
                if store.isLoading || syncService.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await store.loadStores()
                        await syncService.syncAll()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh all data")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAIChat.toggle()
                    }
                } label: {
                    Label("AI Chat", systemImage: showAIChat ? "sidebar.trailing" : "sidebar.trailing")
                }
                .help(showAIChat ? "Hide AI Chat" : "Show AI Chat")
            }
        }
        .toolbarBackground(.visible, for: .windowToolbar)
        .onChange(of: selectedItem) { _, _ in
            // Clear navigation path when sidebar selection changes
            navigationPath = NavigationPath()
        }
        .task {
            await store.loadStores()
            if let storeId = store.selectedStore?.id {
                syncService.configure(modelContext: modelContext, storeId: storeId)
                await loadAllData()
            }
        }
        .onChange(of: store.selectedStore?.id) { _, newId in
            if let storeId = newId {
                syncService.configure(modelContext: modelContext, storeId: storeId)
                Task { await loadAllData() }
            }
        }
    }

    /// Load all data for the current store - PHASED for performance
    /// Phase 1: Critical data for sidebar (fast, blocks UI)
    /// Phase 2: Secondary data (background, non-blocking)
    private func loadAllData() async {
        // PHASE 1: Critical data needed for initial UI render (run in parallel, await all)
        async let locationsTask: () = store.loadLocations()
        async let ordersTask: () = store.loadOrders()
        async let agentsTask: () = store.loadAIAgents()

        _ = await (locationsTask, ordersTask, agentsTask)

        // PHASE 2: Secondary data - fire and forget (don't block UI)
        // NOTE: loadCatalog() calls loadCatalogs() + loadCatalogData() + loadConversations()
        // sequentially, so we must NOT call them separately in parallel (causes double-load cascade)
        Task.detached(priority: .utility) { [store, syncService] in
            async let syncTask: () = syncService.syncAll()
            async let catalogTask: () = store.loadCatalog()
            async let customersTask: () = store.loadCustomers()
            async let creationsTask: () = store.loadCreations()
            async let browserTask: () = store.loadBrowserSessions()
            async let emailsTask: () = store.loadEmailCounts()
            async let campaignsTask: () = store.loadAllCampaigns()

            _ = await (syncTask, catalogTask, customersTask, creationsTask,
                       browserTask, emailsTask, campaignsTask)
        }
    }
}

// MARK: - Detail Destination
// Routes NavigationStack destinations to appropriate detail views

struct DetailDestination: View {
    let item: SDSidebarItem
    var store: EditorStore
    @Binding var selection: SDSidebarItem?

    var body: some View {
        switch item {
        case .orderDetail(let id):
            OrderDetailWrapper(orderId: id, store: store)

        case .locationDetail(let id):
            LocationDetailWrapper(locationId: id, store: store)

        case .queue(let locationId):
            SDLocationQueueView(locationId: locationId)

        case .customerDetail(let id):
            CustomerDetailWrapper(customerId: id, store: store)

        case .catalogDetail(let id):
            CatalogDetailView(catalogId: id, store: store)

        case .catalogSettings(let id):
            CatalogSettingsView(catalogId: id, store: store)

        case .categoryDetail(let id):
            CategoryDetailView(categoryId: id, store: store)

        case .categorySettings(let id):
            if let category = store.categories.first(where: { $0.id == id }) {
                CategoryConfigView(category: category, store: store)
            } else {
                Text("Category not found")
            }

        case .productDetail(let id):
            ProductDetailWrapper(productId: id, store: store)

        case .creationDetail(let id):
            CreationDetailWrapper(creationId: id, store: store)

        case .browserSessionDetail(let id):
            BrowserSessionWrapper(sessionId: id, store: store)

        case .emailDetail(let id):
            EmailDetailWrapper(emailId: id, store: store)

        case .inboxThread(let id):
            ThreadDetailWrapper(threadId: id, store: store)

        case .inboxSettings:
            EmailDomainSettingsView(store: store)

        case .emailCampaignDetail(let id):
            EmailCampaignWrapper(campaignId: id, store: store)

        case .metaCampaignDetail(let id):
            MetaCampaignWrapper(campaignId: id, store: store)

        case .metaIntegrationDetail(let id):
            MetaIntegrationWrapper(integrationId: id, store: store)

        case .agentDetail(let id):
            AgentDetailWrapper(agentId: id, store: store, selection: $selection)

        default:
            // Section-level items handled by MainDetailView
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    AppleContentView()
        .modelContainer(for: [SDOrder.self, SDLocation.self, SDCustomer.self], inMemory: true)
}
