import SwiftUI
import WebKit

// MARK: - Browser Controls
// Extracted from BrowserSessionView.swift following Apple engineering standards
// Contains: Browser navigation and control bar
// File size: ~178 lines (under Apple's 300 line "excellent" threshold)

struct BrowserControls: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let isLoading: Bool
    let currentURL: String?
    let pageTitle: String?
    let webView: WKWebView?
    @Binding var isDarkMode: Bool

    let onBack: () -> Void
    let onForward: () -> Void
    let onRefresh: () -> Void
    let onStop: () -> Void
    let onNewTab: () -> Void
    let onToggleDarkMode: () -> Void

    @State private var urlText: String = ""
    @FocusState private var isURLFieldFocused: Bool

    private func navigateToURL() {
        guard let webView = webView, !urlText.isEmpty else { return }

        var urlString = urlText.trimmingCharacters(in: .whitespaces)

        // Add https:// if no scheme is present
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            // Check if it looks like a URL (contains a dot)
            if urlString.contains(".") {
                urlString = "https://" + urlString
            } else {
                // Otherwise, treat as a search query
                urlString = "https://www.google.com/search?q=" + urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            }
        }

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }

    var body: some View {
        let backButton = Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(canGoBack ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(!canGoBack)
        .help("Back")

        let forwardButton = Button(action: onForward) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(canGoForward ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(!canGoForward)
        .help("Forward")

        let refreshButton = Button(action: isLoading ? onStop : onRefresh) {
            Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(isLoading ? "Stop" : "Refresh")

        let urlBar = HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundStyle(DesignSystem.Colors.green.opacity(0.8))

            TextField("Enter URL or search...", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .focused($isURLFieldFocused)
                .onSubmit {
                    navigateToURL()
                    isURLFieldFocused = false
                }

            if !urlText.isEmpty {
                Button(action: { urlText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(DesignSystem.Colors.surfaceElevated)
        .cornerRadius(8)

        let darkModeButton = Button(action: onToggleDarkMode) {
            Image(systemName: isDarkMode ? "moon.fill" : "moon")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isDarkMode ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(isDarkMode ? "Disable Dark Mode" : "Enable Dark Mode")

        let newTabButton = Button(action: onNewTab) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help("New tab")

        return HStack(spacing: 8) {
            HStack(spacing: 4) {
                backButton
                forwardButton
                refreshButton
            }
            .padding(.leading, 8)

            urlBar

            darkModeButton
            newTabButton
                .padding(.trailing, 8)
        }
        .frame(height: 44)
        .background(DesignSystem.Colors.surfaceSecondary)
        .onAppear {
            urlText = currentURL ?? ""
        }
        .onChange(of: currentURL) { _, newURL in
            if !isURLFieldFocused {
                urlText = newURL ?? ""
            }
        }
    }
}

#Preview {
    BrowserSessionView(
        session: BrowserSession(
            id: UUID(),
            creationId: nil,
            storeId: UUID(),
            name: "Test Session",
            currentUrl: "https://example.com",
            viewportWidth: 1280,
            viewportHeight: 800,
            userAgent: nil,
            cookies: nil,
            localStorage: nil,
            sessionStorage: nil,
            screenshotUrl: nil,
            screenshotAt: Date(),
            interactiveElements: nil,
            pageTitle: "Example Domain",
            browserWsEndpoint: nil,
            browserService: "browserless",
            status: "active",
            errorMessage: nil,
            lastActivity: Date(),
            createdAt: Date(),
            updatedAt: Date()
        ),
        store: EditorStore()
    )
    .frame(width: 800, height: 600)
}
