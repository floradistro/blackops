import SwiftUI

// MARK: - AI Chat Pane
// Apple-like chat interface with smooth animations and timeline-based messages

struct AIChatPane: View {
    @StateObject private var chatStore = AIChatStore()
    @Environment(EditorStore.self) var editorStore
    @ObservedObject private var agentClient = AgentClient.shared
    @State private var inputText = ""
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 0) {
            if showHistory {
                // Conversation history list (Messages.app pattern)
                ConversationHistoryView(
                    agentClient: agentClient,
                    chatStore: chatStore,
                    storeId: editorStore.selectedStore?.id,
                    onSelect: { conv in
                        // Load full conversation from server
                        agentClient.onConversationLoaded = { [weak chatStore] id, title, messages in
                            chatStore?.restoreTimeline(from: messages, conversationId: id, title: title)
                        }
                        agentClient.loadConversation(conv.id)
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showHistory = false
                        }
                    },
                    onNewConversation: {
                        chatStore.clearConversation()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showHistory = false
                        }
                    }
                )
            } else {
                // Timeline — .defaultScrollAnchor(.bottom) is the native Apple pattern
                // for chat auto-scroll. It pins to bottom as content grows and respects
                // user scroll position (won't force-scroll if user scrolled up).
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if chatStore.timeline.isEmpty {
                            ChatEmptyState()
                        } else {
                            ForEach(chatStore.timeline) { item in
                                TimelineItemView(
                                    item: item,
                                    streamingBuffer: chatStore.streamingBuffer
                                )
                                .id(item.id)
                            }
                        }

                        Spacer()
                            .frame(height: 12)
                    }
                }
                .defaultScrollAnchor(.bottom)
                .scrollContentBackground(.hidden)

                // Input bar
                InputBar(
                    text: $inputText,
                    isStreaming: chatStore.isStreaming,
                    onSend: sendMessage
                )
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    // Agent switcher
                    Menu {
                        ForEach(editorStore.aiAgents) { agent in
                            Button {
                                chatStore.agentId = agent.id
                            } label: {
                                HStack {
                                    if let icon = agent.icon, !icon.isEmpty {
                                        Image(systemName: icon)
                                    }
                                    Text(agent.displayName)
                                    if chatStore.agentId == agent.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let agent = chatStore.currentAgent, let icon = agent.icon, !icon.isEmpty {
                                Image(systemName: icon)
                                    .font(.system(size: 12))
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                            }
                            Text(chatStore.currentAgent?.displayName ?? "Agent")
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    // Connection indicator
                    Circle()
                        .fill(agentClient.isConnected ? Color.green : Color.red.opacity(0.6))
                        .frame(width: 6, height: 6)
                }
            }

            ToolbarItem(placement: .automatic) {
                HStack(spacing: 4) {
                    Button {
                        chatStore.clearConversation()
                        showHistory = false
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .help("New conversation")

                    Button {
                        chatStore.clearConversation()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(chatStore.timeline.isEmpty)
                    .help("Clear conversation")

                    Button {
                        if let storeId = editorStore.selectedStore?.id {
                            agentClient.getConversations(storeId: storeId)
                        }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showHistory.toggle()
                        }
                    } label: {
                        Image(systemName: showHistory ? "bubble.left.fill" : "clock.arrow.circlepath")
                    }
                    .help(showHistory ? "Back to chat" : "Conversation history")
                }
            }
        }
        .task {
            // Lazy agent start — only connect when chat pane first appears
            if !AgentProcessManager.shared.isRunning {
                AgentProcessManager.shared.start()
            }
            await editorStore.loadAIAgents()
            syncAgentState()
            chatStore.storeId = editorStore.selectedStore?.id
            // Pre-load conversation history once connected
            if agentClient.isConnected, let storeId = editorStore.selectedStore?.id {
                agentClient.getConversations(storeId: storeId, limit: 50)
            }
        }
        .onChange(of: agentClient.isConnected) { _, connected in
            // Fetch history as soon as WebSocket connects
            if connected, let storeId = editorStore.selectedStore?.id {
                agentClient.getConversations(storeId: storeId, limit: 50)
            }
        }
        .onChange(of: editorStore.selectedStore?.id) { _, newId in
            guard chatStore.storeId != newId else { return }
            chatStore.clearConversation()
            chatStore.storeId = newId
            // Reset agent — will be set to new store's first agent after load
            chatStore.agentId = nil
            chatStore.currentAgent = nil
            Task {
                await editorStore.loadAIAgents()
                syncAgentState()
            }
            // Reload history for new store
            if let newId, agentClient.isConnected {
                agentClient.getConversations(storeId: newId, limit: 50)
            }
        }
        .onChange(of: editorStore.aiAgents.count) { _, _ in
            syncAgentState()
        }
        .onChange(of: chatStore.agentId) { oldId, newId in
            guard oldId != newId else { return }
            if let newId = newId {
                chatStore.currentAgent = editorStore.aiAgents.first { $0.id == newId }
            } else {
                chatStore.currentAgent = nil
            }
        }
    }

    private func syncAgentState() {
        let agents = editorStore.aiAgents
        if let id = chatStore.agentId, let agent = agents.first(where: { $0.id == id }) {
            // Current agent exists in this store — keep it
            chatStore.currentAgent = agent
        } else if let first = agents.first {
            // Agent not found (nil or wrong store) — pick first available
            chatStore.agentId = first.id
            chatStore.currentAgent = first
        } else {
            // No agents in this store
            chatStore.agentId = nil
            chatStore.currentAgent = nil
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task {
            await chatStore.sendMessage(text)
        }
    }
}

// MARK: - Empty State

private struct ChatEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)

            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.tertiary)

            Text("Ask anything")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// MARK: - Timeline Item View

