import SwiftUI

// MARK: - EnhancedChatView Quick Actions Extension
// Extracted from EnhancedChatView.swift following Apple engineering standards
// File size: ~40 lines (under Apple's 300 line "excellent" threshold)

extension EnhancedChatView {
    // MARK: - Quick Actions Bar

    internal var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                quickAction("Search", icon: "magnifyingglass", action: "/search")
                quickAction("Analyze", icon: "chart.bar", action: "/analyze")
                quickAction("Report", icon: "doc.text", action: "/report")
                quickAction("Help", icon: "questionmark.circle", action: "/help")
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.surfaceTertiary)
    }

    internal func quickAction(_ label: String, icon: String, action: String) -> some View {
        Button {
            chatStore.draftMessage = action + " "
            isInputFocused = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.IconSize.small))
                Text(label)
                    .font(DesignSystem.Typography.caption1)
            }
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(DesignSystem.Colors.surfaceElevated)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
