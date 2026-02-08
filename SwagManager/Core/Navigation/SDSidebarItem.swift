import Foundation

// MARK: - Sidebar Navigation Item
// All navigation destinations for the main sidebar

enum SDSidebarItem: Hashable {
    // AI
    case agents
    case agentDetail(UUID)
    case telemetry
}