private struct TimelineItemView: View {
    let item: ChatTimelineItem
    @ObservedObject var streamingBuffer: StreamingTextBuffer

    var body: some View {
        switch item {
        case .userMessage(_, let content, _):
            UserMessageRow(content: content)

        case .thinking:
            ThinkingRow()

        case .toolCall(_, let name, let status, _, let result, _):
            ToolCallRow(name: name, status: status, result: result)

        case .assistantMessage(_, let content, let isStreaming, _):
            AssistantMessageRow(
                content: content,
                isStreaming: isStreaming,
                streamingBuffer: streamingBuffer
            )

        case .error(_, let message, _):
            ErrorRow(message: message)
        }
    }
}

// MARK: - User Message Row

private struct UserMessageRow: View {
    let content: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Spacer(minLength: 48)

            Text(content)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// MARK: - Thinking Row

private struct ThinkingRow: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 10) {
            // Pulsing dots indicator
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(isPulsing ? 0.3 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: isPulsing
                        )
                }
            }

            Text("Thinking")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(minHeight: 36) // Stable height to prevent layout jumps
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Tool Call Row

private struct ToolCallRow: View {
    let name: String
    let status: ToolStatus
    let result: String?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tool header
            Button {
                if result != nil {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    // Status icon
                    Group {
                        switch status {
                        case .running:
                            ProgressView()
                                .controlSize(.small)
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failed:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(width: 16, height: 16)

                    // Tool name
                    Text(cleanToolName(name))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    // Expand indicator
                    if result != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
            .buttonStyle(.plain)

            // Expanded result
            if isExpanded, let result = result {
                Text(result.prefix(500) + (result.count > 500 ? "..." : ""))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.02))
                    )
                    .padding(.top, 4)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Assistant Message Row

private struct AssistantMessageRow: View {
    let content: String
    let isStreaming: Bool
    @ObservedObject var streamingBuffer: StreamingTextBuffer

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                if isStreaming {
                    // Streaming: render markdown in real-time
                    if streamingBuffer.text.isEmpty {
                        TypewriterCursor()
                    } else {
                        MarkdownText(streamingBuffer.text)
                            .textSelection(.enabled)
                    }
                } else {
                    // Final: render markdown
                    if content.isEmpty {
                        EmptyView()
                    } else {
                        MarkdownText(content)
                            .textSelection(.enabled)
                    }
                }
            }

            Spacer(minLength: 48)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Error Row

private struct ErrorRow: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red.opacity(0.8))
                .font(.system(size: 14))

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.06))
    }
}

// MARK: - Typewriter Cursor

