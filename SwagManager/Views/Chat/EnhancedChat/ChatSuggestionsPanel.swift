import SwiftUI

// MARK: - Chat Suggestions Panel
// Extracted from EnhancedChatView.swift following Apple engineering standards
// Contains: Command and mention suggestion dropdowns
// File size: ~70 lines (under Apple's 300 line "excellent" threshold)

extension EnhancedChatView {
    // MARK: - Command Suggestions

    internal var commandSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(chatStore.filteredCommands.prefix(5)) { cmd in
                Button {
                    chatStore.selectCommand(cmd)
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(cmd.command)
                            .font(DesignSystem.Typography.monoBody)
                            .foregroundStyle(DesignSystem.Colors.accent)

                        Text(cmd.description)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)

                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.surfaceElevated)
                }
                .buttonStyle(HoverButtonStyle())
            }
        }
        .background(DesignSystem.Colors.surfaceTertiary)
    }

    // MARK: - Mention Suggestions

    internal var mentionSuggestionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                mentionChip("Product", icon: "leaf")
                mentionChip("Category", icon: "folder")
                mentionChip("Store", icon: "building.2")
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.surfaceTertiary)
    }

    private func mentionChip(_ label: String, icon: String) -> some View {
        Button {
            chatStore.insertMention(label)
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.IconSize.small))
                Text("@\(label)")
                    .font(DesignSystem.Typography.caption1)
            }
            .foregroundStyle(DesignSystem.Colors.purple)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(DesignSystem.Colors.purple.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
