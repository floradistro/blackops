import SwiftUI
import Supabase

// MARK: - Cached Formatters (Performance Optimization)

private enum ChatFormatters {
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
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
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return f.string(from: date)
        } else {
            return dateFormatter.string(from: date)
        }
    }
}

// MARK: - Team Chat View (iMessage Style)

struct TeamChatView: View {
    @ObservedObject var store: EditorStore
    @StateObject private var chatStore = ChatStore()
    @State private var shouldScrollToBottom = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with conversation picker
            chatHeader

            // Messages
            if store.selectedStore == nil {
                noStoreView
            } else if chatStore.isLoading && chatStore.messages.isEmpty {
                loadingView
            } else if let error = chatStore.error {
                errorView(error)
            } else if chatStore.conversations.isEmpty {
                noConversationsView
            } else if chatStore.messages.isEmpty {
                emptyStateView
            } else {
                messageList
            }

            // Input (only show when conversation is selected)
            if chatStore.conversation != nil {
                messageInput
            }
        }
        .background(Color(white: 0.05))
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
    }

    private var noStoreView: some View {
        VStack(spacing: 8) {
            Image(systemName: "building.2")
                .font(.system(size: 24))
                .foregroundStyle(Color.white.opacity(0.15))
            Text("Select a store")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noConversationsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 24))
                .foregroundStyle(Color.white.opacity(0.15))
            Text("No conversations")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(.orange.opacity(0.6))
            Text("Error loading chat")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(error)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Button("Retry") {
                Task {
                    if let storeId = store.selectedStore?.id {
                        await chatStore.loadConversation(storeId: storeId, supabase: store.supabase)
                    }
                }
            }
            .font(.system(size: 10))
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header (Minimal)

    private var chatHeader: some View {
        HStack(spacing: 8) {
            if let conv = chatStore.conversation {
                // Compact status + title
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)

                Text(conv.displayTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text("•")
                    .font(.system(size: 8))
                    .foregroundStyle(.quaternary)

                Text(conv.chatTypeLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Spacer()

                if let count = conv.messageCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.quaternary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.04))
    }

    // MARK: - Message List

    private var messageList: some View {
        SmoothChatScrollView(scrollToBottom: $shouldScrollToBottom) {
            VStack(spacing: 1) {
                ForEach(chatStore.groupedMessages, id: \.date) { group in
                    // Date separator
                    dateSeparator(group.date)

                    // Use indices for stable identity
                    ForEach(group.messages.indices, id: \.self) { index in
                        let message = group.messages[index]
                        let isFirstInGroup = index == 0 || group.messages[index - 1].senderId != message.senderId
                        let isLastInGroup = index == group.messages.count - 1 || group.messages[index + 1].senderId != message.senderId

                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.senderId == chatStore.currentUserId,
                            showAvatar: shouldShowAvatar(for: message, in: group.messages),
                            isFirstInGroup: isFirstInGroup,
                            isLastInGroup: isLastInGroup,
                            isPending: chatStore.pendingMessageIds.contains(message.id),
                            avatarColor: MessageBubble.computeAvatarColor(for: message),
                            hasRichContent: MessageBubble.checkHasRichContent(message.content)
                        )
                        .id(message.id)
                    }
                }

                // Spacer at bottom
                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: chatStore.messages.count) { oldCount, newCount in
            if newCount > oldCount {
                shouldScrollToBottom = true
            }
        }
        .onAppear {
            shouldScrollToBottom = true
        }
    }

    private func dateSeparator(_ date: Date) -> some View {
        Text(formatDateHeader(date))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.45))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.12).opacity(0.8))
            .clipShape(Capsule())
            .padding(.vertical, 12)
    }

    private func shouldShowAvatar(for message: ChatMessage, in messages: [ChatMessage]) -> Bool {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return true }
        if index == 0 { return true }
        let previousMessage = messages[index - 1]
        return previousMessage.senderId != message.senderId
    }

    // MARK: - Message Input

    private var messageInput: some View {
        HStack(spacing: 8) {
            // Text field
            TextField("iMessage", text: $chatStore.draftMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(white: 0.12))
                .clipShape(Capsule())
                .lineLimit(1...5)
                .onSubmit {
                    sendMessageWithAnimation()
                }

            // Send button with animation
            Button {
                sendMessageWithAnimation()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(chatStore.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.15) : Color.accentColor)
                    .scaleEffect(chatStore.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: chatStore.draftMessage.isEmpty)
            }
            .buttonStyle(SendButtonStyle())
            .disabled(chatStore.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color(white: 0.05)
                .shadow(color: .black.opacity(0.2), radius: 8, y: -2)
        )
    }

    private func sendMessageWithAnimation() {
        guard !chatStore.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task { await chatStore.sendMessage(supabase: store.supabase) }
    }

    // MARK: - Empty & Loading States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading messages...")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.animation(.easeOut(duration: 0.2)))
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(Color.white.opacity(0.15))

            VStack(spacing: 4) {
                Text("No messages yet")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Start a conversation with your team")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.animation(.easeOut(duration: 0.25)))
    }

    // MARK: - Helpers

    private func formatDateHeader(_ date: Date) -> String {
        ChatFormatters.formatDateHeader(date)
    }
}

