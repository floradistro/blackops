import SwiftUI
import SwiftData

// MARK: - Main Detail View
// Routes top-level sidebar selections to section content views
// Uses @Environment for store access - Apple WWDC23 pattern

struct MainDetailView: View {
    @Binding var selection: SDSidebarItem?
    @Environment(\.editorStore) private var store

    var body: some View {
        Group {
            switch selection {
            // CONTENT - Section views
            case .teamChat:
                TeamChatView(storeId: store.selectedStore?.id)

            // OPERATIONS - Section views
            case .locations:
                LocationsListView(selection: $selection, storeId: store.currentStoreId)

            case .locationDetail(let id):
                LocationDetailWrapper(locationId: id)

            case .queue(let locationId):
                LocationQueueView(locationId: locationId)

            case .emails:
                EmailsListView(selection: $selection, storeId: store.currentStoreId)

            case .inbox:
                InboxListView(selection: $selection)

            case .inboxThread(let id):
                ThreadDetailWrapper(threadId: id)

            case .inboxSettings:
                EmailDomainSettingsView()

            // CRM - Section views
            case .emailCampaigns:
                CRMEmailCampaignsView(selection: $selection, storeId: store.currentStoreId)

            case .metaCampaigns:
                CRMMetaCampaignsView(selection: $selection, storeId: store.currentStoreId)

            case .metaIntegrations:
                CRMMetaIntegrationsView(selection: $selection, storeId: store.currentStoreId)

            // AI - Section views
            case .aiChat:
                WelcomeView()

            case .agents:
                AgentsListView(selection: $selection, storeId: store.currentStoreId)

            case .telemetry:
                TelemetryPanel(storeId: store.selectedStore?.id)

            // Detail items
            case .emailDetail(let id):
                EmailDetailWrapper(emailId: id)

            case .emailCampaignDetail(let id):
                EmailCampaignWrapper(campaignId: id)

            case .metaCampaignDetail(let id):
                MetaCampaignWrapper(campaignId: id)

            case .metaIntegrationDetail(let id):
                MetaIntegrationWrapper(integrationId: id)

            case .agentDetail(let id):
                AgentDetailWrapper(agentId: id, selection: $selection)

            case .none:
                WelcomeView()
            }
        }
        .freezeDebugLifecycle("MainDetailView")
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    var body: some View {
        ContentUnavailableView {
            Label("WhaleTools", systemImage: "hammer.fill")
        } description: {
            Text("Select an item from the sidebar")
        }
        .navigationTitle("Home")
    }
}
