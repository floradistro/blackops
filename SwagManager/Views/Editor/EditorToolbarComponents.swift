import SwiftUI

// MARK: - Editor Toolbar Components
// Extracted from EditorView.swift following Apple engineering standards
// File size: ~194 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Unified Toolbar Content (Baked into Window Titlebar)

struct UnifiedToolbarContent: CustomizableToolbarContent {
    @ObservedObject var store: EditorStore
    @State private var urlText: String = ""
    @FocusState private var isURLFieldFocused: Bool

    private var isBrowserActive: Bool {
        if case .browserSession = store.activeTab {
            return true
        }
        return store.selectedBrowserSession != nil
    }

    private var tabManager: BrowserTabManager? {
        if case .browserSession(let session) = store.activeTab {
            return BrowserTabManager.forSession(session.id)
        } else if let session = store.selectedBrowserSession {
            return BrowserTabManager.forSession(session.id)
        }
        return nil
    }

    var body: some CustomizableToolbarContent {
        if let activeTab = store.activeTab {
            switch activeTab {
            case .browserSession(let session):
                let tabManager = BrowserTabManager.forSession(session.id)
                // Back
                ToolbarItem(id: "back") {
                    Button(action: { tabManager.activeTab?.goBack() }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!(tabManager.activeTab?.canGoBack ?? false))
                }

                // Forward
                ToolbarItem(id: "forward") {
                    Button(action: { tabManager.activeTab?.goForward() }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!(tabManager.activeTab?.canGoForward ?? false))
                }

                // Address bar (centered)
                ToolbarItem(id: "address", placement: .principal) {
                    BrowserAddressField(
                        urlText: $urlText,
                        isSecure: tabManager.activeTab?.isSecure ?? false,
                        isLoading: tabManager.activeTab?.isLoading ?? false,
                        isURLFieldFocused: $isURLFieldFocused,
                        onSubmit: { navigateToURL(tabManager: tabManager) }
                    )
                    .frame(maxWidth: 600)
                    .onChange(of: tabManager.activeTab?.currentURL) { _, newURL in
                        if !isURLFieldFocused {
                            urlText = newURL ?? ""
                        }
                    }
                    .onAppear {
                        urlText = tabManager.activeTab?.currentURL ?? ""
                    }
                }

                // Dark mode
                ToolbarItem(id: "darkMode") {
                    Button(action: { tabManager.activeTab?.toggleDarkMode() }) {
                        Image(systemName: tabManager.activeTab?.isDarkMode == true ? "moon.fill" : "moon")
                    }
                }

                // New tab
                ToolbarItem(id: "newTab") {
                    Button(action: { tabManager.newTab() }) {
                        Image(systemName: "plus")
                    }
                }

            case .product(let product):
                ToolbarItem(id: "context", placement: .principal) {
                    Label(product.name, systemImage: "leaf")
                        .font(.system(size: 13, weight: .medium))
                }

            case .conversation(let conversation):
                ToolbarItem(id: "context", placement: .principal) {
                    Label(conversation.displayTitle, systemImage: conversation.chatTypeIcon)
                        .font(.system(size: 13, weight: .medium))
                }

            case .category(let category):
                ToolbarItem(id: "context", placement: .principal) {
                    Label(category.name, systemImage: "folder")
                        .font(.system(size: 13, weight: .medium))
                }

            case .creation(let creation):
                ToolbarItem(id: "context", placement: .principal) {
                    Label(creation.name, systemImage: creation.creationType.icon)
                        .font(.system(size: 13, weight: .medium))
                }

            case .order(let order):
                ToolbarItem(id: "context", placement: .principal) {
                    Label(order.displayTitle, systemImage: order.orderTypeIcon)
                        .font(.system(size: 13, weight: .medium))
                }

            case .location(let location):
                ToolbarItem(id: "context", placement: .principal) {
                    Label(location.name, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 13, weight: .medium))
                }

            case .queue(let location):
                ToolbarItem(id: "context", placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.blue)
                        Text("\(location.name) Queue")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }

            case .customer(let customer):
                ToolbarItem(id: "context", placement: .principal) {
                    Label(customer.displayName, systemImage: customer.statusIcon)
                        .font(.system(size: 13, weight: .medium))
                }

            case .mcpServer(let server):
                ToolbarItem(id: "context", placement: .principal) {
                    Label(server.name, systemImage: "server.rack")
                        .font(.system(size: 13, weight: .medium))
                }
            }
        } else if let browserSession = store.selectedBrowserSession {
            let tabManager = BrowserTabManager.forSession(browserSession.id)
            // Browser controls for selected session
            ToolbarItem(id: "back") {
                Button(action: { tabManager.activeTab?.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!(tabManager.activeTab?.canGoBack ?? false))
            }

            ToolbarItem(id: "forward") {
                Button(action: { tabManager.activeTab?.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!(tabManager.activeTab?.canGoForward ?? false))
            }

            ToolbarItem(id: "address", placement: .principal) {
                BrowserAddressField(
                    urlText: $urlText,
                    isSecure: tabManager.activeTab?.isSecure ?? false,
                    isLoading: tabManager.activeTab?.isLoading ?? false,
                    isURLFieldFocused: $isURLFieldFocused,
                    onSubmit: { navigateToURL(tabManager: tabManager) }
                )
                .frame(maxWidth: 600)
                .onChange(of: tabManager.activeTab?.currentURL) { _, newURL in
                    if !isURLFieldFocused {
                        urlText = newURL ?? ""
                    }
                }
                .onAppear {
                    urlText = tabManager.activeTab?.currentURL ?? ""
                }
            }

            ToolbarItem(id: "darkMode") {
                Button(action: { tabManager.activeTab?.toggleDarkMode() }) {
                    Image(systemName: tabManager.activeTab?.isDarkMode == true ? "moon.fill" : "moon")
                }
            }

            ToolbarItem(id: "newTab") {
                Button(action: { tabManager.newTab() }) {
                    Image(systemName: "plus")
                }
            }
        } else {
            // Empty state - no toolbar items
            ToolbarItem(id: "empty", placement: .principal) {
                Text("")
            }
        }
    }

    private var contextTitle: String {
        if let activeTab = store.activeTab {
            switch activeTab {
            case .creation: return "Creation"
            case .product: return "Product"
            case .conversation: return "Team Chat"
            case .category: return "Category"
            case .browserSession: return "Browser"
            case .order: return "Order"
            case .location: return "Location"
            case .queue: return "Queue"
            case .customer: return "Customer"
            case .mcpServer: return "MCP Server"
            }
        } else if store.selectedBrowserSession != nil {
            return "Browser"
        } else if store.selectedConversation != nil {
            return "Team Chat"
        } else if store.selectedProduct != nil {
            return "Product"
        } else if store.selectedCreation != nil {
            return "Creation"
        } else if store.selectedCategory != nil {
            return "Category"
        }
        return ""
    }

    private func navigateToURL(tabManager: BrowserTabManager) {
        guard !urlText.isEmpty else { return }
        var urlString = urlText.trimmingCharacters(in: .whitespaces)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if urlString.contains(".") {
                urlString = "https://" + urlString
            } else {
                urlString = "https://www.google.com/search?q=" + urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            }
        }
        tabManager.activeTab?.navigate(to: urlString)
        isURLFieldFocused = false
    }
}
