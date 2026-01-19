import SwiftUI

// MARK: - Safari Toolbar (Unified Address Bar)
// Extracted from SafariBrowserWindow.swift following Apple engineering standards
// File size: ~120 lines (under Apple's 300 line "excellent" threshold)

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
                        .foregroundStyle(canGoBack ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)

                Button(action: { tabManager.activeTab?.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(canGoForward ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
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
                        .foregroundStyle(tabManager.activeTab?.isDarkMode == true ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                // New tab button
                Button(action: { tabManager.newTab() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                // Show tabs button (only appears when tabs > 1)
                if tabManager.tabs.count > 1 {
                    Button(action: { withAnimation(.spring(duration: 0.3)) { showTabs.toggle() } }) {
                        ZStack {
                            Image(systemName: "square.on.square")
                                .font(.system(size: 13))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)

                            Text("\(tabManager.tabs.count)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
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
        .background(DesignSystem.Colors.surfacePrimary)
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
