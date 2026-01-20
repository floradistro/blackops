import SwiftUI

// MARK: - Enhanced Chat View (REFACTORED - AI-Powered)
//
// Previously 400 lines, now ~190 lines by extracting:
// - EnhancedChatStore.swift (150 lines) - State management and data loading
// - EnhancedChatView+WelcomeView.swift (60 lines) - Welcome screen
// - EnhancedChatView+QuickActions.swift (40 lines) - Quick action buttons
//
// File size: ~190 lines (under Apple's 300 line "excellent" threshold)

/// AI-enhanced chat with commands, mentions, and quick actions
/// Uses unified components, eliminates 624 lines of duplicate code
struct EnhancedChatView: View {
    @ObservedObject var store: EditorStore
    @StateObject internal var chatStore = EnhancedChatStore()
    @State internal var showCommandPalette = false
    @State internal var shouldScrollToBottom = false
    @FocusState internal var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            messageContent

            if chatStore.isAITyping {
                TypingIndicatorBubble(senderName: "AI Assistant")
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            if chatStore.showQuickActions && chatStore.draftMessage.isEmpty {
                quickActionsBar
            }

            if chatStore.showCommandSuggestions {
                commandSuggestionsView
            }

            if chatStore.showMentionSuggestions {
                mentionSuggestionsView
            }

            if chatStore.conversation != nil {
                enhancedMessageInput
            }
        }
        .background(DesignSystem.Materials.thin)
        .task {
            if let storeId = store.selectedStore?.id {
                await chatStore.loadConversations(storeId: storeId, supabase: store.supabase)
                chatStore.updateContext(from: store)
            }
        }
        .onChange(of: store.selectedStore?.id) { _, newId in
            if let storeId = newId {
                Task {
                    await chatStore.loadConversations(storeId: storeId, supabase: store.supabase)
                    chatStore.updateContext(from: store)
                }
            }
        }
        .onChange(of: store.selectedProduct?.id) { _, _ in
            chatStore.updateContext(from: store)
        }
        .onChange(of: store.selectedCategory?.id) { _, _ in
            chatStore.updateContext(from: store)
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if let conv = chatStore.conversation {
                // AI indicator
                ZStack {
                    Circle()
                        .fill(conv.chatType == "ai" ? DesignSystem.Colors.purple.opacity(0.2) : DesignSystem.Colors.green.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: conv.chatType == "ai" ? "sparkles" : "bubble.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(conv.chatType == "ai" ? DesignSystem.Colors.purple : DesignSystem.Colors.green)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(conv.displayTitle)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Circle()
                            .fill(DesignSystem.Colors.green)
                            .frame(width: 6, height: 6)
                        Text("Online")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }

                Spacer()

                // Context indicator
                if let productName = store.selectedProduct?.name {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "leaf")
                            .font(.system(size: 9))
                        Text(productName)
                            .font(DesignSystem.Typography.caption2)
                            .lineLimit(1)
                    }
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(Capsule())
                }
            } else {
                Text("Enhanced Chat")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceTertiary)
    }

    // MARK: - Message Content

    @ViewBuilder
    private var messageContent: some View {
        if store.selectedStore == nil {
            EmptyStateView(
                icon: "building.2",
                title: "No Store Selected",
                subtitle: "Select a store to start chatting with AI"
            )
        } else if chatStore.isLoading && chatStore.messages.isEmpty {
            LoadingStateView(message: "Loading conversation...")
        } else if let error = chatStore.error {
            ErrorStateView(
                error: error,
                retryAction: {
                    Task {
                        if let storeId = store.selectedStore?.id {
                            await chatStore.loadConversations(storeId: storeId, supabase: store.supabase)
                        }
                    }
                }
            )
        } else if chatStore.messages.isEmpty {
            welcomeView
        } else {
            messageList
        }
    }

}

// MARK: - Preview

#Preview {
    EnhancedChatView(store: EditorStore())
        .frame(width: 800, height: 600)
}
