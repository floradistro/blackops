import SwiftUI
import Supabase

// MARK: - Team Chat View (REFACTORED - Apple Standard)

/// Modern team chat interface using unified design system
/// Eliminates 1,218 lines of duplicate code
struct TeamChatView: View {
    @ObservedObject var store: EditorStore
    @StateObject private var chatStore = ChatStore()
    @State private var shouldScrollToBottom = false

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            messageContent
            if chatStore.conversation != nil {
                messageInput
            }
        }
        .background(DesignSystem.Materials.thin)
        .task {
            if let storeId = store.selectedStore?.id {
                NSLog("[TeamChatView] Loading conversations for store: \(storeId)")
                await chatStore.loadConversations(storeId: storeId, supabase: store.supabase)
            }
        }
        .onChange(of: store.selectedStore?.id) { _, newId in
            if let storeId = newId {
                Task {
                    NSLog("[TeamChatView] Store changed, loading conversations for: \(storeId)")
                    await chatStore.loadConversations(storeId: storeId, supabase: store.supabase)
                }
            }
        }
        .onChange(of: store.selectedConversation) { _, newConversation in
            if let conversation = newConversation {
                Task {
                    NSLog("[TeamChatView] Syncing selected conversation from store: \(conversation.displayTitle)")
                    await chatStore.selectConversation(conversation, supabase: store.supabase)
                }
            }
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: DesignSystem.IconSize.medium))
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Text("Team Chat")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            // Conversation picker
            if !chatStore.conversations.isEmpty {
                conversationPicker
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceTertiary)
    }

    private var conversationPicker: some View {
        Menu {
            ForEach(chatStore.conversations) { conversation in
                Button {
                    Task {
                        await chatStore.selectConversation(conversation, supabase: store.supabase)
                    }
                } label: {
                    HStack {
                        Image(systemName: conversation.chatTypeIcon)
                        Text(conversation.displayTitle)
                        if chatStore.conversation?.id == conversation.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                if let conv = chatStore.conversation {
                    Image(systemName: conv.chatTypeIcon)
                    Text(conv.displayTitle)
                        .font(DesignSystem.Typography.subheadline)
                } else {
                    Text("Select Conversation")
                        .font(DesignSystem.Typography.subheadline)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: DesignSystem.IconSize.small))
            }
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(DesignSystem.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Message Content

    @ViewBuilder
    private var messageContent: some View {
        if store.selectedStore == nil {
            EmptyStateView(
                icon: "building.2",
                title: "No Store Selected",
                subtitle: "Select a store to view team conversations"
            )
        } else if chatStore.isLoading && chatStore.messages.isEmpty {
            LoadingStateView(message: "Loading messages...")
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
        } else if chatStore.conversations.isEmpty {
            EmptyStateView(
                icon: "bubble.left.and.bubble.right",
                title: "No Conversations",
                subtitle: "No team conversations found for this store"
            )
        } else if chatStore.messages.isEmpty {
            EmptyStateView(
                icon: "message",
                title: "No Messages",
                subtitle: "Start the conversation by sending a message"
            )
        } else {
            messageList
        }
    }

    // MARK: - Message List (OPTIMIZED with LazyVStack)

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Group messages by date using centralized formatter
                    let groups = Formatters.groupMessagesByDate(chatStore.messages) { $0.createdAt }

                    ForEach(groups) { group in
                        ChatDateSeparator(date: group.date)

                        // Compute grouping once for performance
                        let groupIndices = group.items.groupedIndices()

                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, message in
                            let grouping = groupIndices[index]
                            let isPending = chatStore.pendingMessageIds.contains(message.id)

                            ChatMessageBubble(
                                message: message,
                                config: .init(
                                    isFromCurrentUser: message.senderId == chatStore.currentUserId,
                                    showAvatar: true,
                                    isFirstInGroup: grouping.first,
                                    isLastInGroup: grouping.last,
                                    isPending: isPending,
                                    style: .standard
                                )
                            )
                        }
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .scrollBounceBehavior(.always)
            .onChange(of: shouldScrollToBottom) { _, shouldScroll in
                if shouldScroll {
                    withAnimation(DesignSystem.Animation.medium) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    shouldScrollToBottom = false
                }
            }
            .onChange(of: chatStore.messages.count) { _, _ in
                shouldScrollToBottom = true
            }
        }
    }

    // MARK: - Message Input

    private var messageInput: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            TextField("Message...", text: $chatStore.draftMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                .lineLimit(1...6)
                .onSubmit {
                    Task { await chatStore.sendMessage(supabase: store.supabase) }
                }

            Button {
                Task { await chatStore.sendMessage(supabase: store.supabase) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        chatStore.draftMessage.isEmpty
                            ? DesignSystem.Colors.textQuaternary
                            : DesignSystem.Colors.accent
                    )
            }
            .buttonStyle(.plain)
            .disabled(chatStore.draftMessage.isEmpty)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceTertiary)
    }
}

