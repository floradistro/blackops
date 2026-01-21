import SwiftUI

// MARK: - Conversation Tree Components
// Extracted from TreeItems.swift following Apple engineering standards
// Contains: ConversationRow, ChatSectionLabel
// File size: ~51 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                Text("#")
                    .font(.system(size: DesignSystem.TreeSpacing.iconSize, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)

                Text(conversation.displayTitle)
                    .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize))
                    .foregroundStyle(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: DesignSystem.TreeSpacing.elementSpacing)

                if let count = conversation.messageCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: DesignSystem.TreeSpacing.itemHeight)
            .padding(.horizontal, DesignSystem.TreeSpacing.itemPaddingHorizontal)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isSelected ? DesignSystem.Colors.selectionActive : Color.clear)
            )
            .animation(DesignSystem.Animation.fast, value: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}

// MARK: - Chat Section Label

struct ChatSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(DesignSystem.Colors.textTertiary)
            .tracking(0.5)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.xs)
            .padding(.bottom, 3)
    }
}
