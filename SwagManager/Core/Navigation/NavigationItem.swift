import Foundation

// MARK: - Unified Navigation Item

enum NavigationItem: Hashable {
    case agents
}

// MARK: - Navigation Path

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
