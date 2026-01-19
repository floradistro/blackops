import SwiftUI

// MARK: - Enhanced Chat View (REFACTORED - AI-Powered)

/// AI-enhanced chat with commands, mentions, and quick actions
/// Uses unified components, eliminates 624 lines of duplicate code
struct EnhancedChatView: View {
    @ObservedObject var store: EditorStore
    @StateObject private var chatStore = EnhancedChatStore()
    @State private var showCommandPalette = false
    @State private var shouldScrollToBottom = false
    @FocusState private var isInputFocused: Bool

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

    private var welcomeView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DesignSystem.Colors.purple)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("AI Assistant Ready")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Ask me anything about your products, inventory, or store operations")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                quickActionButton(icon: "magnifyingglass", text: "Search products")
                quickActionButton(icon: "chart.bar", text: "View analytics")
                quickActionButton(icon: "square.and.pencil", text: "Create report")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }

    private func quickActionButton(icon: String, text: String) -> some View {
        Button {
            chatStore.draftMessage = text
            isInputFocused = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.IconSize.medium))
                Text(text)
                    .font(DesignSystem.Typography.body)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: DesignSystem.IconSize.small))
            }
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Message List (OPTIMIZED with LazyVStack)

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    let groups = Formatters.groupMessagesByDate(chatStore.messages) { $0.createdAt }

                    ForEach(groups) { group in
                        ChatDateSeparator(date: group.date)

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
                                    style: .enhanced
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

    // MARK: - Quick Actions Bar

    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                quickAction("Search", icon: "magnifyingglass", action: "/search")
                quickAction("Analyze", icon: "chart.bar", action: "/analyze")
                quickAction("Report", icon: "doc.text", action: "/report")
                quickAction("Help", icon: "questionmark.circle", action: "/help")
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.surfaceTertiary)
    }

    private func quickAction(_ label: String, icon: String, action: String) -> some View {
        Button {
            chatStore.draftMessage = action + " "
            isInputFocused = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.IconSize.small))
                Text(label)
                    .font(DesignSystem.Typography.caption1)
            }
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(DesignSystem.Colors.surfaceElevated)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Command Suggestions

    private var commandSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(chatStore.filteredCommands.prefix(5), id: \.command) { cmd in
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

    private var mentionSuggestionsView: some View {
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

    // MARK: - Enhanced Message Input

    private var enhancedMessageInput: some View {
        VStack(spacing: 0) {
            if let replyTo = chatStore.replyToMessage {
                replyPreview(replyTo)
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                TextField("Message AI assistant...", text: $chatStore.draftMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                    .lineLimit(1...6)
                    .focused($isInputFocused)
                    .onSubmit {
                        Task { await chatStore.sendMessage(supabase: store.supabase) }
                    }
                    .onChange(of: chatStore.draftMessage) { _, newValue in
                        chatStore.updateSuggestions(newValue)
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
        }
        .background(DesignSystem.Colors.surfaceTertiary)
    }

    private func replyPreview(_ message: ChatMessage) -> some View {
        HStack {
            Rectangle()
                .fill(DesignSystem.Colors.accent)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Text(message.content)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                chatStore.replyToMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: DesignSystem.IconSize.small))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.surfaceElevated)
    }
}

// MARK: - Enhanced Chat Store (KEPT - AI-Specific Logic)

@MainActor
class EnhancedChatStore: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var conversation: Conversation?
    @Published var messages: [ChatMessage] = []
    @Published var draftMessage = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var pendingMessageIds: Set<UUID> = []

    @Published var isAITyping = false
    @Published var showQuickActions = true
    @Published var showCommandSuggestions = false
    @Published var showMentionSuggestions = false
    @Published var replyToMessage: ChatMessage?

    @Published var filteredCommands: [AIService.SlashCommand] = []

    var currentUserId: UUID?
    private var allCommands: [AIService.SlashCommand] = [
        AIService.SlashCommand(command: "/search", description: "Search products"),
        AIService.SlashCommand(command: "/analyze", description: "Analyze data"),
        AIService.SlashCommand(command: "/report", description: "Generate report"),
        AIService.SlashCommand(command: "/help", description: "Show help")
    ]

    // Context from EditorStore
    var contextProductId: UUID?
    var contextProductName: String?
    var contextCategoryId: UUID?
    var contextCategoryName: String?

    func updateContext(from store: EditorStore) {
        contextProductId = store.selectedProduct?.id
        contextProductName = store.selectedProduct?.name
        contextCategoryId = store.selectedCategory?.id
        contextCategoryName = store.selectedCategory?.name
    }

    func updateSuggestions(_ text: String) {
        if text.starts(with: "/") {
            showCommandSuggestions = true
            filteredCommands = allCommands.filter { $0.command.starts(with: text) }
        } else {
            showCommandSuggestions = false
        }

        showMentionSuggestions = text.contains("@")
    }

    func selectCommand(_ command: AIService.SlashCommand) {
        draftMessage = command.command + " "
        showCommandSuggestions = false
    }

    func insertMention(_ mention: String) {
        draftMessage += "@\(mention) "
        showMentionSuggestions = false
    }

    func loadConversations(storeId: UUID, supabase: SupabaseService) async {
        isLoading = true
        error = nil

        do {
            let user = try await supabase.client.auth.user()
            currentUserId = user.id

            conversations = try await supabase.fetchAllConversationsForStoreLocations(storeId: storeId)

            if let first = conversations.first {
                conversation = first
                messages = try await supabase.fetchMessages(conversationId: first.id, limit: 100)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func sendMessage(supabase: SupabaseService) async {
        guard !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let conversationId = conversation?.id,
              let userId = currentUserId else { return }

        let content = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        draftMessage = ""

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
            replyToMessageId: replyToMessage?.id,
            createdAt: Date()
        )

        pendingMessageIds.insert(optimisticId)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            messages.append(optimisticMessage)
        }

        replyToMessage = nil

        let insert = ChatMessageInsert(
            conversationId: conversationId,
            role: "user",
            content: content,
            senderId: userId,
            isAiInvocation: false,
            replyToMessageId: replyToMessage?.id
        )

        do {
            let newMessage = try await supabase.sendMessage(insert)
            if let index = messages.firstIndex(where: { $0.id == optimisticId }) {
                withAnimation(.easeOut(duration: 0.15)) {
                    messages[index] = newMessage
                    pendingMessageIds.remove(optimisticId)
                }
            }
        } catch {
            self.error = error.localizedDescription
            withAnimation {
                messages.removeAll { $0.id == optimisticId }
                pendingMessageIds.remove(optimisticId)
            }
            draftMessage = content
        }
    }
}

// MARK: - Preview

#Preview {
    EnhancedChatView(store: EditorStore())
        .frame(width: 800, height: 600)
}
