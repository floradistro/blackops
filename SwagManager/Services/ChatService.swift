// Extracted from SupabaseService.swift following Apple engineering standards

import Foundation
import Supabase

@MainActor
final class ChatService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Conversations

    func fetchConversations(storeId: UUID, chatType: String? = nil) async throws -> [Conversation] {
        if let chatType = chatType {
            return try await client.from("lisa_conversations")
                .select("*")
                .eq("store_id", value: storeId)
                .eq("chat_type", value: chatType)
                .order("updated_at", ascending: false)
                .execute()
                .value
        } else {
            // Fetch ALL conversations for this store (don't filter by status)
            return try await client.from("lisa_conversations")
                .select("*")
                .eq("store_id", value: storeId)
                .order("updated_at", ascending: false)
                .execute()
                .value
        }
    }

    func fetchConversation(id: UUID) async throws -> Conversation {
        return try await client.from("lisa_conversations")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func fetchConversationsByLocation(locationId: UUID) async throws -> [Conversation] {
        return try await client.from("lisa_conversations")
            .select("*")
            .eq("location_id", value: locationId)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches all conversations for a store and its locations using backend RPC
    /// This replaces the previous N+1 query pattern with a single database call
    func fetchAllConversationsForStoreLocations(storeId: UUID, fetchLocations: @escaping (UUID) async throws -> [Location]) async throws -> [Conversation] {

        // Use the backend RPC - single query handles all logic
        let response = try await client.rpc("get_all_store_conversations", params: ["p_store_id": storeId.uuidString])
            .execute()

        // Decode the JSON response
        let decoder = JSONDecoder()
        // Note: Don't use .convertFromSnakeCase - Conversation model has explicit CodingKeys
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
            // Try alternative format
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
        }

        let conversations = try decoder.decode([Conversation].self, from: response.data)
        return conversations
    }

    func createConversation(_ conversation: ConversationInsert) async throws -> Conversation {
        return try await client.from("lisa_conversations")
            .insert(conversation)
            .select("*")
            .single()
            .execute()
            .value
    }

    func getOrCreateTeamConversation(storeId: UUID, chatType: String = "dm", title: String? = nil) async throws -> Conversation {
        // Try to find existing conversation of this type
        let existing: [Conversation] = try await client.from("lisa_conversations")
            .select("*")
            .eq("store_id", value: storeId)
            .eq("chat_type", value: chatType)
            .eq("status", value: "active")
            .limit(1)
            .execute()
            .value

        if let first = existing.first {
            return first
        }

        // Create new conversation
        let insert = ConversationInsert(
            storeId: storeId,
            userId: nil,
            title: title ?? "Team Chat",
            chatType: chatType,
            locationId: nil
        )
        return try await createConversation(insert)
    }

    // MARK: - Messages

    func fetchMessages(conversationId: UUID, limit: Int = 50, before: Date? = nil) async throws -> [ChatMessage] {
        let messages: [ChatMessage]
        if let before = before {
            messages = try await client.from("lisa_messages")
                .select("*")
                .eq("conversation_id", value: conversationId)
                .lt("created_at", value: ISO8601DateFormatter().string(from: before))
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else {
            messages = try await client.from("lisa_messages")
                .select("*")
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        }
        return messages.reversed() // Return in chronological order
    }

    func sendMessage(_ message: ChatMessageInsert) async throws -> ChatMessage {
        return try await client.from("lisa_messages")
            .insert(message)
            .select("*")
            .single()
            .execute()
            .value
    }

    // MARK: - Chat Participants

    func fetchParticipants(conversationId: UUID) async throws -> [ChatParticipant] {
        return try await client.from("lisa_chat_participants")
            .select("*")
            .eq("conversation_id", value: conversationId)
            .is("left_at", value: nil)
            .execute()
            .value
    }

    func updateTypingStatus(conversationId: UUID, userId: UUID, isTyping: Bool) async throws {
        struct TypingUpdate: Codable {
            let isTyping: Bool
            let typingStartedAt: String?

            enum CodingKeys: String, CodingKey {
                case isTyping = "is_typing"
                case typingStartedAt = "typing_started_at"
            }
        }

        let update = TypingUpdate(
            isTyping: isTyping,
            typingStartedAt: isTyping ? ISO8601DateFormatter().string(from: Date()) : nil
        )

        try await client.from("lisa_chat_participants")
            .update(update)
            .eq("conversation_id", value: conversationId)
            .eq("user_id", value: userId)
            .execute()
    }

    func markMessagesRead(conversationId: UUID, userId: UUID, lastMessageId: UUID) async throws {
        try await client.from("lisa_chat_participants")
            .update(["last_read_at": ISO8601DateFormatter().string(from: Date()), "last_read_message_id": lastMessageId.uuidString])
            .eq("conversation_id", value: conversationId)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Realtime Channel

    func messagesChannel(conversationId: UUID) -> RealtimeChannelV2 {
        return client.realtimeV2.channel("messages:\(conversationId.uuidString)")
    }
}
