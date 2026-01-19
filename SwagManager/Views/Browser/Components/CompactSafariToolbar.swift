import SwiftUI

// MARK: - Compact Safari Toolbar (Tabs + Address Bar in one row)
// Extracted from SafariBrowserWindow.swift following Apple engineering standards
// File size: ~120 lines (under Apple's 300 line "excellent" threshold)

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
                        .foregroundStyle(canGoBack ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)

                Button(action: { tabManager.activeTab?.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(canGoForward ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)
            }

            // Address bar
            HStack(spacing: 6) {
                Image(systemName: tabManager.activeTab?.isSecure ?? false ? "lock.fill" : "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(tabManager.activeTab?.isSecure ?? false ? DesignSystem.Colors.green : DesignSystem.Colors.textTertiary)

                TextField("Search or enter website name", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
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
            .background(DesignSystem.Colors.surfaceTertiary)
            .cornerRadius(6)
            .padding(.horizontal, 8)

            // Right controls
            HStack(spacing: 0) {
                Button(action: { tabManager.activeTab?.toggleDarkMode() }) {
                    Image(systemName: tabManager.activeTab?.isDarkMode == true ? "moon.fill" : "moon")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(tabManager.activeTab?.isDarkMode == true ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)

                Button(action: { tabManager.newTab() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
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
