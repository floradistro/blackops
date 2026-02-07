import Foundation
import Combine
import Supabase
import Realtime

// MARK: - Team Chat Store
// State management for team chat — channels, messages, participants, realtime

@MainActor
@Observable
class TeamChatStore {
    // MARK: - State
    var channels: [Conversation] = []
    var messages: [ChatMessage] = []
    var participants: [ChatParticipant] = []
    var typingUsers: [UUID] = []
    var selectedChannel: Conversation?
    var isLoadingChannels = false
    var isLoadingMessages = false
    var isSending = false
    var error: String?
    var hasMoreMessages = false

    // MARK: - Grouped Channels (cached)
    // Cache invalidated when channels array changes
    @ObservationIgnored private var _cachedGroupedChannels: [(String, String, [Conversation])]?
    @ObservationIgnored private var _cachedChannelsHash: Int = 0

    var groupedChannels: [(String, String, [Conversation])] {
        let currentHash = channels.hashValue
        if let cached = _cachedGroupedChannels, currentHash == _cachedChannelsHash {
            return cached
        }

        let groups: [(String, String, [String])] = [
            ("Channels", "bubble.left.and.bubble.right", ["team"]),
            ("Locations", "mappin.and.ellipse", ["location"]),
            ("System", "bell.badge", ["alerts", "bugs"]),
        ]
        let result = groups.compactMap { label, icon, types -> (String, String, [Conversation])? in
            let matching = channels.filter { types.contains($0.chatType ?? "") }
            guard !matching.isEmpty else { return nil }
            return (label, icon, matching)
        }

        _cachedGroupedChannels = result
        _cachedChannelsHash = currentHash
        return result
    }

    // MARK: - Unread Count
    var totalUnreadCount: Int {
        // Placeholder — requires participant last_read tracking
        0
    }

    // MARK: - Dependencies
    private let chatService: ChatService
    private var storeId: UUID?
    @ObservationIgnored private var messagesChannel: RealtimeChannelV2?
    @ObservationIgnored private var realtimeTask: Task<Void, Never>?
    @ObservationIgnored private var typingTask: Task<Void, Never>?

    init() {
        self.chatService = SupabaseService.shared.chat
    }

    // MARK: - Load Channels

    func loadChannels(storeId: UUID) async {
        self.storeId = storeId
        isLoadingChannels = true
        error = nil

        do {
            // Fetch all conversations for this store (team chat types only)
            print("[TeamChat] Loading channels for store: \(storeId)")
            let all = try await chatService.fetchConversations(storeId: storeId)
            print("[TeamChat] Fetched \(all.count) conversations")
            let teamTypes = Set(["team", "location", "alerts", "bugs", "dm"])
            channels = all.filter { teamTypes.contains($0.chatType ?? "") }
                .sorted { ($0.chatType ?? "") < ($1.chatType ?? "") }
            print("[TeamChat] Filtered to \(channels.count) team chat channels")

            // If no channels exist, create defaults
            if channels.isEmpty {
                try await SupabaseService.shared.client
                    .rpc("create_default_channels_for_store", params: ["p_store_id": storeId.uuidString])
                    .execute()
                let refreshed = try await chatService.fetchConversations(storeId: storeId)
                channels = refreshed.filter { teamTypes.contains($0.chatType ?? "") }
                    .sorted { ($0.chatType ?? "") < ($1.chatType ?? "") }
            }

            isLoadingChannels = false

            // Auto-select first channel if none selected
            if selectedChannel == nil, let first = channels.first(where: { $0.chatType == "team" }) ?? channels.first {
                selectChannel(first)
            }
        } catch {
            print("[TeamChat] Error loading channels: \(error)")
            self.error = error.localizedDescription
            isLoadingChannels = false
        }
    }

    // MARK: - Select Channel

    func selectChannel(_ channel: Conversation) {
        guard selectedChannel?.id != channel.id else { return }
        selectedChannel = channel

        // Unsubscribe from previous channel's realtime
        unsubscribeRealtime()

        // Load messages for the new channel
        Task {
            await loadMessages(for: channel)
            subscribeRealtime(conversationId: channel.id)
        }
    }

    // MARK: - Load Messages

    func loadMessages(for channel: Conversation) async {
        isLoadingMessages = true
        do {
            let fetched = try await chatService.fetchMessages(conversationId: channel.id, limit: 50)
            messages = fetched
            hasMoreMessages = fetched.count >= 50
            isLoadingMessages = false
        } catch {
            self.error = error.localizedDescription
            isLoadingMessages = false
        }
    }

    func loadMoreMessages() async {
        guard hasMoreMessages,
              let channel = selectedChannel,
              let oldest = messages.first?.createdAt else { return }

        do {
            let older = try await chatService.fetchMessages(conversationId: channel.id, limit: 50, before: oldest)
            messages.insert(contentsOf: older, at: 0)
            hasMoreMessages = older.count >= 50
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Send Message

    func sendMessage(_ text: String) async {
        guard let channel = selectedChannel else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSending = true

        let insert = ChatMessageInsert(
            conversationId: channel.id,
            role: "user",
            content: trimmed,
            senderId: nil, // Will be populated server-side or by auth
            isAiInvocation: false,
            replyToMessageId: nil
        )

        do {
            let sent = try await chatService.sendMessage(insert)
            // Only append if realtime hasn't already added it
            if !messages.contains(where: { $0.id == sent.id }) {
                messages.append(sent)
            }
            isSending = false
        } catch {
            self.error = error.localizedDescription
            isSending = false
        }
    }

    // MARK: - Realtime Subscription

    private func subscribeRealtime(conversationId: UUID) {
        let client = SupabaseService.shared.client

        let channel = client.realtimeV2.channel("team-chat-\(conversationId.uuidString)")

        realtimeTask = Task {
            // Listen for new messages via postgres_changes
            let insertions = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "lisa_messages",
                filter: "conversation_id=eq.\(conversationId.uuidString)"
            )

            await channel.subscribe()

            for await insertion in insertions {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let str = try container.decode(String.self)
                        let iso = ISO8601DateFormatter()
                        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        if let d = iso.date(from: str) { return d }
                        iso.formatOptions = [.withInternetDateTime]
                        if let d = iso.date(from: str) { return d }
                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date")
                    }
                    let data = try JSONSerialization.data(withJSONObject: insertion.record)
                    let newMessage = try decoder.decode(ChatMessage.self, from: data)
                    if !self.messages.contains(where: { $0.id == newMessage.id }) {
                        self.messages.append(newMessage)
                    }
                } catch {
                    // Silently handle decode errors
                }
            }
        }

        messagesChannel = channel
    }

    private func unsubscribeRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let channel = messagesChannel {
            Task {
                await SupabaseService.shared.client.realtimeV2.removeChannel(channel)
            }
        }
        messagesChannel = nil
    }

    // MARK: - Cleanup

    func cleanup() {
        unsubscribeRealtime()
        typingTask?.cancel()
    }
}
