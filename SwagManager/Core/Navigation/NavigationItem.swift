import Foundation
import SwiftData

// MARK: - Unified Navigation Item
// Single enum for all navigation in the app

enum NavigationItem: Hashable {
    // Content
    case teamChat

    // AI
    case agents
    case aiChat
    case email
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