// MARK: - Chat Store (KEPT - Well Implemented)

@MainActor
class ChatStore: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var conversation: Conversation?
    @Published var messages: [ChatMessage] = []
    @Published var draftMessage = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var typingUsers: [UUID] = []
    @Published var pendingMessageIds: Set<UUID> = []

    var currentUserId: UUID?

    func loadConversations(storeId: UUID, supabase: SupabaseService) async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let user = try await supabase.client.auth.user()
            currentUserId = user.id
            NSLog("[ChatStore] Current user: \(user.id)")

            // Fetch ALL conversations for this store AND its locations
            conversations = try await supabase.fetchAllConversationsForStoreLocations(storeId: storeId, fetchLocations: { storeId in
                try await supabase.fetchLocations(storeId: storeId)
            })
            NSLog("[ChatStore] Found \(conversations.count) total conversations for store \(storeId)")

            // Auto-select first conversation if available
            if let first = conversations.first {
                await selectConversation(first, supabase: supabase)
            }
        } catch {
            self.error = error.localizedDescription
            NSLog("[ChatStore] Error loading conversations: \(error)")
        }

        isLoading = false
    }

    func selectConversation(_ conv: Conversation, supabase: SupabaseService) async {
        conversation = conv
        messages = []

        do {
            messages = try await supabase.fetchMessages(conversationId: conv.id, limit: 100)
            NSLog("[ChatStore] Loaded \(messages.count) messages for conversation \(conv.id)")
        } catch {
            NSLog("[ChatStore] Error loading messages: \(error)")
        }
    }

    func loadConversation(storeId: UUID, supabase: SupabaseService) async {
        await loadConversations(storeId: storeId, supabase: supabase)
    }

    func sendMessage(supabase: SupabaseService) async {
        guard !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let conversationId = conversation?.id,
              let userId = currentUserId else { return }

        let content = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        draftMessage = ""

        // Create optimistic message for instant UI update
        let optimisticId = UUID()
        let optimisticMessage = ChatMessage(
            id: optimisticId,
            conversationId: conversationId,
            role: "user",
            content: content,
            toolCalls: nil,
            tokensUsed: nil,
            senderId: userId,
            isAiInvocation: false,
            aiPrompt: nil,
            replyToMessageId: nil,
            createdAt: Date()
        )

        // Add to pending and messages immediately
        pendingMessageIds.insert(optimisticId)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            messages.append(optimisticMessage)
        }

        let insert = ChatMessageInsert(
            conversationId: conversationId,
            role: "user",
            content: content,
            senderId: userId,
            isAiInvocation: false,
            replyToMessageId: nil
        )

        do {
            let newMessage = try await supabase.sendMessage(insert)
            // Replace optimistic message with real one
            if let index = messages.firstIndex(where: { $0.id == optimisticId }) {
                withAnimation(.easeOut(duration: 0.15)) {
                    messages[index] = newMessage
                    pendingMessageIds.remove(optimisticId)
                }
            }
        } catch {
            self.error = error.localizedDescription
            NSLog("[ChatStore] Error sending message: \(error)")
            // Remove optimistic message on error
            withAnimation {
                messages.removeAll { $0.id == optimisticId }
                pendingMessageIds.remove(optimisticId)
            }
            // Restore draft
            draftMessage = content
        }
    }

    func loadMoreMessages(supabase: SupabaseService) async {
        guard let convId = conversation?.id,
              let oldestMessage = messages.first,
              let oldestDate = oldestMessage.createdAt else { return }

        do {
            let olderMessages = try await supabase.fetchMessages(conversationId: convId, limit: 50, before: oldestDate)
            messages.insert(contentsOf: olderMessages, at: 0)
        } catch {
            NSLog("[ChatStore] Error loading more messages: \(error)")
        }
    }

    func loadConversationMessages(_ conv: Conversation, supabase: SupabaseService) async {
        conversation = conv
        messages = []
        isLoading = true
        error = nil

        do {
            // Get current user
            let user = try await supabase.client.auth.user()
            currentUserId = user.id

            messages = try await supabase.fetchMessages(conversationId: conv.id, limit: 100)
            NSLog("[ChatStore] Loaded \(messages.count) messages for conversation \(conv.id)")
        } catch {
            self.error = error.localizedDescription
            NSLog("[ChatStore] Error loading messages: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    TeamChatView(store: EditorStore())
        .frame(width: 800, height: 600)
}
