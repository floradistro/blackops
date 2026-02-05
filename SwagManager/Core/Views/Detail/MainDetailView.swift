import SwiftUI
import SwiftData

// MARK: - Main Detail View
// Routes top-level sidebar selections to section content views
// Detail items are pushed via NavigationStack (handled by DetailDestination)

struct MainDetailView: View {
    @Binding var selection: SDSidebarItem?
    var store: EditorStore

    var body: some View {
        Group {
            switch selection {
            // WORKSPACE - Section views
            case .orders:
                AllOrdersListView()

            case .locations:
                AllLocationsListView()

            case .customers:
                CustomersListView(store: store)

            // CONTENT - Section views
            case .catalogs:
                CatalogsListView(store: store, selection: $selection)

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

            case .catalog:
                CatalogContentView(store: store, selection: $selection)

            case .creations:
                CreationsContentView(store: store, selection: $selection)

            case .teamChat:
                TeamChatPlaceholderView()

            // OPERATIONS - Section views
            case .browserSessions:
                BrowserSessionsListView(store: store, selection: $selection)

            case .emails:
                EmailsListView(store: store, selection: $selection)

            // CRM - Section views
            case .emailCampaigns:
                CRMEmailCampaignsView(store: store, selection: $selection)

            case .metaCampaigns:
                CRMMetaCampaignsView(store: store, selection: $selection)

            case .metaIntegrations:
                CRMMetaIntegrationsView(store: store, selection: $selection)

            // AI - Section views
            case .aiChat:
                WelcomeView(store: store)

            case .agents:
                AgentsListView(store: store, selection: $selection)

            case .telemetry:
                TelemetryPanel(storeId: store.selectedStore?.id)

            // Detail items - These are pushed via NavigationStack, but we handle them
            // here as fallback for direct sidebar selection (from old saved state)
            case .orderDetail(let id):
                OrderDetailWrapper(orderId: id, store: store)

            case .locationDetail(let id):
                LocationDetailWrapper(locationId: id, store: store)

            case .queue(let locationId):
                SDLocationQueueView(locationId: locationId)

            case .customerDetail(let id):
                CustomerDetailWrapper(customerId: id, store: store)

            case .productDetail(let id):
                ProductDetailWrapper(productId: id, store: store)

            case .creationDetail(let id):
                CreationDetailWrapper(creationId: id, store: store)

            case .browserSessionDetail(let id):
                BrowserSessionWrapper(sessionId: id, store: store)

            case .emailDetail(let id):
                EmailDetailWrapper(emailId: id, store: store)

            case .emailCampaignDetail(let id):
                EmailCampaignWrapper(campaignId: id, store: store)

            case .metaCampaignDetail(let id):
                MetaCampaignWrapper(campaignId: id, store: store)

            case .metaIntegrationDetail(let id):
                MetaIntegrationWrapper(integrationId: id, store: store)

            case .agentDetail(let id):
                AgentDetailWrapper(agentId: id, store: store, selection: $selection)

            case .none:
                WelcomeView(store: store)
            }
        }
    }
}

// MARK: - Welcome View
// Minimal native macOS empty state

struct WelcomeView: View {
    var store: EditorStore

    var body: some View {
        ContentUnavailableView {
            Label("WhaleTools", systemImage: "hammer.fill")
        } description: {
            Text("Select an item from the sidebar")
        }
        .navigationTitle("Home")
    }
}
