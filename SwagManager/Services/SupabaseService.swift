import Foundation
import Supabase
import Auth

// MARK: - Supabase Configuration

enum SupabaseConfig {
    // Production: floradistro.com
    static let url = URL(string: "https://uaednwpxursknmwdeejn.supabase.co")!

    // Anon key - safe for client-side use (RLS protects data)
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg"

    // Service role key - for local agent server only (bypasses RLS)
    // NOTE: This runs locally, not exposed to network
    static let serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI"
}

// MARK: - UserDefaults Auth Storage (avoids Keychain prompts during development)

final class UserDefaultsAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let defaults = UserDefaults.standard
    private let keyPrefix = "supabase.auth."

    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: keyPrefix + key)
    }

    func retrieve(key: String) throws -> Data? {
        defaults.data(forKey: keyPrefix + key)
    }

    func remove(key: String) throws {
        defaults.removeObject(forKey: keyPrefix + key)
    }
}

// MARK: - Supabase Service Coordinator

@MainActor
class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    // Admin client - uses service role key for privileged operations (bypasses RLS)
    // ONLY use for local admin operations, NEVER expose to network
    let adminClient: SupabaseClient

    // Service instances
    private(set) lazy var chat = ChatService(client: client)

    private init() {
        // Using anon key - RLS policies enforce security
        // Using UserDefaults storage to avoid Keychain password prompts during development
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(
                auth: .init(
                    storage: UserDefaultsAuthLocalStorage(),
                    flowType: .implicit,
                    autoRefreshToken: true,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )

        // Admin client with service role key - bypasses RLS
        // Used for agent config and other admin operations that run locally
        adminClient = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.serviceRoleKey
        )
    }

    // MARK: - Stores

    func fetchStores(limit: Int = 100) async throws -> [Store] {
        try await client.from("stores")
            .select()
            .limit(limit)
            .execute()
            .value
    }

    func fetchStore(id: UUID) async throws -> Store {
        try await client.from("stores")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createStore(_ store: StoreInsert) async throws -> Store {
        try await client.from("stores")
            .insert(store)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Locations

    func fetchLocations(storeId: UUID) async throws -> [Location] {
        try await client.from("locations")
            .select()
            .eq("store_id", value: storeId)
            .order("name")
            .execute()
            .value
    }

    // MARK: - Catalogs

    func fetchCatalogs(storeId: UUID) async throws -> [Catalog] {
        try await client.from("catalogs")
            .select()
            .eq("store_id", value: storeId)
            .order("name")
            .execute()
            .value
    }

    func fetchCatalog(id: UUID) async throws -> Catalog {
        try await client.from("catalogs")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createCatalog(_ catalog: CatalogInsert) async throws -> Catalog {
        try await client.from("catalogs")
            .insert(catalog)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteCatalog(id: UUID) async throws {
        try await client.from("catalogs")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Categories

    func fetchCategories(storeId: UUID? = nil, catalogId: UUID? = nil) async throws -> [Category] {
        var query = client.from("categories").select()

        if let storeId = storeId {
            query = query.eq("store_id", value: storeId)
        }
        if let catalogId = catalogId {
            query = query.eq("catalog_id", value: catalogId)
        }

        return try await query
            .order("name")
            .execute()
            .value
    }

    func fetchCategory(id: UUID) async throws -> Category {
        try await client.from("categories")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createCategory(_ category: CategoryInsert) async throws -> Category {
        try await client.from("categories")
            .insert(category)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteCategory(id: UUID) async throws {
        try await client.from("categories")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Chat

    func fetchConversations(storeId: UUID, chatType: String? = nil) async throws -> [Conversation] {
        try await chat.fetchConversations(storeId: storeId, chatType: chatType)
    }

    func fetchConversation(id: UUID) async throws -> Conversation {
        try await chat.fetchConversation(id: id)
    }

    func fetchConversationsByLocation(locationId: UUID) async throws -> [Conversation] {
        try await chat.fetchConversationsByLocation(locationId: locationId)
    }

    func fetchAllConversationsForStoreLocations(storeId: UUID, fetchLocations: @escaping (UUID) async throws -> [Location]) async throws -> [Conversation] {
        try await chat.fetchAllConversationsForStoreLocations(storeId: storeId, fetchLocations: fetchLocations)
    }

    func createConversation(_ conversation: ConversationInsert) async throws -> Conversation {
        try await chat.createConversation(conversation)
    }

    func getOrCreateTeamConversation(storeId: UUID, chatType: String, title: String) async throws -> Conversation {
        try await chat.getOrCreateTeamConversation(storeId: storeId, chatType: chatType, title: title)
    }

    func fetchMessages(conversationId: UUID, limit: Int = 50, before: Date? = nil) async throws -> [ChatMessage] {
        try await chat.fetchMessages(conversationId: conversationId, limit: limit, before: before)
    }

    func sendMessage(_ message: ChatMessageInsert) async throws -> ChatMessage {
        try await chat.sendMessage(message)
    }

    func fetchParticipants(conversationId: UUID) async throws -> [ChatParticipant] {
        try await chat.fetchParticipants(conversationId: conversationId)
    }

    func updateTypingStatus(conversationId: UUID, userId: UUID, isTyping: Bool) async throws {
        try await chat.updateTypingStatus(conversationId: conversationId, userId: userId, isTyping: isTyping)
    }

    func markMessagesRead(conversationId: UUID, userId: UUID, lastMessageId: UUID) async throws {
        try await chat.markMessagesRead(conversationId: conversationId, userId: userId, lastMessageId: lastMessageId)
    }

    func messagesChannel(conversationId: UUID) -> RealtimeChannelV2 {
        chat.messagesChannel(conversationId: conversationId)
    }
}
