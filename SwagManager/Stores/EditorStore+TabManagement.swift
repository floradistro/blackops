import SwiftUI

// MARK: - EditorStore Tab Management Extension
// Extracted from EditorView.swift following Apple engineering standards
// Contains: Safari/Xcode-style tab management and routing logic
// File size: ~165 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Tab Management

    func openTab(_ item: OpenTabItem) {
        if !openTabs.contains(where: { $0.id == item.id }) {
            openTabs.append(item)
        }
        activeTab = item
    }

    func closeTab(_ item: OpenTabItem) {
        openTabs.removeAll { $0.id == item.id }
        if activeTab?.id == item.id {
            activeTab = openTabs.last
            // Update selection based on active tab
            if let tab = activeTab {
                switch tab {
                case .creation(let c):
                    selectedCreation = c
                    editedCode = c.reactCode
                    selectedProduct = nil
                    selectedConversation = nil
                case .product(let p):
                    selectedProduct = p
                    selectedCreation = nil
                    selectedConversation = nil
                    editedCode = nil
                case .conversation(let c):
                    selectedConversation = c
                    selectedCreation = nil
                    selectedProduct = nil
                    selectedCategory = nil
                    editedCode = nil
                case .category(let c):
                    selectedCategory = c
                    selectedCreation = nil
                    selectedProduct = nil
                    selectedConversation = nil
                    editedCode = nil
                case .browserSession(let s):
                    selectedBrowserSession = s
                    selectedCreation = nil
                    selectedProduct = nil
                    selectedConversation = nil
                    selectedCategory = nil
                    editedCode = nil
                }
            } else {
                selectedCreation = nil
                selectedProduct = nil
                selectedConversation = nil
                selectedCategory = nil
                selectedBrowserSession = nil
                editedCode = nil
            }
        }
    }

    func switchToTab(_ item: OpenTabItem) {
        activeTab = item
        switch item {
        case .creation(let c):
            selectedCreation = c
            editedCode = c.reactCode
            selectedProduct = nil
            selectedConversation = nil
            selectedCategory = nil
            selectedBrowserSession = nil
        case .product(let p):
            selectedProduct = p
            selectedCreation = nil
            selectedConversation = nil
            selectedCategory = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .conversation(let c):
            selectedConversation = c
            selectedCreation = nil
            selectedProduct = nil
            selectedCategory = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .category(let c):
            selectedCategory = c
            selectedCreation = nil
            selectedProduct = nil
            selectedConversation = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .browserSession(let s):
            selectedBrowserSession = s
            selectedCreation = nil
            selectedProduct = nil
            selectedConversation = nil
            selectedCategory = nil
            editedCode = nil
        }
    }

    func closeOtherTabs(except tab: OpenTabItem) {
        openTabs = openTabs.filter { $0.id == tab.id }
        activeTab = tab
        switch tab {
        case .creation(let c):
            selectedCreation = c
            editedCode = c.reactCode
            selectedProduct = nil
            selectedConversation = nil
            selectedCategory = nil
            selectedBrowserSession = nil
        case .product(let p):
            selectedProduct = p
            selectedCreation = nil
            selectedConversation = nil
            selectedCategory = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .conversation(let c):
            selectedConversation = c
            selectedCreation = nil
            selectedProduct = nil
            selectedCategory = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .category(let c):
            selectedCategory = c
            selectedCreation = nil
            selectedProduct = nil
            selectedConversation = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .browserSession(let s):
            selectedBrowserSession = s
            selectedCreation = nil
            selectedProduct = nil
            selectedConversation = nil
            selectedCategory = nil
            editedCode = nil
        }
    }

    func closeAllTabs() {
        openTabs.removeAll()
        activeTab = nil
        selectedCreation = nil
        selectedProduct = nil
        selectedConversation = nil
        selectedCategory = nil
        selectedBrowserSession = nil
        editedCode = nil
    }

    func closeTabsToRight(of tab: OpenTabItem) {
        guard let index = openTabs.firstIndex(where: { $0.id == tab.id }) else { return }
        openTabs = Array(openTabs.prefix(through: index))
        // If active tab was closed, switch to the reference tab
        if let active = activeTab, !openTabs.contains(where: { $0.id == active.id }) {
            switchToTab(tab)
        }
    }

}
