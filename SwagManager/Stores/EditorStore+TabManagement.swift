import SwiftUI

// MARK: - EditorStore Tab Management Extension
// Refactored to eliminate repetitive switch statements
// Uses protocol-based state activation pattern

extension EditorStore {
    // MARK: - Tab Management

    func openTab(_ item: OpenTabItem) {
        if !openTabs.contains(where: { $0.id == item.id }) {
            openTabs.append(item)
        }
        switchToTab(item)
    }

    func closeTab(_ item: OpenTabItem) {
        openTabs.removeAll { $0.id == item.id }

        if activeTab?.id == item.id {
            activeTab = openTabs.last
            if let tab = activeTab {
                switchToTab(tab)
            } else {
                clearAllSelections()
            }
        }
    }

    func switchToTab(_ item: OpenTabItem) {
        clearAllSelections()
        activeTab = item
        item.activateState(in: self)
    }

    func closeOtherTabs(except tab: OpenTabItem) {
        openTabs = openTabs.filter { $0.id == tab.id }
        switchToTab(tab)
    }

    func closeTabsToRight(of tab: OpenTabItem) {
        guard let index = openTabs.firstIndex(where: { $0.id == tab.id }) else { return }
        openTabs = Array(openTabs.prefix(through: index))

        if let active = activeTab, !openTabs.contains(where: { $0.id == active.id }) {
            switchToTab(tab)
        }
    }

    func closeAllTabs() {
        openTabs.removeAll()
        activeTab = nil
        clearAllSelections()
    }

    // MARK: - Clear All Selections

    private func clearAllSelections() {
        selectedCreation = nil
        selectedProduct = nil
        selectedConversation = nil
        selectedCategory = nil
        selectedBrowserSession = nil
        selectedOrder = nil
        selectedLocation = nil
        selectedQueue = nil
        selectedCustomer = nil
        selectedEmail = nil
        editedCode = nil
    }
}

// MARK: - Tab State Activation

extension OpenTabItem {
    @MainActor
    func activateState(in store: EditorStore) {
        switch self {
        case .creation(let c):
            store.selectedCreation = c
            store.editedCode = c.reactCode

        case .product(let p):
            store.selectedProduct = p

        case .conversation(let c):
            store.selectedConversation = c

        case .category(let c):
            store.selectedCategory = c

        case .browserSession(let s):
            store.selectedBrowserSession = s

        case .order(let o):
            store.selectedOrder = o

        case .location(let l):
            store.selectedLocation = l

        case .queue(let l):
            store.selectedQueue = l

        case .customer(let c):
            store.selectedCustomer = c

        case .email(let e):
            store.selectedEmail = e

        case .thread(let t):
            store.selectedThread = t

        case .cart, .emailCampaign, .metaCampaign, .metaIntegration, .aiChat:
            // These tabs don't have dedicated state
            break

        case .aiAgent(let agent):
            store.selectedAIAgent = agent
        }
    }
}
