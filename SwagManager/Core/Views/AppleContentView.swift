import SwiftUI
import SwiftData

// MARK: - Apple-Style Content View
// Settings-style navigation: flat sidebar + drill-down detail with back navigation
// Sidebar shows top-level sections, detail view uses NavigationStack for breadcrumb nav

struct AppleContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editorStore) private var store
    @State private var syncService = SyncService.shared

    @State private var selectedItem: SDSidebarItem? = nil
    @State private var navigationPath = NavigationPath()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showAIChat = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            MainSidebar(selection: $selectedItem, syncService: syncService)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        } detail: {
            NavigationStack(path: $navigationPath) {
                MainDetailView(selection: $selectedItem)
                    .navigationDestination(for: SDSidebarItem.self) { item in
                        DetailDestination(item: item, selection: $selectedItem)
                    }
            }
        }
        // Store is injected by ContentView at root level
        // CRITICAL: Use StableInspectorContent to prevent view churn when toggling
        // The inspector column still animates in/out, but the AIChatPane stays mounted
        // once first shown, preventing NSHostingView layout recursion
        .inspector(isPresented: $showAIChat) {
            StableInspectorContent(isVisible: showAIChat)
                .inspectorColumnWidth(min: 320, ideal: 420, max: 600)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                StoreDropdown()
            }

            ToolbarItem(placement: .primaryAction) {
                if syncService.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                RefreshButton(syncService: syncService)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAIChat.toggle()
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
            store.startSubscriptions()  // Start realtime after store is ready
            if let storeId = store.selectedStore?.id {
                syncService.configure(modelContext: modelContext, storeId: storeId)
                await loadAllData(store: store, syncService: syncService)
            }
        }
        .onChange(of: store.selectedStore?.id) { _, newId in
            if let storeId = newId {
                syncService.configure(modelContext: modelContext, storeId: storeId)
                Task { await loadAllData(store: store, syncService: syncService) }
            }
        }
        .freezeDebugLifecycle("AppleContentView")
    }
}

// MARK: - Refresh Button (Isolated observation)
private struct RefreshButton: View {
    let syncService: SyncService
    @Environment(\.editorStore) private var store

    var body: some View {
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
}

// MARK: - Load All Data
/// Load all data for the current store - PHASED for performance
/// Phase 1: Critical data for sidebar (fast, blocks UI)
/// Phase 2: Secondary data (background, non-blocking)
@MainActor
private func loadAllData(store: EditorStore, syncService: SyncService) async {
    // PHASE 1: Critical data needed for initial UI render
    async let agentsTask: () = store.loadAIAgents()
    async let locationsTask: () = store.loadLocations()
    _ = await (agentsTask, locationsTask)

    // PHASE 2: Secondary data - fire and forget (don't block UI)
    Task.detached(priority: .utility) { @Sendable [store, syncService] in
        async let syncTask: () = syncService.syncAll()
        async let emailsTask: () = store.loadEmailCounts()
        async let campaignsTask: () = store.loadAllCampaigns()

        _ = await (syncTask, emailsTask, campaignsTask)
    }
}

// MARK: - Detail Destination
// Routes NavigationStack destinations to appropriate detail views
// Uses @Environment for store access - Apple WWDC23 pattern

struct DetailDestination: View {
    let item: SDSidebarItem
    @Binding var selection: SDSidebarItem?
    @Environment(\.editorStore) private var store

    var body: some View {
        switch item {
        case .locationDetail(let id):
            LocationDetailWrapper(locationId: id)

        case .queue(let locationId):
            LocationQueueView(locationId: locationId)

        case .emailDetail(let id):
            EmailDetailWrapper(emailId: id)

        case .inboxThread(let id):
            ThreadDetailWrapper(threadId: id)

        case .inboxSettings:
            EmailDomainSettingsView()

        case .emailCampaignDetail(let id):
            EmailCampaignWrapper(campaignId: id)

        case .metaCampaignDetail(let id):
            MetaCampaignWrapper(campaignId: id)

        case .metaIntegrationDetail(let id):
            MetaIntegrationWrapper(integrationId: id)

        case .agentDetail(let id):
            AgentDetailWrapper(agentId: id, selection: $selection)

        default:
            EmptyView()
        }
    }
}

// MARK: - Stable Inspector Content
// Since animations are disabled on the toggle, we can mount AIChatPane directly
// The wrapper still defers @ObservedObject subscriptions via AIChatPaneContent

private struct StableInspectorContent: View {
    let isVisible: Bool

    var body: some View {
        // AIChatPane is a lightweight wrapper that defers creating
        // AIChatPaneContent (with @ObservedObject) until after a delay
        AIChatPane()
    }
}

// MARK: - Preview

#Preview {
    AppleContentView()
        .modelContainer(for: [], inMemory: true)
}