private struct TypewriterCursor: View {
    @State private var opacity: Double = 1

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.accentColor)
            .frame(width: 2, height: 18)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    opacity = 0.2
                }
            }
    }
}

// MARK: - Input Bar

private struct InputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)

            HStack(spacing: 12) {
                // Text field
                TextField("Message...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .onSubmit {
                        if !text.isEmpty && !isStreaming {
                            onSend()
                        }
                    }

                // Send button
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            text.isEmpty || isStreaming
                                ? Color.secondary.opacity(0.3)
                                : Color.accentColor
                        )
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty || isStreaming)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Conversation History View
// Full inline history list — replaces the timeline when visible (Messages.app pattern)

private struct ConversationHistoryView: View {
    @ObservedObject var agentClient: AgentClient
    @ObservedObject var chatStore: AIChatStore
    let storeId: UUID?
    let onSelect: (ConversationMeta) -> Void
    let onNewConversation: () -> Void

    private var grouped: [(String, [ConversationMeta])] {
        let calendar = Calendar.current
        let now = Date()
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]

        func parse(_ str: String) -> Date {
            isoFractional.date(from: str) ?? isoBasic.date(from: str) ?? .distantPast
        }

        var today: [ConversationMeta] = []
        var yesterday: [ConversationMeta] = []
        var week: [ConversationMeta] = []
        var month: [ConversationMeta] = []
        var older: [ConversationMeta] = []

        for conv in agentClient.conversations {
            let date = parse(conv.updatedAt.isEmpty ? conv.createdAt : conv.updatedAt)

            if calendar.isDateInToday(date) {
                today.append(conv)
            } else if calendar.isDateInYesterday(date) {
                yesterday.append(conv)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now), date >= weekAgo {
                week.append(conv)
            } else if let monthAgo = calendar.date(byAdding: .day, value: -30, to: now), date >= monthAgo {
                month.append(conv)
            } else {
                older.append(conv)
            }
        }

        var result: [(String, [ConversationMeta])] = []
        if !today.isEmpty { result.append(("Today", today)) }
        if !yesterday.isEmpty { result.append(("Yesterday", yesterday)) }
        if !week.isEmpty { result.append(("Previous 7 Days", week)) }
        if !month.isEmpty { result.append(("Previous 30 Days", month)) }
        if !older.isEmpty { result.append(("Older", older)) }
        return result
    }

    var body: some View {
        Group {
            if agentClient.conversations.isEmpty {
                emptyState
            } else {
                conversationList
            }
        }
        .onAppear {
            if let storeId {
                agentClient.getConversations(storeId: storeId, limit: 50)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(.quaternary)

            Text("No conversations")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Start a new conversation to see it here.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button(action: onNewConversation) {
                Text("New Conversation")
            }
            .controlSize(.large)
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var conversationList: some View {
        List {
            ForEach(grouped, id: \.0) { section, conversations in
                Section(section) {
                    ForEach(conversations) { conv in
                        ConversationRow(
                            conversation: conv,
                            isActive: chatStore.conversationId == conv.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(conv)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .alternatingRowBackgrounds(.disabled)
    }
}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conversation: ConversationMeta
    let isActive: Bool

    private var relativeDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: conversation.updatedAt)
                ?? formatter.date(from: conversation.createdAt) else {
            return ""
        }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(conversation.title.isEmpty ? "Untitled" : conversation.title)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .primary : .primary)
                    .lineLimit(1)

                Spacer()

                Text(relativeDate)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 6) {
                if let agentName = conversation.agentName, !agentName.isEmpty {
                    Text(agentName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if conversation.messageCount > 0 {
                    Text("\(conversation.messageCount) msgs")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(
            isActive
                ? RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                : nil
        )
    }
}

// MARK: - Helpers

private func cleanToolName(_ name: String) -> String {
    name
        .replacingOccurrences(of: "mcp__swagmanager__", with: "")
        .replacingOccurrences(of: "mcp__local__", with: "")
        .replacingOccurrences(of: "mcp__business__", with: "")
        .replacingOccurrences(of: "_", with: " ")
        .localizedCapitalized
}

// MARK: - Preview

#Preview {
    AIChatPane()
        .environment(EditorStore())
        .frame(width: 400, height: 600)
}
