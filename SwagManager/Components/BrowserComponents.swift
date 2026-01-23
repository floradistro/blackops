import SwiftUI

// MARK: - Browser UI Components
// Optimized with smooth Apple-style animations

// MARK: - Browser Toolbar (inline, minimal)

struct BrowserToolbar: View {
    let sessionId: UUID
    @ObservedObject var tabManager: BrowserTabManager
    @State private var urlText: String = ""
    @FocusState private var isURLFieldFocused: Bool

    init(sessionId: UUID) {
        self.sessionId = sessionId
        self.tabManager = BrowserTabManager.forSession(sessionId)
    }

    var body: some View {
        HStack(spacing: 6) {
            navigationButtons
            addressBar
            actionButtons
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

    // MARK: - Subviews

    private var navigationButtons: some View {
        let activeTab = tabManager.activeTab
        let canGoBack = activeTab?.canGoBack ?? false
        let canGoForward = activeTab?.canGoForward ?? false
        let isLoading = activeTab?.isLoading ?? false

        return HStack(spacing: 2) {
            ToolbarButton(
                icon: "chevron.left",
                action: { activeTab?.goBack() },
                disabled: !canGoBack
            )
            ToolbarButton(
                icon: "chevron.right",
                action: { activeTab?.goForward() },
                disabled: !canGoForward
            )
            ToolbarButton(
                icon: isLoading ? "xmark" : "arrow.clockwise",
                action: {
                    if isLoading {
                        activeTab?.stop()
                    } else {
                        activeTab?.refresh()
                    }
                }
            )
        }
    }

    private var addressBar: some View {
        let activeTab = tabManager.activeTab
        let isSecure = activeTab?.isSecure ?? false
        let isLoading = activeTab?.isLoading ?? false

        return HStack(spacing: 4) {
            if isSecure {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .transition(.scale.combined(with: .opacity))
            }

            TextField("Search or enter URL", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .focused($isURLFieldFocused)
                .onSubmit { navigateToURL() }

            if isLoading {
                LoadingDots()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(isURLFieldFocused ? 0.06 : 0.04))
        .cornerRadius(4)
        .animation(.easeOut(duration: 0.15), value: isURLFieldFocused)
    }

    private var actionButtons: some View {
        let activeTab = tabManager.activeTab
        let isDarkMode = activeTab?.isDarkMode ?? false

        return HStack(spacing: 2) {
            ToolbarButton(
                icon: isDarkMode ? "moon.fill" : "moon",
                action: { activeTab?.toggleDarkMode() }
            )
            ToolbarButton(
                icon: "plus",
                action: { tabManager.newTab() }
            )
        }
    }

    // MARK: - Actions

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

// MARK: - Loading Dots Animation

struct LoadingDots: View {
    @State private var dotPhase = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.primary.opacity(dotPhase == index ? 0.5 : 0.2))
                    .frame(width: 3, height: 3)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.15)) {
                    dotPhase = (dotPhase + 1) % 3
                }
            }
        }
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let action: () -> Void
    var disabled: Bool = false

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.primary.opacity(disabled ? 0.2 : (isHovering ? 0.8 : 0.5)))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(
                            isPressed ? 0.1 :
                            isHovering && !disabled ? 0.06 : 0
                        ))
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.08)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
        )
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

// MARK: - Panel Toolbar (unified minimal toolbar for all detail panels)

struct PanelToolbar<Actions: View>: View {
    let title: String
    let icon: String
    var subtitle: String? = nil
    var hasChanges: Bool = false
    @ViewBuilder var actions: () -> Actions

    @State private var showChangeIndicator = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.4))
                .symbolEffect(.bounce, value: hasChanges)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.7))
                .lineLimit(1)

            if let subtitle = subtitle {
                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.3))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .lineLimit(1)
            }

            if hasChanges {
                Circle()
                    .fill(Color.primary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .transition(.scale.combined(with: .opacity))
                    .modifier(PulseModifier())
            }

            Spacer()

            actions()
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasChanges)
    }
}

// Convenience initializer without actions
extension PanelToolbar where Actions == EmptyView {
    init(title: String, icon: String, subtitle: String? = nil, hasChanges: Bool = false) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.hasChanges = hasChanges
        self.actions = { EmptyView() }
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

// SectionHeader and InfoRow are defined in FormFieldComponents.swift

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
                LoadingDots()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(4)
    }
}
