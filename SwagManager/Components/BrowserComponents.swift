import SwiftUI

// MARK: - Browser UI Components
// Minimal, sleek browser controls

// MARK: - Browser Toolbar (inline, minimal)

struct BrowserToolbar: View {
    let sessionId: UUID
    @State private var urlText: String = ""
    @FocusState private var isURLFieldFocused: Bool

    private var tabManager: BrowserTabManager {
        BrowserTabManager.forSession(sessionId)
    }

    var body: some View {
        HStack(spacing: 6) {
            // Navigation buttons
            HStack(spacing: 2) {
                ToolbarButton(
                    icon: "chevron.left",
                    action: { tabManager.activeTab?.goBack() },
                    disabled: !(tabManager.activeTab?.canGoBack ?? false)
                )
                ToolbarButton(
                    icon: "chevron.right",
                    action: { tabManager.activeTab?.goForward() },
                    disabled: !(tabManager.activeTab?.canGoForward ?? false)
                )
                ToolbarButton(
                    icon: tabManager.activeTab?.isLoading == true ? "xmark" : "arrow.clockwise",
                    action: {
                        if tabManager.activeTab?.isLoading == true {
                            tabManager.activeTab?.stop()
                        } else {
                            tabManager.activeTab?.reload()
                        }
                    }
                )
            }

            // Address bar
            HStack(spacing: 4) {
                if tabManager.activeTab?.isSecure == true {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }

                TextField("Search or enter URL", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .focused($isURLFieldFocused)
                    .onSubmit { navigateToURL() }

                if tabManager.activeTab?.isLoading == true {
                    Text("···")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.3))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(4)

            // Actions
            HStack(spacing: 2) {
                ToolbarButton(
                    icon: tabManager.activeTab?.isDarkMode == true ? "moon.fill" : "moon",
                    action: { tabManager.activeTab?.toggleDarkMode() }
                )
                ToolbarButton(
                    icon: "plus",
                    action: { tabManager.newTab() }
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
        .onChange(of: tabManager.activeTab?.currentURL) { _, newURL in
            if !isURLFieldFocused {
                urlText = newURL ?? ""
            }
        }
        .onAppear {
            urlText = tabManager.activeTab?.currentURL ?? ""
        }
    }

    private func navigateToURL() {
        guard !urlText.isEmpty else { return }
        var urlString = urlText.trimmingCharacters(in: .whitespaces)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if urlString.contains(".") {
                urlString = "https://" + urlString
            } else {
                urlString = "https://www.google.com/search?q=" + (urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)
            }
        }
        tabManager.activeTab?.navigate(to: urlString)
        isURLFieldFocused = false
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let action: () -> Void
    var disabled: Bool = false

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.primary.opacity(disabled ? 0.2 : (isHovering ? 0.8 : 0.5)))
                .frame(width: 24, height: 24)
                .background(isHovering && !disabled ? Color.primary.opacity(0.06) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Content Toolbar (generic for any view that needs tools)

struct ContentToolbar: View {
    let title: String?
    let icon: String?
    var actions: [ToolbarAction] = []

    struct ToolbarAction: Identifiable {
        let id = UUID()
        let icon: String
        let action: () -> Void
        var disabled: Bool = false
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }

            if let title = title {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.7))
            }

            Spacer()

            ForEach(actions) { action in
                ToolbarButton(
                    icon: action.icon,
                    action: action.action,
                    disabled: action.disabled
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Legacy Browser Controls Bar

struct BrowserControlsBar: View {
    let sessionId: UUID

    var body: some View {
        BrowserToolbar(sessionId: sessionId)
    }
}

// MARK: - Browser Address Field (Legacy)

struct BrowserAddressField: View {
    @Binding var urlText: String
    let isSecure: Bool
    let isLoading: Bool
    @FocusState.Binding var isURLFieldFocused: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if isSecure {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }

            TextField("Search or enter URL", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .focused($isURLFieldFocused)
                .onSubmit(onSubmit)

            if isLoading {
                Text("···")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.3))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(4)
    }
}
