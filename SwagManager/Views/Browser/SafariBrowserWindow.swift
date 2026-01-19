//
//  SafariBrowserWindow.swift
//  SwagManager
//
//  Safari-style unified toolbar with tabs that only appear when needed
//

import SwiftUI
import WebKit

struct SafariBrowserWindow: View {
    let sessionId: UUID
    @State private var showTabs = false
    @ObservedObject var tabManager: BrowserTabManager

    init(sessionId: UUID) {
        self.sessionId = sessionId
        // Get or create a unique tab manager for this session
        self.tabManager = BrowserTabManager.forSession(sessionId)
        NSLog("[SafariBrowserWindow] Initialized for session \(sessionId.uuidString.prefix(8))")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Thin top border for visual separation
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            // Active tab content (controls are now in unified header)
            if let activeTab = tabManager.activeTab {
                BrowserTabView(tab: activeTab)
                    .id(activeTab.id)
            } else {
                EmptyBrowserView(onNewTab: { tabManager.newTab() })
            }
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
        .onAppear {
            // Create initial tab
            if tabManager.tabs.isEmpty {
                tabManager.newTab()
            }
        }
    }
}

// MARK: - Compact Safari Toolbar (Tabs + Address Bar in one row)

struct CompactSafariToolbar: View {
    @ObservedObject var tabManager: BrowserTabManager
    @Binding var showTabs: Bool
    @State private var urlText: String = ""
    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Back/Forward buttons
            HStack(spacing: 0) {
                Button(action: { tabManager.activeTab?.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(canGoBack ? Theme.text : Theme.textTertiary)
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)

                Button(action: { tabManager.activeTab?.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(canGoForward ? Theme.text : Theme.textTertiary)
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)
            }

            // Address bar
            HStack(spacing: 6) {
                Image(systemName: tabManager.activeTab?.isSecure ?? false ? "lock.fill" : "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(tabManager.activeTab?.isSecure ?? false ? Theme.green : Theme.textTertiary)

                TextField("Search or enter website name", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text)
                    .focused($isURLFieldFocused)
                    .onSubmit(navigateToURL)

                if tabManager.activeTab?.isLoading ?? false {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 18, height: 18)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.bgTertiary)
            .cornerRadius(6)
            .padding(.horizontal, 8)

            // Right controls
            HStack(spacing: 0) {
                Button(action: { tabManager.activeTab?.toggleDarkMode() }) {
                    Image(systemName: tabManager.activeTab?.isDarkMode == true ? "moon.fill" : "moon")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(tabManager.activeTab?.isDarkMode == true ? Theme.accent : Theme.textSecondary)
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)

                Button(action: { tabManager.newTab() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 36)
        .background(VisualEffectBackground(material: .titlebar))
        .onChange(of: tabManager.activeTab?.currentURL) { _, newURL in
            if !isURLFieldFocused {
                urlText = newURL ?? ""
            }
        }
        .onAppear {
            urlText = tabManager.activeTab?.currentURL ?? ""
        }
    }

    private var canGoBack: Bool {
        tabManager.activeTab?.canGoBack ?? false
    }

    private var canGoForward: Bool {
        tabManager.activeTab?.canGoForward ?? false
    }

    private func calculateTabWidth(totalWidth: CGFloat) -> CGFloat {
        let controlsWidth: CGFloat = 64 + 96 // back/forward + right controls
        let availableWidth = totalWidth - controlsWidth
        let tabCount = CGFloat(max(1, tabManager.tabs.count))
        let maxTabWidth: CGFloat = 240
        let calculatedWidth = availableWidth / tabCount
        return min(calculatedWidth, maxTabWidth)
    }

    private func navigateToURL() {
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

// MARK: - Square Tab Item

struct SquareTabItem: View {
    @ObservedObject var tab: BrowserTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Loading indicator or favicon
                if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: tab.isSecure ? "lock.fill" : "globe")
                        .font(.system(size: 9))
                        .foregroundStyle(tab.isSecure ? Theme.green : Theme.textTertiary)
                        .frame(width: 14, height: 14)
                }

                // Title with URL fallback
                Text(tab.pageTitle ?? tab.currentURL ?? "New Tab")
                    .font(.system(size: 11))
                    .foregroundStyle(isActive ? Theme.text : Theme.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .opacity(isActive ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(isActive ? Theme.bgTertiary : Theme.bgSecondary)
            .overlay(
                Rectangle()
                    .frame(width: 1)
                    .foregroundStyle(Theme.border)
                , alignment: .trailing
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Safari Toolbar (Unified Address Bar)

struct SafariToolbar: View {
    @ObservedObject var tabManager: BrowserTabManager
    @Binding var showTabs: Bool
    @State private var urlText: String = ""
    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Back/Forward buttons
            HStack(spacing: 4) {
                Button(action: { tabManager.activeTab?.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(canGoBack ? Theme.text : Theme.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)

                Button(action: { tabManager.activeTab?.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(canGoForward ? Theme.text : Theme.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)
            }

            // Unified address bar (Safari-style)
            SafariAddressBar(
                urlText: $urlText,
                pageTitle: tabManager.activeTab?.pageTitle,
                isSecure: tabManager.activeTab?.isSecure ?? false,
                isLoading: tabManager.activeTab?.isLoading ?? false,
                isURLFieldFocused: $isURLFieldFocused,
                onSubmit: { navigateToURL() },
                onRefresh: { tabManager.activeTab?.refresh() },
                onStop: { tabManager.activeTab?.stop() }
            )

            // Right side controls
            HStack(spacing: 8) {
                // Dark mode toggle
                Button(action: { tabManager.activeTab?.toggleDarkMode() }) {
                    Image(systemName: tabManager.activeTab?.isDarkMode == true ? "moon.fill" : "moon")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(tabManager.activeTab?.isDarkMode == true ? Theme.accent : Theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                // New tab button
                Button(action: { tabManager.newTab() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                // Show tabs button (only appears when tabs > 1)
                if tabManager.tabs.count > 1 {
                    Button(action: { withAnimation(.spring(duration: 0.3)) { showTabs.toggle() } }) {
                        ZStack {
                            Image(systemName: "square.on.square")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)

                            Text("\(tabManager.tabs.count)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.text)
                                .offset(y: 8)
                        }
                        .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.bg)
        .onChange(of: tabManager.activeTab?.currentURL) { _, newURL in
            if !isURLFieldFocused {
                urlText = newURL ?? ""
            }
        }
        .onAppear {
            urlText = tabManager.activeTab?.currentURL ?? ""
        }
    }

    private var canGoBack: Bool {
        tabManager.activeTab?.canGoBack ?? false
    }

    private var canGoForward: Bool {
        tabManager.activeTab?.canGoForward ?? false
    }

    private func navigateToURL() {
        guard !urlText.isEmpty else { return }

        var urlString = urlText.trimmingCharacters(in: .whitespaces)

        // Add https:// if no scheme
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

// MARK: - Safari Address Bar

struct SafariAddressBar: View {
    @Binding var urlText: String
    let pageTitle: String?
    let isSecure: Bool
    let isLoading: Bool
    @FocusState.Binding var isURLFieldFocused: Bool
    let onSubmit: () -> Void
    let onRefresh: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Security icon
            Image(systemName: isSecure ? "lock.fill" : "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(isSecure ? Theme.green : Theme.textTertiary)

            // URL / Title field
            TextField("Search or enter website name", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .focused($isURLFieldFocused)
                .onSubmit(onSubmit)

            // Loading or refresh button
            Button(action: isLoading ? onStop : onRefresh) {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .opacity(isLoading || isURLFieldFocused ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.bgElevated.opacity(0.8))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isURLFieldFocused ? Theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Safari Tab Bar

struct SafariTabBar: View {
    @ObservedObject var tabManager: BrowserTabManager
    @Binding var showTabs: Bool

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(tabManager.tabs) { tab in
                    SafariTabItem(
                        tab: tab,
                        isActive: tab.id == tabManager.activeTab?.id,
                        onSelect: { tabManager.selectTab(tab) },
                        onClose: { tabManager.closeTab(tab) }
                    )
                    .frame(width: geometry.size.width / CGFloat(max(1, tabManager.tabs.count)))
                }
            }
        }
        .frame(height: 36)
        .background(Theme.bg)
    }
}

// MARK: - Safari Tab Item

struct SafariTabItem: View {
    let tab: BrowserTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Favicon or loading indicator
                if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                }

                // Title
                Text(tab.pageTitle ?? "New Tab")
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? Theme.text : Theme.textSecondary)
                    .lineLimit(1)

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .opacity(isActive ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Theme.bgElevated.opacity(0.5) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty Browser View

struct EmptyBrowserView: View {
    let onNewTab: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "safari")
                .font(.system(size: 64))
                .foregroundStyle(Theme.textTertiary)

            Text("No tabs open")
                .font(.title2)
                .foregroundStyle(Theme.textSecondary)

            Button(action: onNewTab) {
                Text("New Tab")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

#Preview {
    SafariBrowserWindow(sessionId: UUID())
        .frame(width: 1200, height: 800)
}
