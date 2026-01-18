import SwiftUI
import Supabase

// MARK: - Team Chat View (iMessage Style)

struct TeamChatView: View {
    @ObservedObject var store: EditorStore
    @StateObject private var chatStore = ChatStore()

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
        .background(Color(white: 0.08))
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

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 10) {
            if let conv = chatStore.conversation {
                // Status indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(conv.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                    Text(conv.chatTypeLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if let count = conv.messageCount, count > 0 {
                    Text("\(count) messages")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.06))
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(chatStore.groupedMessages, id: \.date) { group in
                        // Date separator
                        dateSeparator(group.date)

                        ForEach(group.messages) { message in
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: message.senderId == chatStore.currentUserId,
                                showAvatar: shouldShowAvatar(for: message, in: group.messages)
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: chatStore.messages.count) { _, _ in
                if let lastMessage = chatStore.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastMessage = chatStore.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    private func dateSeparator(_ date: Date) -> some View {
        HStack {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            Text(formatDateHeader(date))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.35))
                .padding(.horizontal, 8)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
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
        HStack(spacing: 10) {
            // Text field
            TextField("Type a message...", text: $chatStore.draftMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...5)
                .onSubmit {
                    Task { await chatStore.sendMessage(supabase: store.supabase) }
                }

            // Send button
            Button {
                Task { await chatStore.sendMessage(supabase: store.supabase) }
            } label: {
                Image(systemName: chatStore.draftMessage.isEmpty ? "arrow.up.circle" : "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(chatStore.draftMessage.isEmpty ? Color.white.opacity(0.25) : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(chatStore.draftMessage.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(white: 0.06))
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
    }

    // MARK: - Helpers

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let showAvatar: Bool

    private var avatarColor: Color {
        if message.isFromAssistant {
            return .purple
        }
        // Generate consistent color from sender ID
        let hash = message.senderId?.hashValue ?? 0
        let colors: [Color] = [.blue, .green, .orange, .pink, .teal, .indigo]
        return colors[abs(hash) % colors.count]
    }

    private var initials: String {
        if message.isFromAssistant { return "AI" }
        return "U"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            } else {
                // Avatar
                if showAvatar {
                    Circle()
                        .fill(avatarColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(initials)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(avatarColor)
                        )
                } else {
                    Color.clear.frame(width: 32, height: 32)
                }
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message content
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isFromCurrentUser ?
                        Color.accentColor :
                        Color(white: 0.15)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Timestamp
                if let createdAt = message.createdAt {
                    Text(formatTime(createdAt))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }

            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Chat Bubble Shape

struct ChatBubbleShape: Shape {
    let isFromCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailSize: CGFloat = 6

        var path = Path()

        if isFromCurrentUser {
            // Right-aligned bubble with tail on right
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                             control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - radius + tailSize, y: rect.maxY),
                             control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                             control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                             control: CGPoint(x: rect.minX, y: rect.minY))
        } else {
            // Left-aligned bubble with tail on left
            path.move(to: CGPoint(x: rect.minX + radius - tailSize, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                             control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                             control: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                             control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                             control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + radius - tailSize, y: rect.maxY))
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 5, height: 5)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
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
            messages.append(newMessage)
        } catch {
            self.error = error.localizedDescription
            NSLog("[ChatStore] Error sending message: \(error)")
            // Restore draft on error
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

// MARK: - Chat Tab View (Full-size conversation view for main content area)

struct ChatTabView: View {
    let conversation: Conversation
    @ObservedObject var store: EditorStore
    @StateObject private var chatStore = ChatStore()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            // Content
            if chatStore.isLoading && chatStore.messages.isEmpty {
                loadingView
            } else if let error = chatStore.error {
                errorView(error)
            } else if chatStore.messages.isEmpty {
                emptyStateView
            } else {
                messageList
            }

            // Input
            messageInput
        }
        .background(Color(white: 0.08))
        .task {
            await chatStore.loadConversationMessages(conversation, supabase: store.supabase)
        }
        .onChange(of: conversation.id) { _, _ in
            Task {
                await chatStore.loadConversationMessages(conversation, supabase: store.supabase)
            }
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: conversation.chatTypeIcon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color(white: 0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.displayTitle)
                    .font(.system(size: 14, weight: .semibold))

                HStack(spacing: 6) {
                    Text(conversation.chatTypeLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if let count = conversation.messageCount {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text("\(count) messages")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button {
                    Task {
                        await chatStore.loadConversationMessages(conversation, supabase: store.supabase)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.06))
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(chatStore.groupedMessages, id: \.date) { group in
                        dateSeparator(group.date)

                        ForEach(group.messages) { message in
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: message.senderId == chatStore.currentUserId,
                                showAvatar: shouldShowAvatar(for: message, in: group.messages)
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: chatStore.messages.count) { _, _ in
                if let lastMessage = chatStore.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastMessage = chatStore.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    private func dateSeparator(_ date: Date) -> some View {
        HStack {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            Text(formatDateHeader(date))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
                .padding(.horizontal, 12)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
        .padding(.vertical, 16)
    }

    private func shouldShowAvatar(for message: ChatMessage, in messages: [ChatMessage]) -> Bool {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return true }
        if index == 0 { return true }
        let previousMessage = messages[index - 1]
        return previousMessage.senderId != message.senderId
    }

    // MARK: - Message Input

    private var messageInput: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $chatStore.draftMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...6)
                .onSubmit {
                    Task { await chatStore.sendMessage(supabase: store.supabase) }
                }

            Button {
                Task { await chatStore.sendMessage(supabase: store.supabase) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(chatStore.draftMessage.isEmpty ? Color.white.opacity(0.2) : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(chatStore.draftMessage.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.06))
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading messages...")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange.opacity(0.6))
            Text("Error loading messages")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text(error)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") {
                Task {
                    await chatStore.loadConversationMessages(conversation, supabase: store.supabase)
                }
            }
            .font(.system(size: 12))
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(Color.white.opacity(0.15))

            VStack(spacing: 6) {
                Text("No messages yet")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Be the first to start the conversation")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}