// MARK: - Send Button Style

struct SendButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View, Equatable {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let showAvatar: Bool
    var isFirstInGroup: Bool = true
    var isLastInGroup: Bool = true
    var isPending: Bool = false

    // Pre-computed values passed in to avoid recalculation
    let avatarColor: Color
    let hasRichContent: Bool

    // Equatable - only re-render if these change
    static func == (lhs: MessageBubble, rhs: MessageBubble) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.isPending == rhs.isPending &&
        lhs.isFirstInGroup == rhs.isFirstInGroup &&
        lhs.isLastInGroup == rhs.isLastInGroup
    }

    // Static helper to compute avatar color once
    static func computeAvatarColor(for message: ChatMessage) -> Color {
        if message.isFromAssistant {
            return Color(white: 0.4)
        }
        let hash = message.senderId?.hashValue ?? 0
        let colors: [Color] = [.blue, .green, .orange, .teal, .indigo, .cyan]
        return colors[abs(hash) % colors.count]
    }

    // Static helper to check rich content once
    static func checkHasRichContent(_ content: String) -> Bool {
        content.contains("```") ||
        content.contains("|---") ||
        content.contains("| ---") ||
        content.contains("|:--")
    }

    private var initials: String {
        message.isFromAssistant ? "L" : "U"
    }

    // iMessage-style corner radii
    private var bubbleCorners: RoundedCornerShape {
        let large: CGFloat = 18
        let small: CGFloat = 4

        if isFromCurrentUser {
            return RoundedCornerShape(
                topLeft: large,
                topRight: isFirstInGroup ? large : small,
                bottomLeft: large,
                bottomRight: isLastInGroup ? large : small
            )
        } else {
            return RoundedCornerShape(
                topLeft: isFirstInGroup ? large : small,
                topRight: large,
                bottomLeft: isLastInGroup ? large : small,
                bottomRight: large
            )
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            } else {
                // Avatar - only show on last message in group
                if showAvatar && isLastInGroup {
                    Circle()
                        .fill(avatarColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(initials)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(avatarColor)
                        )
                } else {
                    Color.clear.frame(width: 28, height: 28)
                }
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                // Message content - rich markdown for AI, plain bubbles for user
                if message.isFromAssistant && hasRichContent {
                    // AI message with code/tables - card style with subtle background
                    MarkdownText(message.content, isFromCurrentUser: false)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(isPending ? 0.6 : 1.0)
                } else if message.isFromAssistant {
                    // Simple AI message - subtle bubble
                    MarkdownText(message.content, isFromCurrentUser: false)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.12))
                        .clipShape(bubbleCorners)
                        .opacity(isPending ? 0.6 : 1.0)
                } else {
                    // User message - colored bubble (no gradient for performance)
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .clipShape(bubbleCorners)
                        .opacity(isPending ? 0.6 : 1.0)
                }

                // Timestamp - only show on last message in group or after time gap
                if isLastInGroup, let createdAt = message.createdAt {
                    HStack(spacing: 4) {
                        Text(formatTime(createdAt))
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.4))

                        if isPending {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else if isFromCurrentUser {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                    .padding(.top, 2)
                    .padding(.horizontal, 4)
                }
            }

            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, isLastInGroup ? 4 : 1)
    }

    private func formatTime(_ date: Date) -> String {
        ChatFormatters.formatTime(date)
    }
}

