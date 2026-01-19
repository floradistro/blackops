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
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text("#")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)

                Text(conversation.displayTitle)
                    .font(DesignSystem.Typography.caption2)
                    .lineLimit(1)

                Spacer()

                if let count = conversation.messageCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
        .padding(.horizontal, DesignSystem.Spacing.sm)
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
