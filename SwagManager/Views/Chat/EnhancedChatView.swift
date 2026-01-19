import SwiftUI

// MARK: - Cached Formatters (Performance)

private enum EnhancedChatFormatters {
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    static let calendar = Calendar.current

    static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func formatDateHeader(_ date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return dateFormatter.string(from: date)
        }
    }
}

// MARK: - Enhanced Chat View with AI Features

struct EnhancedChatView: View {
    @ObservedObject var store: EditorStore
    @StateObject private var chatStore = EnhancedChatStore()
    @State private var showCommandPalette = false
    @State private var shouldScrollToBottom = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            // Messages
            if store.selectedStore == nil {
                noStoreView
            } else if chatStore.isLoading && chatStore.messages.isEmpty {
                loadingView
            } else if let error = chatStore.error {
                errorView(error)
            } else if chatStore.messages.isEmpty {
                welcomeView
            } else {
                messageList
            }

            // AI Typing indicator
            if chatStore.isAITyping {
                aiTypingIndicator
            }

            // Quick actions / suggestions
            if chatStore.showQuickActions && !chatStore.draftMessage.isEmpty == false {
                quickActionsBar
            }

            // Slash command suggestions
            if chatStore.showCommandSuggestions {
                commandSuggestionsView
            }

            // Mention suggestions
            if chatStore.showMentionSuggestions {
                mentionSuggestionsView
            }

