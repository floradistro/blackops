// Extracted from SupabaseService.swift following Apple engineering standards

import Foundation
import Supabase

@MainActor
final class ChatService {
    private let client: SupabaseClient

    /// Shared decoder for Chat models — handles ISO8601 dates without .convertFromSnakeCase
    /// (Chat models have explicit CodingKeys so we must NOT use .convertFromSnakeCase)
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                throw DecodingError.valueNotFound(Date.self,
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "null date"))
            }
            let str = try container.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: str) { return date }
            // Fallback for Postgres-style timestamps
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
            if let date = fmt.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return d
    }()

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Conversations

    func fetchConversations(storeId: UUID, chatType: String? = nil) async throws -> [Conversation] {
        if let chatType = chatType {
            let response = try await client.from("lisa_conversations")
                .select("*")
                .eq("store_id", value: storeId)
                .eq("chat_type", value: chatType)
                .order("updated_at", ascending: false)
                .execute()
            return try Self.decoder.decode([Conversation].self, from: response.data)
        } else {
            let response = try await client.from("lisa_conversations")
                .select("*")
                .eq("store_id", value: storeId)
                .order("updated_at", ascending: false)
                .execute()
            return try Self.decoder.decode([Conversation].self, from: response.data)
        }
    }

    func fetchConversation(id: UUID) async throws -> Conversation {
        let response = try await client.from("lisa_conversations")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute()
        return try Self.decoder.decode(Conversation.self, from: response.data)
    }

    func fetchConversationsByLocation(locationId: UUID) async throws -> [Conversation] {
        let response = try await client.from("lisa_conversations")
            .select("*")
            .eq("location_id", value: locationId)
            .order("updated_at", ascending: false)
            .execute()
        return try Self.decoder.decode([Conversation].self, from: response.data)
    }

    /// Fetches all conversations for a store and its locations using backend RPC
    /// This replaces the previous N+1 query pattern with a single database call
    func fetchAllConversationsForStoreLocations(storeId: UUID, fetchLocations: @escaping (UUID) async throws -> [Location]) async throws -> [Conversation] {
        let response = try await client.rpc("get_all_store_conversations", params: ["p_store_id": storeId.uuidString])
            .execute()
        return try Self.decoder.decode([Conversation].self, from: response.data)
    }

    func createConversation(_ conversation: ConversationInsert) async throws -> Conversation {
        let response = try await client.from("lisa_conversations")
            .insert(conversation)
            .select("*")
            .single()
            .execute()
        return try Self.decoder.decode(Conversation.self, from: response.data)
    }

    func getOrCreateTeamConversation(storeId: UUID, chatType: String = "dm", title: String? = nil) async throws -> Conversation {
        // Try to find existing conversation of this type
        let existingResponse = try await client.from("lisa_conversations")
            .select("*")
            .eq("store_id", value: storeId)
            .eq("chat_type", value: chatType)
            .eq("status", value: "active")
            .limit(1)
            .execute()

        let existing = try Self.decoder.decode([Conversation].self, from: existingResponse.data)
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
        if let before = before {
            let response = try await client.from("lisa_messages")
                .select("*")
                .eq("conversation_id", value: conversationId)
                .lt("created_at", value: ISO8601DateFormatter().string(from: before))
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
            let messages = try Self.decoder.decode([ChatMessage].self, from: response.data)
            return messages.reversed()
        } else {
            let response = try await client.from("lisa_messages")
                .select("*")
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
            let messages = try Self.decoder.decode([ChatMessage].self, from: response.data)
            return messages.reversed()
        }
    }

    func sendMessage(_ message: ChatMessageInsert) async throws -> ChatMessage {
        let response = try await client.from("lisa_messages")
            .insert(message)
            .select("*")
            .single()
            .execute()
        return try Self.decoder.decode(ChatMessage.self, from: response.data)
    }

    // MARK: - Chat Participants

    func fetchParticipants(conversationId: UUID) async throws -> [ChatParticipant] {
        let response = try await client.from("lisa_chat_participants")
            .select("*")
            .eq("conversation_id", value: conversationId)
            .is("left_at", value: nil)
            .execute()
        return try Self.decoder.decode([ChatParticipant].self, from: response.data)
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
