import Foundation

// MARK: - Location

public struct Location: Codable, Identifiable, Hashable {
    public let id: UUID
    var storeId: UUID?
    var name: String
    var slug: String?
    var address: String?
    var city: String?
    var state: String?
    var zip: String?
    var phone: String?
    var email: String?
    var isActive: Bool?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, address, city, state, zip, phone, email
        case storeId = "store_id"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Conversation

public struct Conversation: Codable, Identifiable, Hashable {
    public let id: UUID
    var storeId: UUID?
    var userId: UUID?
    var title: String?
    var status: String?
    var messageCount: Int?
    var chatType: String?
    var locationId: UUID?
    var metadata: AnyCodable?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case userId = "user_id"
        case title, status
        case messageCount = "message_count"
        case chatType = "chat_type"
        case locationId = "location_id"
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }

    var displayTitle: String {
        title ?? chatTypeLabel
    }

    var chatTypeLabel: String {
        switch chatType {
        case "ai": return "AI Assistant"
        case "dm": return "Direct Message"
        case "location": return "Location Chat"
        case "alerts": return "Alerts"
        case "bugs": return "Bug Reports"
        default: return "Chat"
        }
    }

    var chatTypeIcon: String {
        switch chatType {
        case "ai": return "sparkles"
        case "dm": return "person.2"
        case "location": return "mappin.and.ellipse"
        case "alerts": return "bell"
        case "bugs": return "ladybug"
        default: return "bubble.left"
        }
    }
}

// MARK: - Message

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: UUID
    var conversationId: UUID
    var role: String
    var content: String
    var toolCalls: AnyCodable?
    var tokensUsed: Int?
    var senderId: UUID?
    var isAiInvocation: Bool?
    var aiPrompt: String?
    var replyToMessageId: UUID?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role, content
        case toolCalls = "tool_calls"
        case tokensUsed = "tokens_used"
        case senderId = "sender_id"
        case isAiInvocation = "is_ai_invocation"
        case aiPrompt = "ai_prompt"
        case replyToMessageId = "reply_to_message_id"
        case createdAt = "created_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }

    var isFromUser: Bool {
        role == "user"
    }

    var isFromAssistant: Bool {
        role == "assistant"
    }
}

// MARK: - Message Insert

struct ChatMessageInsert: Codable {
    var conversationId: UUID
    var role: String
    var content: String
    var senderId: UUID?
    var isAiInvocation: Bool?
    var replyToMessageId: UUID?

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case role, content
        case senderId = "sender_id"
        case isAiInvocation = "is_ai_invocation"
        case replyToMessageId = "reply_to_message_id"
    }
}

// MARK: - Conversation Insert

struct ConversationInsert: Codable {
    var storeId: UUID
    var userId: UUID?
    var title: String?
    var chatType: String?
    var locationId: UUID?

    enum CodingKeys: String, CodingKey {
        case storeId = "store_id"
        case userId = "user_id"
        case title
        case chatType = "chat_type"
        case locationId = "location_id"
    }
}

// MARK: - Chat Participant

struct ChatParticipant: Codable, Identifiable, Hashable {
    let id: UUID
    var conversationId: UUID
    var userId: UUID
    var role: String?
    var lastReadAt: Date?
    var lastReadMessageId: UUID?
    var notificationsEnabled: Bool?
    var isMuted: Bool?
    var mutedUntil: Date?
    var isTyping: Bool?
    var typingStartedAt: Date?
    var joinedAt: Date?
    var leftAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case role
        case lastReadAt = "last_read_at"
        case lastReadMessageId = "last_read_message_id"
        case notificationsEnabled = "notifications_enabled"
        case isMuted = "is_muted"
        case mutedUntil = "muted_until"
        case isTyping = "is_typing"
        case typingStartedAt = "typing_started_at"
        case joinedAt = "joined_at"
        case leftAt = "left_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ChatParticipant, rhs: ChatParticipant) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - User Profile (for message senders)

struct UserProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var email: String?
    var fullName: String?
    var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.id == rhs.id
    }

    var displayName: String {
        fullName ?? email ?? "User"
    }

    var initials: String {
        let name = displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