// MARK: - Rounded Corner Shape (iMessage style)

struct RoundedCornerShape: Shape {
    var topLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var bottomRight: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.size.width
        let h = rect.size.height

        let tr = min(min(topRight, h/2), w/2)
        let tl = min(min(topLeft, h/2), w/2)
        let bl = min(min(bottomLeft, h/2), w/2)
        let br = min(min(bottomRight, h/2), w/2)

        path.move(to: CGPoint(x: tl, y: 0))
        path.addLine(to: CGPoint(x: w - tr, y: 0))
        path.addArc(center: CGPoint(x: w - tr, y: tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addArc(center: CGPoint(x: w - br, y: h - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: bl, y: h))
        path.addArc(center: CGPoint(x: bl, y: h - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: tl))
        path.addArc(center: CGPoint(x: tl, y: tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()

        return path
    }
}

// MARK: - Typing Indicator (iMessage style)

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            // Avatar placeholder
            Circle()
                .fill(Color(white: 0.2))
                .frame(width: 28, height: 28)

            // Typing bubble
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.0 : 0.6)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(white: 0.15))
            .clipShape(RoundedCornerShape(topLeft: 18, topRight: 18, bottomLeft: 4, bottomRight: 18))

            Spacer()
        }
        .padding(.vertical, 4)
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

// MARK: - Streaming Message Bubble (AI response being generated)

