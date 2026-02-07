import SwiftUI

// MARK: - Editor Tab Components
// Extracted from EditorView.swift to reduce file size and improve organization
// These components handle the tab UI for the editor

// MARK: - Editor Tab Enum

enum EditorTab: String, CaseIterable {
    case preview = "Preview"
    case code = "Code"
    case details = "Details"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .preview: return "play.display"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .details: return "info.circle"
        case .settings: return "gear"
        }
    }

    var terminalLabel: String {
        switch self {
        case .preview: return "▶"
        case .code: return "</>"
        case .details: return "ℹ"
        case .settings: return "⚙"
        }
    }
}

// MARK: - Minimal Tab Bar (VS Code / Terminal style)

struct MinimalTabBar: View {
    @Environment(\.editorStore) private var store

    var body: some View {
        HStack(spacing: 0) {
            // Traffic light spacer (70pt for macOS window buttons)
            Color.clear
                .frame(width: 78, height: 36)

            // Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(store.openTabs) { tab in
                        MinimalTab(
                            tab: tab,
                            isActive: store.activeTab?.id == tab.id,
                            hasUnsavedChanges: tabHasUnsavedChanges(tab),
                            onSelect: { store.switchToTab(tab) },
                            onClose: { store.closeTab(tab) },
                            onCloseOthers: { store.closeOtherTabs(except: tab) },
                            onCloseAll: { store.closeAllTabs() }
                        )
                    }
                }
                .padding(.trailing, 20)
            }
        }
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func tabHasUnsavedChanges(_ tab: OpenTabItem) -> Bool {
        // No creation tabs - unsaved changes tracked elsewhere
        return false
    }
}

// MARK: - Minimal Tab

struct MinimalTab: View {
    let tab: OpenTabItem
    let isActive: Bool
    let hasUnsavedChanges: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    var onCloseOthers: (() -> Void)? = nil
    var onCloseAll: (() -> Void)? = nil

    @State private var isHovering = false

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 6) {
                // Icon
                Image(systemName: tab.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(isActive ? 0.8 : 0.5))

                // Title
                Text(tab.name)
                    .font(.system(size: 12, weight: isActive ? .medium : .regular))
                    .foregroundStyle(Color.primary.opacity(isActive ? 0.9 : 0.6))
                    .lineLimit(1)

                // Close button / unsaved indicator
                ZStack {
                    if hasUnsavedChanges && !isHovering {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                    } else if isHovering || isActive {
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.primary.opacity(0.5))
                                .frame(width: 16, height: 16)
                                .background(isHovering ? Color.primary.opacity(0.1) : Color.clear)
                                .cornerRadius(3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                isActive
                    ? Color.primary.opacity(0.08)
                    : (isHovering ? Color.primary.opacity(0.04) : Color.clear)
            )
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1),
                alignment: .trailing
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Close") { onClose() }
            if let closeOthers = onCloseOthers {
                Button("Close Others") { closeOthers() }
            }
            if let closeAll = onCloseAll {
                Button("Close All") { closeAll() }
            }
        }
    }
}

// MARK: - Toolbar Tab Strip (Legacy)

struct ToolbarTabStrip: View {
    @Environment(\.editorStore) private var store

    var body: some View {
        HStack(spacing: 0) {
            ForEach(store.openTabs) { tab in
                SafariStyleTab(
                    tab: tab,
                    isActive: store.activeTab?.id == tab.id,
                    hasUnsavedChanges: tabHasUnsavedChanges(tab),
                    onSelect: { store.switchToTab(tab) },
                    onClose: { store.closeTab(tab) }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 22)
        .animation(DesignSystem.Animation.fast, value: store.openTabs.count)
    }

    private func tabHasUnsavedChanges(_ tab: OpenTabItem) -> Bool {
        // No creation tabs - unsaved changes tracked elsewhere
        return false
    }
}

// MARK: - Safari-Style Tab

struct SafariStyleTab: View {
    let tab: OpenTabItem
    let isActive: Bool
    let hasUnsavedChanges: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 6) {
                // Icon
                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)

                // Title
                Text(tab.name)
                    .font(.system(size: 11.5, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 4)

                // Close button / unsaved indicator
                ZStack {
                    if hasUnsavedChanges && !isHovering {
                        Circle()
                            .fill(DesignSystem.Colors.orange)
                            .frame(width: 6, height: 6)
                    } else if isHovering || isActive {
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 7.5, weight: .semibold))
                                .foregroundStyle(isActive ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textTertiary)
                                .frame(width: 16, height: 16)
                                .background(
                                    Circle()
                                        .fill(isHovering ? DesignSystem.Colors.surfaceHover : Color.clear)
                                )
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    if isActive {
                        // Glass-style active tab
                        DesignSystem.Colors.surfaceActive
                    } else if isHovering {
                        // Subtle hover
                        DesignSystem.Colors.surfaceTertiary
                    } else {
                        // Transparent
                        Color.clear
                    }
                }
            )
            .overlay(
                Rectangle()
                    .frame(width: 0.5)
                    .foregroundStyle(DesignSystem.Colors.borderSubtle)
                , alignment: .trailing
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Close Tab") { onClose() }
            Button("Close Other Tabs") { }
            Button("Close All Tabs") { }
        }
    }
}

