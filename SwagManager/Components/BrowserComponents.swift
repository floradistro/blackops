import SwiftUI

// MARK: - Browser UI Components
// Extracted from EditorView.swift to reduce file size and improve organization

// MARK: - Browser Controls Bar (Above browser content only)

struct BrowserControlsBar: View {
    let sessionId: UUID
    @State private var urlText: String = ""
    @FocusState private var isURLFieldFocused: Bool

    private var tabManager: BrowserTabManager {
        BrowserTabManager.forSession(sessionId)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Back/Forward
            Button(action: { tabManager.activeTab?.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(!(tabManager.activeTab?.canGoBack ?? false))
            .foregroundStyle((tabManager.activeTab?.canGoBack ?? false) ? .primary : .tertiary)

            Button(action: { tabManager.activeTab?.goForward() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(!(tabManager.activeTab?.canGoForward ?? false))
            .foregroundStyle((tabManager.activeTab?.canGoForward ?? false) ? .primary : .tertiary)

            // Address bar
            BrowserAddressField(
                urlText: $urlText,
                isSecure: tabManager.activeTab?.isSecure ?? false,
                isLoading: tabManager.activeTab?.isLoading ?? false,
                isURLFieldFocused: $isURLFieldFocused,
                onSubmit: { navigateToURL() }
            )
            .onChange(of: tabManager.activeTab?.currentURL) { _, newURL in
                if !isURLFieldFocused {
                    urlText = newURL ?? ""
                }
            }
            .onAppear {
                urlText = tabManager.activeTab?.currentURL ?? ""
            }

            // Dark mode & New tab
            Button(action: { tabManager.activeTab?.toggleDarkMode() }) {
                Image(systemName: tabManager.activeTab?.isDarkMode == true ? "moon.fill" : "moon")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)

            Button(action: { tabManager.newTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VisualEffectBackground(material: .titlebar))
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

// MARK: - Browser Address Field

struct BrowserAddressField: View {
    @Binding var urlText: String
    let isSecure: Bool
    let isLoading: Bool
    @FocusState.Binding var isURLFieldFocused: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isSecure ? "lock.fill" : "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(isSecure ? DesignSystem.Colors.green : DesignSystem.Colors.textTertiary)

            TextField("Search or enter website name", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .focused($isURLFieldFocused)
                .onSubmit(onSubmit)

            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(DesignSystem.Colors.surfaceTertiary)
        .cornerRadius(6)
    }
}
