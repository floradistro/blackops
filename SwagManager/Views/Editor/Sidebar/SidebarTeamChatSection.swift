import SwiftUI

// MARK: - Sidebar Communications Section
// Premium monochromatic design

struct SidebarTeamChatSection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        TreeSectionHeader(
            title: "Communications",
            icon: "bubble.left.and.bubble.right",
            iconColor: nil,
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
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))

                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.5))

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // Channels
            ForEach(channels) { channel in
                ChannelRow(
                    channel: channel,
                    isSelected: selectedId == channel.id,
                    onTap: { onSelect(channel) }
                )
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Channel Row

struct ChannelRow: View {
    let channel: Conversation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // Channel icon
                Text("#")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .frame(width: 14)

                // Channel name
                Text(channel.displayTitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.primary.opacity(isSelected ? 0.9 : 0.7))
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Message count badge
                if let count = channel.messageCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}

// MARK: - Email Campaigns Category

struct EmailCampaignsCategory: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(spacing: 2) {
            // Category header
            HStack(spacing: 6) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))

                Text("Email Campaigns")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.5))

                Spacer()

                Text("(\(store.emailCampaigns.count))")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // Campaigns
            ForEach(store.emailCampaigns.prefix(5)) { campaign in
                CampaignRow(
                    icon: "envelope",
                    title: campaign.name,
                    status: campaign.status.rawValue,
                    statusColor: Color.primary.opacity(0.5),
                    count: campaign.totalSent,
                    isSelected: store.selectedEmailCampaign?.id == campaign.id,
                    onTap: { store.selectEmailCampaign(campaign) }
                )
            }

            if store.emailCampaigns.count > 5 {
                Text("+\(store.emailCampaigns.count - 5) more")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Meta Campaigns Category

struct MetaCampaignsCategory: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(spacing: 2) {
            // Category header
            HStack(spacing: 6) {
                Image(systemName: "megaphone")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))

                Text("Meta Campaigns")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.5))

                Spacer()

                Text("(\(store.metaCampaigns.count))")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // Campaigns
            ForEach(store.metaCampaigns.prefix(5)) { campaign in
                CampaignRow(
                    icon: "megaphone",
                    title: campaign.name,
                    status: campaign.status ?? "unknown",
                    statusColor: Color.primary.opacity(0.5),
                    count: campaign.impressions,
                    isSelected: store.selectedMetaCampaign?.id == campaign.id,
                    onTap: { store.selectMetaCampaign(campaign) }
                )
            }

            if store.metaCampaigns.count > 5 {
                Text("+\(store.metaCampaigns.count - 5) more")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - SMS Campaigns Category

struct SMSCampaignsCategory: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(spacing: 2) {
            // Category header
            HStack(spacing: 6) {
                Image(systemName: "message")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))

                Text("SMS Campaigns")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.5))

                Spacer()

                Text("(\(store.smsCampaigns.count))")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // Campaigns
            ForEach(store.smsCampaigns.prefix(5)) { campaign in
                CampaignRow(
                    icon: "message",
                    title: campaign.name,
                    status: campaign.status.rawValue,
                    statusColor: Color.primary.opacity(0.5),
                    count: campaign.totalSent,
                    isSelected: false,
                    onTap: { }
                )
            }

            if store.smsCampaigns.count > 5 {
                Text("+\(store.smsCampaigns.count - 5) more")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 8)
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
            HStack(spacing: 6) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.45))
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 1) {
                    // Title
                    Text(title)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(isSelected ? 0.9 : 0.75))
                        .lineLimit(1)

                    // Status and count
                    HStack(spacing: 4) {
                        Text(status.capitalized)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.primary.opacity(0.45))

                        if count > 0 {
                            Text("•")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.primary.opacity(0.3))

                            Text("\(count)")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.primary.opacity(0.4))
                        }
                    }
                }

                Spacer(minLength: 4)
            }
            .frame(height: 28)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            )
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
            .font(.system(size: 10))
            .foregroundStyle(Color.primary.opacity(0.4))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}