            // Input area
            if chatStore.conversation != nil {
                enhancedMessageInput
            }
        }
        .background(Color(white: 0.05))
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
        HStack(spacing: 10) {
            if let conv = chatStore.conversation {
                // AI indicator for AI conversations
                ZStack {
                    Circle()
                        .fill(conv.chatType == "ai" ? Color.purple.opacity(0.2) : Color.green.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: conv.chatType == "ai" ? "sparkles" : "bubble.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(conv.chatType == "ai" ? .purple : .green)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(conv.displayTitle)
                        .font(.system(size: 13, weight: .semibold))

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Online")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Context indicator
                if let productName = store.selectedProduct?.name {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf")
                            .font(.system(size: 9))
                        Text(productName)
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
            } else {
                Text("Team Chat")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(white: 0.06))
    }

    // MARK: - Message List

    private var messageList: some View {
        SmoothChatScrollView(scrollToBottom: $shouldScrollToBottom) {
            VStack(spacing: 2) {
                ForEach(chatStore.groupedMessages, id: \.date) { group in
                    dateSeparator(group.date)

                    // Use indices for stable identity
                    ForEach(group.messages.indices, id: \.self) { index in
                        let message = group.messages[index]
                        let isFirst = index == 0 || group.messages[index - 1].senderId != message.senderId
                        let isLast = index == group.messages.count - 1 || group.messages[index + 1].senderId != message.senderId

                        EnhancedMessageBubble(
                            message: message,
                            isFromCurrentUser: message.senderId == chatStore.currentUserId,
                            showAvatar: isFirst,
                            isFirstInGroup: isFirst,
                            isLastInGroup: isLast,
                            isPending: chatStore.pendingMessageIds.contains(message.id),
                            onReply: { chatStore.replyToMessage = message },
                            onReact: { emoji in Task { await chatStore.addReaction(to: message, emoji: emoji) } }
                        )
                        .id(message.id)
                    }
                }

                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: chatStore.messages.count) { old, new in
            if new > old {
                shouldScrollToBottom = true
            }
        }
        .onAppear {
            shouldScrollToBottom = true
        }
    }

    private func dateSeparator(_ date: Date) -> some View {
        Text(EnhancedChatFormatters.formatDateHeader(date))
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(white: 0.1))
            .clipShape(Capsule())
            .padding(.vertical, 8)
    }

    // MARK: - AI Typing Indicator

    private var aiTypingIndicator: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 24, height: 24)

                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(.purple)
            }

            HStack(spacing: 3) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 6, height: 6)
                        .offset(y: chatStore.typingAnimationOffset(for: i))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Quick Actions Bar

    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AIService.quickActions) { action in
                    Button {
                        chatStore.draftMessage = action.prompt
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: action.icon)
                                .font(.system(size: 10))
                            Text(action.label)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 6)
        .background(Color(white: 0.04))
    }

    // MARK: - Command Suggestions

    private var commandSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(chatStore.filteredCommands, id: \.rawValue) { cmd in
                Button {
                    chatStore.draftMessage = cmd.rawValue + " "
                    chatStore.showCommandSuggestions = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: cmd.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(.purple)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(cmd.rawValue)
                                .font(.system(size: 12, weight: .medium))
                            Text(cmd.description)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.03))
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Mention Suggestions

    private var mentionSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // AI mention
            Button {
                chatStore.insertMention("@lisa ")
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 28, height: 28)
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(.purple)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("@lisa")
                            .font(.system(size: 12, weight: .medium))
                        Text("AI Assistant")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.03))
            }
            .buttonStyle(.plain)

            // Team members would go here
            // ForEach(chatStore.teamMembers) { ... }
        }
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Enhanced Message Input

    private var enhancedMessageInput: some View {
        VStack(spacing: 0) {
            // Reply preview
            if let replyTo = chatStore.replyToMessage {
                replyPreview(replyTo)
            }

            HStack(spacing: 8) {
                // Attachment button
                Button {
                    // TODO: Attachments
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)

                // Text input with @ and / detection
                TextField("Message or @lisa for AI", text: $chatStore.draftMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(white: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onChange(of: chatStore.draftMessage) { _, newValue in
                        chatStore.handleInputChange(newValue)
                    }
                    .onSubmit {
                        Task { await sendMessage() }
                    }

                // Send button with AI indicator
                Button {
                    Task { await sendMessage() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(sendButtonColor)
                            .frame(width: 32, height: 32)

                        Image(systemName: chatStore.willInvokeAI ? "sparkles" : "arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(chatStore.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color(white: 0.04))
    }

    private var sendButtonColor: Color {
        let isEmpty = chatStore.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isEmpty { return Color.white.opacity(0.1) }
        return chatStore.willInvokeAI ? .purple : .accentColor
    }

    private func replyPreview(_ message: ChatMessage) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(message.content)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                chatStore.replyToMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
    }

    // MARK: - States

    private var noStoreView: some View {
        VStack(spacing: 8) {
            Image(systemName: "building.2")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Select a store")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading...")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.animation(.easeOut(duration: 0.2)))
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text(error)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    if let storeId = store.selectedStore?.id {
                        await chatStore.loadConversations(storeId: storeId, supabase: store.supabase)
                    }
                }
            }
            .font(.system(size: 11))
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcomeView: some View {
        VStack(spacing: 20) {
            // AI Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundStyle(.purple)
            }

            VStack(spacing: 6) {
                Text("Hi, I'm Lisa")
                    .font(.system(size: 17, weight: .semibold))

                Text("Your AI assistant. Ask me anything about your store,\ninventory, sales, or try a command below.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Quick commands
            VStack(spacing: 8) {
                ForEach(["/sales", "/inventory", "/lowstock", "/help"], id: \.self) { cmd in
                    if let command = AIService.SlashCommand(rawValue: cmd) {
                        Button {
                            chatStore.draftMessage = cmd + " "
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: command.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.purple)
                                    .frame(width: 24)

                                Text(cmd)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))

                                Spacer()

                                Text(command.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.animation(.easeOut(duration: 0.25)))
    }

    // MARK: - Actions

    private func sendMessage() async {
        await chatStore.sendMessage(supabase: store.supabase, editorStore: store)
    }

    // MARK: - Helpers

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Enhanced Message Bubble

struct EnhancedMessageBubble: View, Equatable {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let showAvatar: Bool
    var isFirstInGroup: Bool = true
    var isLastInGroup: Bool = true
    var isPending: Bool = false
    var onReply: () -> Void = {}
    var onReact: (String) -> Void = { _ in }

    // Equatable - closures are excluded, only data matters
    static func == (lhs: EnhancedMessageBubble, rhs: EnhancedMessageBubble) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.isPending == rhs.isPending &&
        lhs.isFirstInGroup == rhs.isFirstInGroup &&
        lhs.isLastInGroup == rhs.isLastInGroup
    }

    private var isAI: Bool { message.isFromAssistant }

    private var bubbleColor: Color {
        if isAI { return Color(white: 0.12) }
        if isFromCurrentUser { return .accentColor }
        return Color(white: 0.15)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            } else {
                // Avatar
                if showAvatar && isLastInGroup {
                    avatarView
                } else {
                    Color.clear.frame(width: 28, height: 28)
                }
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                // Message content (no hover overlay for performance)
                messageContent

                // Timestamp
                if isLastInGroup, let time = message.createdAt {
                    HStack(spacing: 4) {
                        Text(formatTime(time))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)

                        if isPending {
                            ProgressView().scaleEffect(0.5)
                        } else if isFromCurrentUser {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
                }
            }

            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .padding(.vertical, isLastInGroup ? 3 : 1)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(isAI ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                .frame(width: 28, height: 28)

            if isAI {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(.purple)
            } else {
                Text("U")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.blue)
            }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if isAI && hasRichContent {
            // AI message with markdown
            MarkdownText(message.content, isFromCurrentUser: false)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(white: 0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(isPending ? 0.6 : 1)
        } else {
            // Regular message
            Text(message.content)
                .font(.system(size: 14))
                .foregroundStyle(isFromCurrentUser ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleColor)
                .clipShape(bubbleShape)
                .opacity(isPending ? 0.6 : 1)
        }
    }

    private var hasRichContent: Bool {
        let c = message.content
        return c.contains("```") || c.contains("|---") || c.contains("| ---")
    }

    private var bubbleShape: some Shape {
        RoundedCornerShape(
            topLeft: isFromCurrentUser ? 16 : (isFirstInGroup ? 16 : 4),
            topRight: isFromCurrentUser ? (isFirstInGroup ? 16 : 4) : 16,
            bottomLeft: isFromCurrentUser ? 16 : (isLastInGroup ? 16 : 4),
            bottomRight: isFromCurrentUser ? (isLastInGroup ? 16 : 4) : 16
        )
    }

    private func formatTime(_ date: Date) -> String {
        EnhancedChatFormatters.formatTime(date)
    }
}

// MARK: - Enhanced Chat Store

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

    // Context for AI
    var context = AIService.AIContext(
        storeId: nil, storeName: nil,
        catalogId: nil, catalogName: nil,
        locationId: nil, locationName: nil,
        selectedProductId: nil, selectedProductName: nil,
        selectedCategoryId: nil, selectedCategoryName: nil,
        conversationHistory: [],
        slashCommand: nil, commandArgs: nil
    )

    // Animation state
    @Published private var typingPhase: CGFloat = 0
    private var typingTimer: Timer?

    struct MessageGroup: Identifiable {
        let id = UUID()
        let date: Date
        var messages: [ChatMessage]
    }

    var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        var groups: [MessageGroup] = []

        for message in messages {
            guard let createdAt = message.createdAt else { continue }
            let dayStart = calendar.startOfDay(for: createdAt)

            if let lastGroup = groups.last, calendar.isDate(lastGroup.date, inSameDayAs: dayStart) {
                groups[groups.count - 1].messages.append(message)
            } else {
                groups.append(MessageGroup(date: dayStart, messages: [message]))
            }
        }

        return groups
    }

    var willInvokeAI: Bool {
        draftMessage.shouldInvokeAI
    }

    func typingAnimationOffset(for index: Int) -> CGFloat {
        let phase = typingPhase + CGFloat(index) * 0.3
        return sin(phase * .pi * 2) * 3
    }

    // MARK: - Input Handling

    func handleInputChange(_ text: String) {
        // Detect slash commands
        if text.hasPrefix("/") {
            let query = text.lowercased()
            filteredCommands = AIService.SlashCommand.allCases.filter {
                $0.rawValue.hasPrefix(query) || query == "/"
            }
            showCommandSuggestions = !filteredCommands.isEmpty
            showMentionSuggestions = false
        }
        // Detect @ mentions
        else if text.hasSuffix("@") || (text.contains("@") && !text.contains(" ", after: "@")) {
            showMentionSuggestions = true
            showCommandSuggestions = false
        }
        else {
            showCommandSuggestions = false
            showMentionSuggestions = false
        }

        showQuickActions = text.isEmpty
    }

    func insertMention(_ mention: String) {
        // Replace the @ with the full mention
        if let atIndex = draftMessage.lastIndex(of: "@") {
            draftMessage = String(draftMessage[..<atIndex]) + mention
        } else {
            draftMessage += mention
        }
        showMentionSuggestions = false
    }

    // MARK: - Context

    func updateContext(from store: EditorStore) {
        context = AIService.AIContext(
            storeId: store.selectedStore?.id,
            storeName: store.selectedStore?.storeName,
            catalogId: store.selectedCatalog?.id,
            catalogName: store.selectedCatalog?.name,
            locationId: nil,
            locationName: nil,
            selectedProductId: store.selectedProduct?.id,
            selectedProductName: store.selectedProduct?.name,
            selectedCategoryId: store.selectedCategory?.id,
            selectedCategoryName: store.selectedCategory?.name,
            conversationHistory: messages,
            slashCommand: nil,
            commandArgs: nil
        )
    }

    // MARK: - Load Data

    func loadConversations(storeId: UUID, supabase: SupabaseService) async {
        isLoading = true
        error = nil

        do {
            let user = try await supabase.client.auth.user()
            currentUserId = user.id

            conversations = try await supabase.fetchAllConversationsForStoreLocations(storeId: storeId)

            // Find or create AI conversation
            if let aiConv = conversations.first(where: { $0.chatType == "ai" }) {
                await selectConversation(aiConv, supabase: supabase)
            } else if let first = conversations.first {
                await selectConversation(first, supabase: supabase)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func selectConversation(_ conv: Conversation, supabase: SupabaseService) async {
        conversation = conv
        messages = []

        do {
            messages = try await supabase.fetchMessages(conversationId: conv.id, limit: 100)
        } catch {
            NSLog("[EnhancedChatStore] Error loading messages: \(error)")
        }
    }

    // MARK: - Send Message

    func sendMessage(supabase: SupabaseService, editorStore: EditorStore) async {
        let content = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, let convId = conversation?.id, let userId = currentUserId else { return }

        let parsed = AIService.shared.parseMessage(content)
        draftMessage = ""
        showCommandSuggestions = false
        showMentionSuggestions = false

        // Create optimistic message
        let optimisticId = UUID()
        let optimisticMessage = ChatMessage(
            id: optimisticId,
            conversationId: convId,
            role: "user",
            content: content,
            toolCalls: nil,
            tokensUsed: nil,
            senderId: userId,
            isAiInvocation: parsed.hasAIMention,
            aiPrompt: nil,
            replyToMessageId: replyToMessage?.id,
            createdAt: Date()
        )

        pendingMessageIds.insert(optimisticId)
        replyToMessage = nil

        await MainActor.run {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                messages.append(optimisticMessage)
            }
        }

        // Send to server
        let insert = ChatMessageInsert(
            conversationId: convId,
            role: "user",
            content: content,
            senderId: userId,
            isAiInvocation: parsed.hasAIMention,
            replyToMessageId: optimisticMessage.replyToMessageId
        )

        do {
            let newMessage = try await supabase.sendMessage(insert)

            await MainActor.run {
                if let idx = messages.firstIndex(where: { $0.id == optimisticId }) {
                    messages[idx] = newMessage
                    pendingMessageIds.remove(optimisticId)
                }
            }

            // If AI was mentioned, get response
            if parsed.hasAIMention {
                await getAIResponse(
                    for: parsed,
                    conversationId: convId,
                    supabase: supabase,
                    editorStore: editorStore
                )
            }
        } catch {
            await MainActor.run {
                messages.removeAll { $0.id == optimisticId }
                pendingMessageIds.remove(optimisticId)
                draftMessage = content
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - AI Response

    private func getAIResponse(
        for parsed: AIService.ParsedMessage,
        conversationId: UUID,
        supabase: SupabaseService,
        editorStore: EditorStore
    ) async {
        await MainActor.run {
            isAITyping = true
            startTypingAnimation()
        }

        // Build context with command info
        let aiContext = AIService.AIContext(
            storeId: editorStore.selectedStore?.id,
            storeName: editorStore.selectedStore?.storeName,
            catalogId: editorStore.selectedCatalog?.id,
            catalogName: editorStore.selectedCatalog?.name,
            locationId: nil,
            locationName: nil,
            selectedProductId: editorStore.selectedProduct?.id,
            selectedProductName: editorStore.selectedProduct?.name,
            selectedCategoryId: editorStore.selectedCategory?.id,
            selectedCategoryName: editorStore.selectedCategory?.name,
            conversationHistory: messages,
            slashCommand: parsed.slashCommand,
            commandArgs: parsed.commandArgs
        )

        do {
            let response = try await AIService.shared.invokeAI(
                message: parsed.cleanContent,
                context: aiContext,
                supabase: supabase
            )

            // Insert AI response
            let aiMessageInsert = ChatMessageInsert(
                conversationId: conversationId,
                role: "assistant",
                content: response,
                senderId: nil,
                isAiInvocation: false,
                replyToMessageId: nil
            )

            let aiMessage = try await supabase.sendMessage(aiMessageInsert)

            await MainActor.run {
                isAITyping = false
                stopTypingAnimation()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    messages.append(aiMessage)
                }
            }
        } catch {
            await MainActor.run {
                isAITyping = false
                stopTypingAnimation()
                self.error = "AI error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Reactions

    func addReaction(to message: ChatMessage, emoji: String) async {
        // TODO: Implement reaction storage
        NSLog("Adding reaction \(emoji) to message \(message.id)")
    }

    // MARK: - Typing Animation

    private func startTypingAnimation() {
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.typingPhase += 0.15
            }
        }
    }

    private func stopTypingAnimation() {
        typingTimer?.invalidate()
        typingTimer = nil
        typingPhase = 0
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - String Extension

private extension String {
    func contains(_ char: Character, after searchChar: Character) -> Bool {
        guard let searchIndex = lastIndex(of: searchChar) else { return false }
        let afterSearch = self[index(after: searchIndex)...]
        return afterSearch.contains(char)
    }
}
