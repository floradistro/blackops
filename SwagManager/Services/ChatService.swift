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
        NSLog("[SupabaseService] Fetching conversations for store: \(storeId), chatType: \(chatType ?? "all")")
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
        NSLog("[SupabaseService] Fetching conversations for location: \(locationId)")
        return try await client.from("lisa_conversations")
            .select("*")
            .eq("location_id", value: locationId)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func fetchAllConversationsForStoreLocations(storeId: UUID, fetchLocations: @escaping (UUID) async throws -> [Location]) async throws -> [Conversation] {
        NSLog("[SupabaseService] Fetching all conversations for store locations: \(storeId)")
        // First get all locations for this store
        let locations = try await fetchLocations(storeId)
        NSLog("[SupabaseService] Found \(locations.count) locations")

        // Then get conversations for each location
        var allConversations: [Conversation] = []
        for location in locations {
            let convos = try await fetchConversationsByLocation(locationId: location.id)
            NSLog("[SupabaseService] Location '\(location.name)' has \(convos.count) conversations")
            allConversations.append(contentsOf: convos)
        }

        // Also try to get conversations directly by store_id
        let storeConvos = try await fetchConversations(storeId: storeId, chatType: nil)
        NSLog("[SupabaseService] Store has \(storeConvos.count) direct conversations")

        // Merge and deduplicate
        let existingIds = Set(allConversations.map { $0.id })
        for conv in storeConvos {
            if !existingIds.contains(conv.id) {
                allConversations.append(conv)
            }
        }

        NSLog("[SupabaseService] Total conversations: \(allConversations.count)")
        return allConversations.sorted { ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast) }
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