// MARK: - Editor Mode Strip

struct EditorModeStrip: View {
    @Binding var selectedTab: EditorTab
    @State private var hoveringTab: EditorTab?

    var body: some View {
        HStack(spacing: 1) {
            ForEach(EditorTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(DesignSystem.Animation.spring) { selectedTab = tab }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(selectedTab == tab ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selectedTab == tab ? DesignSystem.Colors.selectionActive : (hoveringTab == tab ? DesignSystem.Colors.surfaceHover : Color.clear))
                        )
                }
                .buttonStyle(.borderless)
                .help(tab.rawValue)
                .onHover { hovering in
                    withAnimation(DesignSystem.Animation.fast) { hoveringTab = hovering ? tab : nil }
                }
            }
        }
        .padding(3)
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Open Tab Bar (Legacy - kept for reference)

struct OpenTabBar: View {
    @Environment(\.editorStore) private var store

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(store.openTabs) { tab in
                    OpenTabButton(
                        tab: tab,
                        isActive: store.activeTab?.id == tab.id,
                        hasUnsavedChanges: tabHasUnsavedChanges(tab),
                        onSelect: { store.switchToTab(tab) },
                        onClose: { store.closeTab(tab) },
                        onCloseOthers: { store.closeOtherTabs(except: tab) },
                        onCloseAll: { store.closeAllTabs() },
                        onCloseToRight: { store.closeTabsToRight(of: tab) }
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .frame(height: 32)
        .background(DesignSystem.Colors.surfaceTertiary)
        .contextMenu {
            Button("Close All Tabs") {
                store.closeAllTabs()
            }
            .disabled(store.openTabs.isEmpty)
        }
    }

    private func tabHasUnsavedChanges(_ tab: OpenTabItem) -> Bool {
        // No creation tabs - unsaved changes tracked elsewhere
        return false
    }
}

struct OpenTabButton: View {
    let tab: OpenTabItem
    let isActive: Bool
    let hasUnsavedChanges: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onCloseOthers: () -> Void
    let onCloseAll: () -> Void
    let onCloseToRight: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            // Icon
            Image(systemName: tab.icon)
                .font(.system(size: 10))
                .foregroundStyle(isActive ? tab.iconColor : tab.iconColor.opacity(0.6))

            // Name
            Text(tab.name)
                .font(.system(size: 11, weight: isActive ? .medium : .regular))
                .lineLimit(1)

            // Unsaved indicator or close button
            if hasUnsavedChanges && !isHovering {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            } else {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(isHovering ? .secondary : .quaternary)
                        .frame(width: 14, height: 14)
                        .background(isHovering ? DesignSystem.Colors.surfaceHover : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .opacity(isHovering || isActive ? 1 : 0)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isActive ? DesignSystem.Colors.surfaceElevated : (isHovering ? DesignSystem.Colors.surfaceTertiary : Color.clear))
        )
        .foregroundStyle(isActive ? .primary : .secondary)
        .onHover { isHovering = $0 }
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Close") { onClose() }
            Button("Close Others") { onCloseOthers() }
            Button("Close Tabs to Right") { onCloseToRight() }
            Divider()
            Button("Close All") { onCloseAll() }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let tab: EditorTab
    let isSelected: Bool
    let hasChanges: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : DesignSystem.Colors.textSecondary)
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .medium))
                if hasChanges {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                }
            }
            .foregroundStyle(isSelected ? .primary : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? DesignSystem.Colors.surfaceActive : (isHovering ? DesignSystem.Colors.surfaceHover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
