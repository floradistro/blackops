import SwiftUI

// MARK: - Sidebar Communications Section
// Discord-like channel structure with categories
// File size: under 200 lines following Apple engineering standards

struct SidebarTeamChatSection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        TreeSectionHeader(
            title: "Communications",
            icon: "bubble.left.and.bubble.right.fill",
            iconColor: DesignSystem.Colors.cyan,
            isExpanded: $store.sidebarChatExpanded,
            count: store.conversations.count,
            isLoading: store.isLoadingConversations
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
                    title: "Team Channels",
                    channels: teamChannels,
                    selectedId: store.selectedConversation?.id,
                    onSelect: { store.openConversation($0) }
                )
            }

            // Location Channels
            if !locationChannels.isEmpty {
                ChannelCategory(
                    icon: "mappin.and.ellipse",
                    title: "Locations",
                    channels: locationChannels,
                    selectedId: store.selectedConversation?.id,
                    onSelect: { store.openConversation($0) }
                )
            }

            // Alerts & Bugs
            if !alertChannels.isEmpty {
                ChannelCategory(
                    icon: "bell.badge.fill",
                    title: "Alerts & Bugs",
                    channels: alertChannels,
                    selectedId: store.selectedConversation?.id,
                    onSelect: { store.openConversation($0) }
                )
            }

            // Direct Messages
            if !dmChannels.isEmpty {
                ChannelCategory(
                    icon: "person.2.fill",
                    title: "Direct Messages",
                    channels: dmChannels,
                    selectedId: store.selectedConversation?.id,
                    onSelect: { store.openConversation($0) }
                )
            }

            // AI Assistants
            if !aiChannels.isEmpty {
                ChannelCategory(
                    icon: "sparkles",
                    title: "AI Assistants",
                    channels: Array(aiChannels),
                    selectedId: store.selectedConversation?.id,
                    onSelect: { store.openConversation($0) }
                )
            }

            // Email Campaigns (moved from CRM)
            if !store.emailCampaigns.isEmpty {
                EmailCampaignsCategory(store: store)
            }

            // Meta Campaigns (moved from CRM)
            if !store.metaCampaigns.isEmpty {
                MetaCampaignsCategory(store: store)
            }

            // SMS Campaigns (moved from CRM)
            if !store.smsCampaigns.isEmpty {
                SMSCampaignsCategory(store: store)
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
        VStack(spacing: 0) {
            // Category header
            HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.TreeSpacing.chevronSize, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Spacer(minLength: DesignSystem.TreeSpacing.elementSpacing)
            }
            .padding(.horizontal, DesignSystem.TreeSpacing.itemPaddingHorizontal)
            .padding(.vertical, DesignSystem.TreeSpacing.sectionPaddingVertical)

            // Channels
            ForEach(channels) { channel in
                ChannelRow(
                    channel: channel,
                    isSelected: selectedId == channel.id,
                    onTap: { onSelect(channel) }
                )
            }
        }
        .padding(.bottom, DesignSystem.TreeSpacing.sectionPaddingTop)
    }
}

// MARK: - Channel Row

struct ChannelRow: View {
    let channel: Conversation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                // Channel icon
                Text("#")
                    .font(.system(size: DesignSystem.TreeSpacing.iconSize, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .frame(width: 14)

                // Channel name
                Text(channel.displayTitle)
                    .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize))
                    .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: DesignSystem.TreeSpacing.elementSpacing)

                // Message count badge
                if let count = channel.messageCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
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

// MARK: - Email Campaigns Category

struct EmailCampaignsCategory: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            // Category header
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.blue)

                Text("Email Campaigns")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Spacer()

                Text("(\(store.emailCampaigns.count))")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)

            // Campaigns
            ForEach(store.emailCampaigns.prefix(5)) { campaign in
                CampaignRow(
                    icon: "envelope",
                    title: campaign.name,
                    status: campaign.status.rawValue,
                    statusColor: emailStatusColor(campaign.status),
                    count: campaign.totalSent,
                    isSelected: store.selectedEmailCampaign?.id == campaign.id,
                    onTap: { store.selectEmailCampaign(campaign) }
                )
            }

            if store.emailCampaigns.count > 5 {
                Text("+\(store.emailCampaigns.count - 5) more")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
            }
        }
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    func emailStatusColor(_ status: CampaignStatus) -> Color {
        switch status {
        case .draft: return DesignSystem.Colors.textTertiary
        case .scheduled: return DesignSystem.Colors.orange
        case .sending: return DesignSystem.Colors.blue
        case .sent: return DesignSystem.Colors.green
        case .paused: return DesignSystem.Colors.yellow
        case .cancelled: return DesignSystem.Colors.red
        case .testing: return DesignSystem.Colors.purple
        }
    }
}

// MARK: - Meta Campaigns Category

struct MetaCampaignsCategory: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            // Category header
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "megaphone")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.pink)

                Text("Meta Campaigns")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Spacer()

                Text("(\(store.metaCampaigns.count))")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)

            // Campaigns
            ForEach(store.metaCampaigns.prefix(5)) { campaign in
                CampaignRow(
                    icon: "megaphone.fill",
                    title: campaign.name,
                    status: campaign.status ?? "unknown",
                    statusColor: DesignSystem.Colors.pink,
                    count: campaign.impressions,
                    isSelected: store.selectedMetaCampaign?.id == campaign.id,
                    onTap: { store.selectMetaCampaign(campaign) }
                )
            }

            if store.metaCampaigns.count > 5 {
                Text("+\(store.metaCampaigns.count - 5) more")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
            }
        }
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
}

// MARK: - SMS Campaigns Category

struct SMSCampaignsCategory: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            // Category header
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "message")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.green)

                Text("SMS Campaigns")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Spacer()

                Text("(\(store.smsCampaigns.count))")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)

            // Campaigns
            ForEach(store.smsCampaigns.prefix(5)) { campaign in
                CampaignRow(
                    icon: "message.fill",
                    title: campaign.name,
                    status: campaign.status.rawValue,
                    statusColor: DesignSystem.Colors.green,
                    count: campaign.totalSent,
                    isSelected: false, // SMS campaigns don't have selection yet
                    onTap: { print("SMS Campaign: \(campaign.name)") }
                )
            }

            if store.smsCampaigns.count > 5 {
                Text("+\(store.smsCampaigns.count - 5) more")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
            }
        }
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
}

// MARK: - Campaign Row

struct CampaignRow: View {
    let icon: String
    let title: String
    let status: String
    let statusColor: Color
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                    .foregroundColor(statusColor)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    // Title
                    Text(title)
                        .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize, weight: .medium))
                        .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                        .lineLimit(1)

                    // Status and count
                    HStack(spacing: DesignSystem.TreeSpacing.elementSpacing) {
                        Text(status.capitalized)
                            .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                            .foregroundColor(statusColor)

                        if count > 0 {
                            Text("•")
                                .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                                .foregroundColor(DesignSystem.Colors.textTertiary)

                            Text("\(count)")
                                .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    }
                }

                Spacer(minLength: DesignSystem.TreeSpacing.elementSpacing)
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

// MARK: - Empty State

private struct ChatEmptyStateView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(DesignSystem.Typography.caption1)
            .foregroundColor(DesignSystem.Colors.textTertiary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
    }
}
