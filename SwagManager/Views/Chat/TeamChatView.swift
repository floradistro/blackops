import SwiftUI
import Supabase

// MARK: - Team Chat View
// Native macOS iMessage-style team chat
// HSplitView: channel list (left) + message thread (right)

struct TeamChatView: View {
    let storeId: UUID?
    @State private var store = TeamChatStore()

    var body: some View {
        HSplitView {
            // Left: Channel list
            ChannelListPane(store: store)
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)

            // Right: Message thread
            if store.selectedChannel != nil {
                MessageThreadPane(store: store)
            } else {
                emptyChatState
            }
        }
        .task {
            guard let storeId else { return }
            await store.loadChannels(storeId: storeId)
        }
        .onDisappear {
            store.cleanup()
        }
        .navigationTitle(store.selectedChannel?.displayTitle ?? "Team Chat")
    }

    private var emptyChatState: some View {
        ContentUnavailableView {
            Label("Team Chat", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("Select a channel to start chatting")
        }
    }
}

// MARK: - Channel List Pane

private struct ChannelListPane: View {
    @Bindable var store: TeamChatStore

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Channels")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Error display
            if let error = store.error, store.channels.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundStyle(.red.opacity(0.6))
                    Text("Failed to load")
                        .font(.system(size: 12, weight: .medium))
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
            } else if store.isLoadingChannels {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            } else if store.channels.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No channels")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(store.groupedChannels, id: \.0) { label, icon, groupChannels in
                        Section {
                            ForEach(groupChannels) { channel in
                                Button {
                                    store.selectChannel(channel)
                                } label: {
                                    ChannelRow(channel: channel)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(
                                    store.selectedChannel?.id == channel.id
                                        ? Color.accentColor.opacity(0.15)
                                        : Color.clear
                                )
                            }
                        } header: {
                            Label(label, systemImage: icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Channel Row

private struct ChannelRow: View {
    let channel: Conversation

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: channel.chatTypeIcon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(channelName)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)

                if let count = channel.messageCount, count > 0 {
                    Text("\(count) messages")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var channelName: String {
        let title = channel.title ?? channel.chatTypeLabel
        if channel.chatType == "team" {
            return "#\(title)"
        }
        return title
    }

    private var iconColor: Color {
        switch channel.chatType {
        case "team": return .secondary
        case "location": return DesignSystem.Colors.blue
        case "alerts": return DesignSystem.Colors.warning
        case "bugs": return DesignSystem.Colors.error
        case "dm": return DesignSystem.Colors.green
        default: return .secondary
        }
    }
}

// MARK: - Message Thread Pane

private struct MessageThreadPane: View {
    @Bindable var store: TeamChatStore
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Channel header bar
            channelHeader

            Divider()

            // Error banner
            if let error = store.error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red.opacity(0.8))
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") { store.error = nil }
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.08))
            }

            // Messages
            if store.isLoadingMessages {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            } else if store.messages.isEmpty {
                emptyMessages
            } else {
                messageList
            }

            Divider()

            // Input bar
            inputBar
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Channel Header

    private var channelHeader: some View {
        HStack(spacing: 10) {
            if let channel = store.selectedChannel {
                Image(systemName: channel.chatTypeIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(channel.displayTitle)
                        .font(.system(size: 14, weight: .semibold))

                    if let meta = channel.metadata,
                       let desc = meta.value as? [String: Any],
                       let description = desc["description"] as? String {
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if let count = store.selectedChannel?.messageCount, count > 0 {
                Text("\(count) messages")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Empty Messages

    private var emptyMessages: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "bubble.left")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(.quaternary)

            Text("No messages yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Start the conversation")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Load more button
                if store.hasMoreMessages {
                    Button("Load earlier messages") {
                        Task { await store.loadMoreMessages() }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                }

                // Date-grouped messages
                ForEach(groupedMessages, id: \.0) { dateKey, dayMessages in
                    ChatDateSeparator(date: dayMessages.first?.createdAt ?? Date())

                    let indices = dayMessages.groupedIndices()
                    ForEach(Array(zip(dayMessages.indices, dayMessages)), id: \.1.id) { idx, message in
                        let groupInfo = idx < indices.count ? indices[idx] : (true, true)
                        ChatMessageBubble(
                            message: message,
                            config: .init(
                                isFromCurrentUser: message.isFromUser,
                                showAvatar: true,
                                isFirstInGroup: groupInfo.0,
                                isLastInGroup: groupInfo.1,
                                isPending: false,
                                style: .standard
                            )
                        )
                        .id(message.id)
                    }
                }

                Spacer()
                    .frame(height: 12)
            }
            .padding(.horizontal, 12)
        }
        .defaultScrollAnchor(.bottom)
        .scrollContentBackground(.hidden)
    }

    /// Group messages by calendar day
    private var groupedMessages: [(String, [ChatMessage])] {
        let calendar = Calendar.current
        var groups: [(String, [ChatMessage])] = []
        var currentKey = ""
        var currentGroup: [ChatMessage] = []

        for message in store.messages {
            let date = message.createdAt ?? Date()
            let key = calendar.isDateInToday(date) ? "Today"
                : calendar.isDateInYesterday(date) ? "Yesterday"
                : Formatters.formatDateHeader(date)

            if key != currentKey {
                if !currentGroup.isEmpty {
                    groups.append((currentKey, currentGroup))
                }
                currentKey = key
                currentGroup = [message]
            } else {
                currentGroup.append(message)
            }
        }
        if !currentGroup.isEmpty {
            groups.append((currentKey, currentGroup))
        }
        return groups
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Message...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...6)
                .focused($inputFocused)
                .onSubmit {
                    sendMessage()
                }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSending
                            ? Color.secondary.opacity(0.3)
                            : Color.accentColor
                    )
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSending)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func sendMessage() {
        let text = inputText
        inputText = ""
        Task {
            await store.sendMessage(text)
        }
    }
}

// MARK: - Preview

#Preview {
    TeamChatView(storeId: nil)
        .frame(width: 800, height: 600)
}
