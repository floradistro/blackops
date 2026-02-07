import Foundation

// MARK: - Sidebar Navigation Item
// All navigation destinations for the main sidebar

enum SDSidebarItem: Hashable {
    // Content
    case teamChat

    // Operations
    case locations
    case locationDetail(UUID)
    case queue(UUID)
    case emails
    case emailDetail(UUID)
    case inbox
    case inboxThread(UUID)
    case inboxSettings

    // CRM
    case emailCampaigns
    case emailCampaignDetail(UUID)
    case metaCampaigns
    case metaCampaignDetail(UUID)
    case metaIntegrations
    case metaIntegrationDetail(UUID)

    // AI
    case aiChat
    case agents
    case agentDetail(UUID)
    case telemetry  // Global tool execution traces
}
