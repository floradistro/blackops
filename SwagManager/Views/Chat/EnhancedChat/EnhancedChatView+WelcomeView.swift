import SwiftUI

// MARK: - EnhancedChatView Welcome View Extension
// Extracted from EnhancedChatView.swift following Apple engineering standards
// File size: ~60 lines (under Apple's 300 line "excellent" threshold)

extension EnhancedChatView {
    // MARK: - Welcome View

    internal var welcomeView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DesignSystem.Colors.purple)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("AI Assistant Ready")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Ask me anything about your products, inventory, or store operations")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                quickActionButton(icon: "magnifyingglass", text: "Search products")
                quickActionButton(icon: "chart.bar", text: "View analytics")
                quickActionButton(icon: "square.and.pencil", text: "Create report")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }

    internal func quickActionButton(icon: String, text: String) -> some View {
        Button {
            chatStore.draftMessage = text
            isInputFocused = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.IconSize.medium))
                Text(text)
                    .font(DesignSystem.Typography.body)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: DesignSystem.IconSize.small))
            }
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        }
        .buttonStyle(.plain)
    }
}
