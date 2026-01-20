import SwiftUI

// MARK: - EditorStore Queue Management Extension
// Following Apple engineering standards
// Handles queue operations and tab management

extension EditorStore {
    // MARK: - Queue Operations

    /// Open queue for a location in a new tab
    func openQueue(_ location: Location) {
        selectedQueue = location
        let tabItem = OpenTabItem.queue(location)

        // Add to tabs if not already open
        if !openTabs.contains(tabItem) {
            openTabs.append(tabItem)
        }

        // Set as active tab
        activeTab = tabItem
    }

    /// Close queue tab for a location
    func closeQueue(_ location: Location) {
        let tabItem = OpenTabItem.queue(location)
        if let index = openTabs.firstIndex(of: tabItem) {
            openTabs.remove(at: index)

            // If this was the active tab, switch to another
            if activeTab == tabItem {
                if index < openTabs.count {
                    activeTab = openTabs[index]
                } else if !openTabs.isEmpty {
                    activeTab = openTabs.last
                } else {
                    activeTab = nil
                }
            }
        }

        // Clear selection if this was the selected queue
        if selectedQueue?.id == location.id {
            selectedQueue = nil
        }
    }
}
