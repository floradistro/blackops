import SwiftUI
import Supabase

// MARK: - Team Chat View (REFACTORED - Apple Standard)

/// Modern team chat interface using unified design system
/// Optimized: Uses ChatMessageBubble, Formatters, StateViews, LazyVStack
struct TeamChatView_Refactored: View {
    @ObservedObject var catalogStore: CatalogStore
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
            if let storeId = catalogStore.selectedStore?.id {
                await chatStore.loadConversations(
                    storeId: storeId,
                    supabase: SupabaseService.shared.client
                )
            }
        }
        .onChange(of: catalogStore.selectedStore?.id) { _, newId in
            if let storeId = newId {
                Task {
                    await chatStore.loadConversations(
                        storeId: storeId,
                        supabase: SupabaseService.shared.client
                    )
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
                Menu {
                    ForEach(chatStore.conversations) { conversation in
                        Button {
                            chatStore.conversation = conversation
                            Task { await chatStore.loadMessages() }
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
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceTertiary)
    }

    // MARK: - Message Content

    @ViewBuilder
    private var messageContent: some View {
        if catalogStore.selectedStore == nil {
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
                    Task { await chatStore.loadMessages() }
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

    // MARK: - Message List (OPTIMIZED)

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Group messages by date
                    let groups = Formatters.groupMessagesByDate(chatStore.messages) { $0.createdAt }

                    ForEach(groups) { group in
                        ChatDateSeparator(date: group.date)

                        // Compute grouping once
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
                    Task { await sendMessage() }
                }

            Button {
                Task { await sendMessage() }
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

    // MARK: - Actions

    private func sendMessage() async {
        guard !chatStore.draftMessage.isEmpty,
              let conversationId = chatStore.conversation?.id else { return }

        let message = chatStore.draftMessage
        chatStore.draftMessage = ""

        await chatStore.sendMessage(
            content: message,
            conversationId: conversationId,
            supabase: SupabaseService.shared.client
        )

        shouldScrollToBottom = true
    }
}

// MARK: - Chat Store (Simplified)

@MainActor
class ChatStore: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var conversation: Conversation?
    @Published var messages: [ChatMessage] = []
    @Published var draftMessage = ""
    @Published var pendingMessageIds: Set<UUID> = []

    @Published var isLoading = false
    @Published var error: String?

    var currentUserId: UUID?

    func loadConversations(storeId: UUID, supabase: SupabaseClient) async {
        isLoading = true
        defer { isLoading = false }

        do {
            conversations = try await supabase
                .from("conversations")
                .select()
                .eq("store_id", value: storeId)
                .order("updated_at", ascending: false)
                .execute()
                .value

            // Auto-select first conversation
            if conversation == nil, let first = conversations.first {
                conversation = first
                await loadMessages()
            }
        } catch {
            self.error = "Failed to load conversations: \(error.localizedDescription)"
        }
    }

    func loadMessages() async {
        guard let conversationId = conversation?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await SupabaseService.shared.client
                .from("messages")
                .select()
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: true)
                .execute()
                .value

            error = nil
        } catch {
            self.error = "Failed to load messages: \(error.localizedDescription)"
        }
    }

    func sendMessage(content: String, conversationId: UUID, supabase: SupabaseClient) async {
        let tempId = UUID()
        let tempMessage = ChatMessage(
            id: tempId,
            conversationId: conversationId,
            role: "user",
            content: content,
            senderId: currentUserId,
            createdAt: Date()
        )

        // Optimistic update
        messages.append(tempMessage)
        pendingMessageIds.insert(tempId)

        do {
            let insert = ChatMessageInsert(
                conversationId: conversationId,
                role: "user",
                content: content,
                senderId: currentUserId
            )

            let sent: ChatMessage = try await supabase
                .from("messages")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value

            // Replace temp with real message
            if let idx = messages.firstIndex(where: { $0.id == tempId }) {
                messages[idx] = sent
            }
            pendingMessageIds.remove(tempId)
        } catch {
            // Remove failed message
            messages.removeAll { $0.id == tempId }
            pendingMessageIds.remove(tempId)
            self.error = "Failed to send message: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    TeamChatView_Refactored(catalogStore: CatalogStore())
        .frame(width: 800, height: 600)
}
