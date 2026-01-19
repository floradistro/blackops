import SwiftUI

// MARK: - Sidebar Team Chat Section
// Extracted from EditorSidebarView.swift following Apple engineering standards
// File size: ~78 lines (under Apple's 300 line "excellent" threshold)

struct SidebarTeamChatSection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        TreeSectionHeader(
            title: "TEAM CHAT",
            isExpanded: $store.sidebarChatExpanded,
            count: store.conversations.count
        )

        if store.sidebarChatExpanded {
            if store.selectedStore == nil {
                Text("Select a store")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            } else if store.conversations.isEmpty {
                Text("No conversations")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            } else {
                // Location chats
                let locationConvos = store.conversations.filter { $0.chatType == "location" }
                if !locationConvos.isEmpty {
                    ChatSectionLabel(title: "Locations")
                    ForEach(locationConvos) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: store.selectedConversation?.id == conversation.id,
                            onTap: { store.openConversation(conversation) }
                        )
                    }
                }

                // Pinned chats
                let pinnedTypes = ["bugs", "alerts", "team"]
                let pinnedConvos = store.conversations.filter { pinnedTypes.contains($0.chatType ?? "") }
                if !pinnedConvos.isEmpty {
                    ChatSectionLabel(title: "Pinned")
                    ForEach(pinnedConvos) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: store.selectedConversation?.id == conversation.id,
                            onTap: { store.openConversation(conversation) }
                        )
                    }
                }

                // Recent AI chats
                let aiConvos = store.conversations.filter { $0.chatType == "ai" }.prefix(10)
                if !aiConvos.isEmpty {
                    ChatSectionLabel(title: "Recent Chats")
                    ForEach(Array(aiConvos)) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: store.selectedConversation?.id == conversation.id,
                            onTap: { store.openConversation(conversation) }
                        )
                    }
                }
            }
        }
    }
}
