import SwiftUI

// MARK: - Editor Tab Components
// Extracted from EditorView.swift to reduce file size and improve organization
// These components handle the tab UI for the editor

// MARK: - Toolbar Tab Strip

struct ToolbarTabStrip: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        HStack(spacing: 0) {
            if store.openTabs.isEmpty {
                Text("Swag Manager")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            } else {
                // Safari-style proportional tabs - each tab gets equal width
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
        }
        .frame(height: 26)
        .animation(DesignSystem.Animation.fast, value: store.openTabs.count)
    }

    private func tabHasUnsavedChanges(_ tab: OpenTabItem) -> Bool {
        if case .creation(let c) = tab, c.id == store.selectedCreation?.id {
            return store.hasUnsavedChanges
        }
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
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
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

// MARK: - Editor Tab Bar (VSCode-style)

struct EditorTabBar: View {
    let creation: Creation?
    @Binding var selectedTab: EditorTab
    @Binding var sidebarCollapsed: Bool
    let hasUnsavedChanges: Bool
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Show sidebar button (only when collapsed)
            if sidebarCollapsed {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { sidebarCollapsed = false }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(DesignSystem.Colors.border)
                    .frame(width: 1, height: 18)
                    .padding(.trailing, 8)
            }

            // Tabs
            HStack(spacing: 2) {
                ForEach(EditorTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        hasChanges: tab == .code && hasUnsavedChanges
                    ) {
                        withAnimation(.easeOut(duration: 0.1)) { selectedTab = tab }
                    }
                }
            }

            Spacer()

            // File info & save
            if let creation = creation {
                HStack(spacing: 12) {
                    // File name
                    HStack(spacing: 5) {
                        if hasUnsavedChanges {
                            Circle()
                                .fill(DesignSystem.Colors.orange)
                                .frame(width: 5, height: 5)
                        }
                        Text(creation.name)
                            .font(.system(size: 11))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)
                    }

                    // Save button
                    Button {
                        onSave()
                    } label: {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(hasUnsavedChanges ? .primary : DesignSystem.Colors.textQuaternary)
                            .frame(width: 28, height: 28)
                            .background(hasUnsavedChanges ? DesignSystem.Colors.surfaceElevated : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("s", modifiers: .command)
                }
                .padding(.trailing, 8)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 38)
        .background(DesignSystem.Colors.surfaceTertiary)
    }
}

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
                        .fill(DesignSystem.Colors.orange)
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