struct StreamingMessageBubble: View {
    let content: String
    let currentTool: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                // Tool indicator (if running) - subtle, inline
                if let tool = currentTool {
                    HStack(spacing: 5) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                        Text(tool)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                // Streaming text bubble - same style as regular messages
                Text(content)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(white: 0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Spacer(minLength: 50)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Typing Indicator Bubble (AI thinking, no text yet)

struct TypingIndicatorBubble: View {
    let currentTool: String?
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                // Tool indicator - subtle
                if let tool = currentTool {
                    HStack(spacing: 5) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                        Text(tool)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                // Typing dots - clean, minimal
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 6, height: 6)
                            .scaleEffect(animating ? 1.0 : 0.5)
                            .animation(
                                .easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                                value: animating
                            )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(white: 0.18))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Spacer(minLength: 50)
        }
        .padding(.vertical, 1)
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

// MARK: - Chat Store

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

    func loadConversations(storeId: UUID, supabase: SupabaseService) async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let user = try await supabase.client.auth.user()
            currentUserId = user.id
            NSLog("[ChatStore] Current user: \(user.id)")

            // Fetch ALL conversations for this store AND its locations
            conversations = try await supabase.fetchAllConversationsForStoreLocations(storeId: storeId)
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

// MARK: - Chat Tab View (Full-size AI-enhanced conversation view)

struct ChatTabView: View {
    let conversation: Conversation
    @ObservedObject var store: EditorStore
    @StateObject private var chatStore = AIChatStore()
    @State private var shouldScrollToBottom = false

    var body: some View {
        VStack(spacing: 0) {
            // Context bar (minimal - only shows when product selected)
            if store.selectedProduct != nil {
                chatContextBar
            }

            // Messages
            if chatStore.isLoading && chatStore.messages.isEmpty {
                loadingView
            } else if let error = chatStore.error {
                errorView(error)
            } else if chatStore.messages.isEmpty {
                welcomeView
            } else {
                messageList
            }

            // Input
            enhancedMessageInput
        }
        .background(Color(white: 0.05))
        .task {
            await chatStore.loadConversationMessages(conversation, supabase: store.supabase)
            chatStore.updateContext(from: store)
        }
        .onChange(of: conversation.id) { _, _ in
            Task {
                await chatStore.loadConversationMessages(conversation, supabase: store.supabase)
            }
        }
        .onChange(of: store.selectedProduct?.id) { _, _ in
            chatStore.updateContext(from: store)
        }
    }

    // MARK: - Context Bar (Minimal - VSCode/Cursor style)

    private var chatContextBar: some View {
        HStack(spacing: 8) {
            // Context indicator
            if let product = store.selectedProduct {
                HStack(spacing: 5) {
                    Image(systemName: "leaf")
                        .font(.system(size: 9))
                        .foregroundStyle(.green)
                    Text("Context:")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(product.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Message count (subtle)
            if let count = conversation.messageCount, count > 0 {
                Text("\(count) messages")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.3))
            }

            // Refresh button
            Button {
                Task { await chatStore.loadConversationMessages(conversation, supabase: store.supabase) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
            .buttonStyle(.plain)
            .help("Refresh messages")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(white: 0.03))
    }

    // MARK: - Message List

    private var messageList: some View {
        SmoothChatScrollView(scrollToBottom: $shouldScrollToBottom) {
            VStack(spacing: 2) {
                ForEach(chatStore.groupedMessages, id: \.date) { group in
                    dateSeparator(group.date)
                    messagesInGroup(group)
                }

                // Streaming AI response
                streamingContent

                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: chatStore.messages.count) { old, new in
            if new > old {
                shouldScrollToBottom = true
            }
        }
        .onChange(of: chatStore.streamingResponse) { _, _ in
            shouldScrollToBottom = true
        }
        .onAppear {
            shouldScrollToBottom = true
        }
    }

    private func dateSeparator(_ date: Date) -> some View {
        Text(formatDateHeader(date))
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(white: 0.1))
            .clipShape(Capsule())
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private func messagesInGroup(_ group: AIChatStore.MessageGroup) -> some View {
        ForEach(group.messages.indices, id: \.self) { index in
            let message = group.messages[index]
            let isFirst = index == 0 || group.messages[index - 1].senderId != message.senderId
            let isLast = index == group.messages.count - 1 || group.messages[index + 1].senderId != message.senderId

            MessageBubble(
                message: message,
                isFromCurrentUser: message.senderId == chatStore.currentUserId,
                showAvatar: isFirst,
                isFirstInGroup: isFirst,
                isLastInGroup: isLast,
                isPending: chatStore.pendingMessageIds.contains(message.id),
                avatarColor: MessageBubble.computeAvatarColor(for: message),
                hasRichContent: MessageBubble.checkHasRichContent(message.content)
            )
            .id(message.id)
        }
    }

    @ViewBuilder
    private var streamingContent: some View {
        if chatStore.isStreaming && !chatStore.streamingResponse.isEmpty {
            StreamingMessageBubble(
                content: chatStore.streamingResponse,
                currentTool: chatStore.currentTool
            )
        } else if chatStore.isAITyping && chatStore.streamingResponse.isEmpty {
            TypingIndicatorBubble(currentTool: chatStore.currentTool)
        }
    }

    // MARK: - Quick Actions

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
                        .background(Color.white.opacity(0.05))
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
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(cmd.rawValue)
                                .font(.system(size: 11, weight: .medium))
                            Text(cmd.description)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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
            Button {
                chatStore.insertMention("@lisa ")
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 26, height: 26)
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("@lisa")
                            .font(.system(size: 11, weight: .medium))
                        Text("AI Assistant")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Enhanced Input

    private var enhancedMessageInput: some View {
        HStack(spacing: 8) {
            // Text input
            TextField("Message @lisa for AI help...", text: $chatStore.draftMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...5)
                .onChange(of: chatStore.draftMessage) { _, newValue in
                    chatStore.handleInputChange(newValue)
                }
                .onSubmit {
                    Task { await sendMessage() }
                }

            // Send button (purple when AI will be invoked)
            Button {
                Task { await sendMessage() }
            } label: {
                ZStack {
                    Circle()
                        .fill(sendButtonColor)
                        .frame(width: 32, height: 32)

                    Image(systemName: chatStore.willInvokeAI ? "sparkles" : "arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(SendButtonStyle())
            .disabled(chatStore.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(white: 0.04))
    }

    private var sendButtonColor: Color {
        let isEmpty = chatStore.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isEmpty { return Color.white.opacity(0.1) }
        return .accentColor
    }

    private func sendMessage() async {
        await chatStore.sendMessage(supabase: store.supabase, editorStore: store, conversationId: conversation.id)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.9)
            Text("Loading...")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.animation(.easeOut(duration: 0.2)))
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text(error)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await chatStore.loadConversationMessages(conversation, supabase: store.supabase) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .transition(.opacity.animation(.easeOut(duration: 0.2)))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcomeView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)

                Image(systemName: "sparkles")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 6) {
                Text("Hi, I'm Lisa")
                    .font(.system(size: 16, weight: .semibold))

                Text("Your AI assistant. Ask me about your store,\ninventory, sales, or try a slash command.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 6) {
                ForEach(["/sales", "/inventory", "/lowstock", "/help"], id: \.self) { cmd in
                    if let command = AIService.SlashCommand(rawValue: cmd) {
                        Button {
                            chatStore.draftMessage = cmd + " "
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: command.icon)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(cmd)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                Spacer()
                                Text(command.description)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatDateHeader(_ date: Date) -> String {
        ChatFormatters.formatDateHeader(date)
    }
}

// MARK: - AI Chat Store

@MainActor
class AIChatStore: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draftMessage = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var pendingMessageIds: Set<UUID> = []

    @Published var isAITyping = false
    @Published var showQuickActions = true
    @Published var showCommandSuggestions = false
    @Published var showMentionSuggestions = false
    @Published var filteredCommands: [AIService.SlashCommand] = []

    // Streaming state
    @Published var streamingResponse = ""
    @Published var currentTool: String?
    @Published var isStreaming = false

    var currentUserId: UUID?
    private var typingPhase: CGFloat = 0
    private var typingTimer: Timer?

    // Context for AI
    var storeId: UUID?
    var storeName: String?
    var catalogId: UUID?
    var catalogName: String?
    var selectedProductId: UUID?
    var selectedProductName: String?
    var selectedCategoryId: UUID?
    var selectedCategoryName: String?

    struct MessageGroup { let date: Date; var messages: [ChatMessage] }

    var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        var groups: [MessageGroup] = []
        for msg in messages {
            guard let date = msg.createdAt else { continue }
            let day = calendar.startOfDay(for: date)
            if let last = groups.last, calendar.isDate(last.date, inSameDayAs: day) {
                groups[groups.count - 1].messages.append(msg)
            } else {
                groups.append(MessageGroup(date: day, messages: [msg]))
            }
        }
        return groups
    }

    var willInvokeAI: Bool { draftMessage.shouldInvokeAI }

    func typingOffset(for i: Int) -> CGFloat {
        sin((typingPhase + CGFloat(i) * 0.3) * .pi * 2) * 3
    }

    func handleInputChange(_ text: String) {
        if text.hasPrefix("/") {
            filteredCommands = AIService.SlashCommand.allCases.filter { $0.rawValue.hasPrefix(text.lowercased()) || text == "/" }
            showCommandSuggestions = !filteredCommands.isEmpty
            showMentionSuggestions = false
        } else if text.hasSuffix("@") {
            showMentionSuggestions = true
            showCommandSuggestions = false
        } else {
            showCommandSuggestions = false
            showMentionSuggestions = false
        }
        showQuickActions = text.isEmpty
    }

    func insertMention(_ mention: String) {
        if let idx = draftMessage.lastIndex(of: "@") {
            draftMessage = String(draftMessage[..<idx]) + mention
        } else {
            draftMessage += mention
        }
        showMentionSuggestions = false
    }

    func updateContext(from store: EditorStore) {
        storeId = store.selectedStore?.id
        storeName = store.selectedStore?.storeName
        catalogId = store.selectedCatalog?.id
        catalogName = store.selectedCatalog?.name
        selectedProductId = store.selectedProduct?.id
        selectedProductName = store.selectedProduct?.name
        selectedCategoryId = store.selectedCategory?.id
        selectedCategoryName = store.selectedCategory?.name
    }

    func loadConversationMessages(_ conv: Conversation, supabase: SupabaseService) async {
        isLoading = true
        error = nil

        do {
            let user = try await supabase.client.auth.user()
            currentUserId = user.id
            messages = try await supabase.fetchMessages(conversationId: conv.id, limit: 100)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func sendMessage(supabase: SupabaseService, editorStore: EditorStore, conversationId: UUID) async {
        let content = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, let userId = currentUserId else { return }

        let parsed = AIService.shared.parseMessage(content)
        draftMessage = ""
        showCommandSuggestions = false
        showMentionSuggestions = false

        let optimisticId = UUID()
        let optimistic = ChatMessage(
            id: optimisticId, conversationId: conversationId, role: "user", content: content,
            toolCalls: nil, tokensUsed: nil, senderId: userId, isAiInvocation: parsed.hasAIMention,
            aiPrompt: nil, replyToMessageId: nil, createdAt: Date()
        )

        pendingMessageIds.insert(optimisticId)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            messages.append(optimistic)
        }

        let insert = ChatMessageInsert(
            conversationId: conversationId, role: "user", content: content,
            senderId: userId, isAiInvocation: parsed.hasAIMention, replyToMessageId: nil
        )

        do {
            let newMsg = try await supabase.sendMessage(insert)
            if let idx = messages.firstIndex(where: { $0.id == optimisticId }) {
                messages[idx] = newMsg
                pendingMessageIds.remove(optimisticId)
            }

            if parsed.hasAIMention {
                await getAIResponse(for: parsed, conversationId: conversationId, supabase: supabase, editorStore: editorStore)
            }
        } catch {
            messages.removeAll { $0.id == optimisticId }
            pendingMessageIds.remove(optimisticId)
            draftMessage = content
            self.error = error.localizedDescription
        }
    }

    private func getAIResponse(for parsed: AIService.ParsedMessage, conversationId: UUID, supabase: SupabaseService, editorStore: EditorStore) async {
        // Capture context on MainActor before async work
        isAITyping = true
        isStreaming = true
        streamingResponse = ""
        currentTool = nil
        startTypingAnimation()

        // Capture values from MainActor-isolated editorStore
        let capturedStoreId = editorStore.selectedStore?.id
        let capturedStoreName = editorStore.selectedStore?.storeName
        let capturedCatalogId = editorStore.selectedCatalog?.id
        let capturedCatalogName = editorStore.selectedCatalog?.name
        let capturedProductId = editorStore.selectedProduct?.id
        let capturedProductName = editorStore.selectedProduct?.name
        let capturedCategoryId = editorStore.selectedCategory?.id
        let capturedCategoryName = editorStore.selectedCategory?.name
        let capturedMessages = messages

        let aiContext = AIService.AIContext(
            storeId: capturedStoreId,
            storeName: capturedStoreName,
            catalogId: capturedCatalogId,
            catalogName: capturedCatalogName,
            locationId: nil as UUID?,
            locationName: nil as String?,
            selectedProductId: capturedProductId,
            selectedProductName: capturedProductName,
            selectedCategoryId: capturedCategoryId,
            selectedCategoryName: capturedCategoryName,
            conversationHistory: capturedMessages,
            slashCommand: parsed.slashCommand,
            commandArgs: parsed.commandArgs
        )

        do {
            // Use streaming API
            let stream = AIService.shared.streamAI(
                message: parsed.cleanContent,
                context: aiContext,
                supabase: supabase
            )

            // Consume stream events
            for try await event in stream {
                NSLog("[AIChatStore] Event: \(event)")
                switch event {
                case .text(let chunk):
                    NSLog("[AIChatStore] Text: \(chunk.prefix(50))...")
                    streamingResponse += chunk
                case .toolStart(let name, _):
                    NSLog("[AIChatStore] Tool start: \(name)")
                    currentTool = name
                case .toolResult(_, _):
                    currentTool = nil
                case .toolsPending(let names):
                    NSLog("[AIChatStore] Tools pending: \(names)")
                    currentTool = names.first
                case .usage(_, _):
                    break
                case .done:
                    NSLog("[AIChatStore] Done")
                    currentTool = nil
                case .error(let msg):
                    NSLog("[AIChatStore] Error: \(msg)")
                    self.error = msg
                }
            }

            NSLog("[AIChatStore] Stream complete, streamingResponse length: \(streamingResponse.count)")
            NSLog("[AIChatStore] Stream complete, response: \(streamingResponse.prefix(500))...")

            // Save the complete response to database
            let finalResponse = streamingResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            NSLog("[AIChatStore] Final response length: \(finalResponse.count)")

            // Always stop streaming state first
            isAITyping = false
            isStreaming = false
            currentTool = nil
            stopTypingAnimation()

            if !finalResponse.isEmpty {
                NSLog("[AIChatStore] Saving AI response to database...")
                let aiInsert = ChatMessageInsert(
                    conversationId: conversationId, role: "assistant", content: finalResponse,
                    senderId: nil, isAiInvocation: false, replyToMessageId: nil
                )

                do {
                    let aiMsg = try await supabase.sendMessage(aiInsert)
                    NSLog("[AIChatStore] AI message saved with ID: \(aiMsg.id)")

                    // Clear streaming response AFTER saving
                    streamingResponse = ""

                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        messages.append(aiMsg)
                    }
                    NSLog("[AIChatStore] Message appended, total messages: \(messages.count)")
                } catch {
                    NSLog("[AIChatStore] Failed to save AI message: \(error)")
                    // Still show the response even if save fails - create a local message
                    let localMsg = ChatMessage(
                        id: UUID(),
                        conversationId: conversationId,
                        role: "assistant",
                        content: finalResponse,
                        toolCalls: nil,
                        tokensUsed: nil,
                        senderId: nil,
                        isAiInvocation: false,
                        aiPrompt: nil,
                        replyToMessageId: nil,
                        createdAt: Date()
                    )
                    streamingResponse = ""
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        messages.append(localMsg)
                    }
                }
            } else {
                NSLog("[AIChatStore] WARNING: Final response is empty!")
                streamingResponse = ""
            }
        } catch {
            NSLog("[AIChatStore] Stream error: \(error)")

            // If we have partial response, still show it
            let partialResponse = streamingResponse.trimmingCharacters(in: .whitespacesAndNewlines)

            isAITyping = false
            isStreaming = false
            currentTool = nil
            stopTypingAnimation()

            if !partialResponse.isEmpty {
                NSLog("[AIChatStore] Showing partial response despite error")
                let localMsg = ChatMessage(
                    id: UUID(),
                    conversationId: conversationId,
                    role: "assistant",
                    content: partialResponse,
                    toolCalls: nil,
                    tokensUsed: nil,
                    senderId: nil,
                    isAiInvocation: false,
                    aiPrompt: nil,
                    replyToMessageId: nil,
                    createdAt: Date()
                )
                streamingResponse = ""
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    messages.append(localMsg)
                }
            } else {
                streamingResponse = ""
                self.error = "AI error: \(error.localizedDescription)"
            }
        }
    }

    private func startTypingAnimation() {
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.typingPhase += 0.15 }
        }
    }

    private func stopTypingAnimation() {
        typingTimer?.invalidate()
        typingTimer = nil
        typingPhase = 0
    }
}
