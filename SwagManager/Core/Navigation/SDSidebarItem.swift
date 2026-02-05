import Foundation

// MARK: - Sidebar Navigation Item
// All navigation destinations for the main sidebar

enum SDSidebarItem: Hashable {
    // Workspace
    case orders
    case orderDetail(UUID)
    case locations
    case locationDetail(UUID)
    case queue(UUID)
    case customers
    case customerDetail(UUID)

    // Content
    case catalogs
    case catalogDetail(UUID)
    case catalogSettings(UUID)
    case categoryDetail(UUID)
    case categorySettings(UUID)
    case catalog  // Legacy - products view
    case productDetail(UUID)
    case creations
    case creationDetail(UUID)
    case teamChat

    // Operations
    case browserSessions
    case browserSessionDetail(UUID)
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
