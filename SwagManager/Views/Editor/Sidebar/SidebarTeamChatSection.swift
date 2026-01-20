import SwiftUI

// MARK: - Sidebar Communications Section
// Discord-like channel structure with categories
// File size: under 200 lines following Apple engineering standards

struct SidebarTeamChatSection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        TreeSectionHeader(
            title: "COMMUNICATIONS",
            isExpanded: $store.sidebarChatExpanded,
            count: store.conversations.count
        )

        if store.sidebarChatExpanded {
            if store.selectedStore == nil {
                ChatEmptyStateView(message: "Select a store")
            } else if store.conversations.isEmpty {
                ChatEmptyStateView(message: "No channels yet")
            } else {
                ChannelList(store: store)
            }
        }
    }
}

// MARK: - Channel List

struct ChannelList: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        // Group conversations by type
        let teamChannels = store.conversations.filter { $0.chatType == "team" }.sorted { ($0.title ?? "") < ($1.title ?? "") }
        let locationChannels = store.conversations.filter { $0.chatType == "location" }.sorted { ($0.title ?? "") < ($1.title ?? "") }
        let alertChannels = store.conversations.filter { ["alerts", "bugs"].contains($0.chatType ?? "") }.sorted { ($0.title ?? "") < ($1.title ?? "") }
        let dmChannels = store.conversations.filter { $0.chatType == "dm" }.sorted { ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast) }
        let aiChannels = store.conversations.filter { $0.chatType == "ai" }.prefix(10)

        VStack(spacing: 0) {
            // Team Channels
            if !teamChannels.isEmpty {
                ChannelCategory(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "TEAM CHANNELS",
                    channels: teamChannels,
                    selectedId: store.selectedConversation?.id,
                    onSelect: { store.openConversation($0) }
                )
            }

            // Location Channels
            if !locationChannels.isEmpty {
                ChannelCategory(
                    icon: "mappin.and.ellipse",
                    title: "LOCATIONS",
                    channels: locationChannels,
                    selectedId: store.selectedConversation?.id,
                    onSelect: { store.openConversation($0) }
                )
            }

            // Alerts & Bugs
            if !alertChannels.isEmpty {
                ChannelCategory(
                    icon: "bell.badge.fill",
                    title: "ALERTS & BUGS",
                    channels: alertChannels,
                    selectedId: store.selectedConversation?.id,
                    onSelect: { store.openConversation($0) }
                )
            }

            // Direct Messages
            if !dmChannels.isEmpty {
                ChannelCategory(
                    icon: "person.2.fill",
                    title: "DIRECT MESSAGES",
                    channels: dmChannels,
                    selectedId: store.selectedConversation?.id,
                    onSelect: { store.openConversation($0) }
                )
            }

            // AI Assistants
            if !aiChannels.isEmpty {
                ChannelCategory(
                    icon: "sparkles",
                    title: "AI ASSISTANTS",
                    channels: Array(aiChannels),
                    selectedId: store.selectedConversation?.id,
                    onSelect: { store.openConversation($0) }
                )
            }
        }
    }
}

// MARK: - Channel Category

struct ChannelCategory: View {
    let icon: String
    let title: String
    let channels: [Conversation]
    let selectedId: UUID?
    let onSelect: (Conversation) -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            // Category header
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(0.5)

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)

            // Channels
            ForEach(channels) { channel in
                ChannelRow(
                    channel: channel,
                    isSelected: selectedId == channel.id,
                    onTap: { onSelect(channel) }
                )
            }
        }
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
}

// MARK: - Channel Row

struct ChannelRow: View {
    let channel: Conversation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Channel icon
                Text("#")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)

                // Channel name
                Text(channel.displayTitle)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()

                // Message count badge
                if let count = channel.messageCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
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

// MARK: - Empty State

private struct ChatEmptyStateView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(DesignSystem.Typography.caption1)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
    }
}
