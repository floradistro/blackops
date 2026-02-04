import Foundation
import SwiftData

// MARK: - Unified Navigation Item
// Single enum for all navigation in the app

enum NavigationItem: Hashable {
    // Workspace
    case orders
    case order(SDOrder)
    case location(SDLocation)
    case queue(SDLocation)

    // Content
    case catalog
    case products
    case creations
    case teamChat

    // Operations
    case browserSessions

    // AI
    case agents
    case aiChat
    case email

    // Detail views
    case customer(SDCustomer)
}

// MARK: - Navigation Path (for programmatic navigation)

@MainActor
@Observable
class NavigationState {
    var selection: NavigationItem?
    var path: [NavigationItem] = []

    func navigate(to item: NavigationItem) {
        selection = item
    }

    func push(_ item: NavigationItem) {
        path.append(item)
    }

    func pop() {
        _ = path.popLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
