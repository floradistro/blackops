import Foundation

// MARK: - AI Agent Model
// Represents an AI agent from ai_agent_config table

struct AIAgent: Codable, Identifiable, Hashable {
    let id: UUID
    let storeId: UUID?
    var name: String?
    var description: String?
    var icon: String?
    var accentColor: String?
    var systemPrompt: String?
    var model: String?
    var maxToolCalls: Int?
    var maxTokens: Int?
    var version: Int?
    var isActive: Bool
    let createdAt: Date?
    var updatedAt: Date?

    // Deployment status
    var status: String?  // draft, published, archived
    var publishedAt: Date?
    var publishedBy: UUID?

    // Agent Builder fields
    var enabledTools: [String]?  // Array of tool IDs (UUIDs as strings)
    var temperature: Double?
    var tone: String?
    var verbosity: String?
    var canQuery: Bool?
    var canSend: Bool?
    var canModify: Bool?
    var apiKey: String?  // Anthropic API key for this agent

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case name
        case description
        case icon
        case accentColor = "accent_color"
        case systemPrompt = "system_prompt"
        case model
        case maxToolCalls = "max_tool_calls"
        case maxTokens = "max_tokens"
        case version
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case status
        case publishedAt = "published_at"
        case publishedBy = "published_by"
        case enabledTools = "enabled_tools"
        case temperature
        case tone
        case verbosity
        case canQuery = "can_query"
        case canSend = "can_send"
        case canModify = "can_modify"
        case apiKey = "api_key"
    }

    // Memberwise initializer
    init(
        id: UUID,
        storeId: UUID?,
        name: String?,
        description: String?,
        systemPrompt: String?,
        model: String?,
        maxTokens: Int?,
        maxToolCalls: Int?,
        icon: String?,
        accentColor: String?,
        isActive: Bool,
        version: Int?,
        createdAt: Date?,
        updatedAt: Date?,
        status: String? = "draft",
        publishedAt: Date? = nil,
        publishedBy: UUID? = nil,
        enabledTools: [String]? = nil,
        temperature: Double? = 0.7,
        tone: String? = "professional",
        verbosity: String? = "moderate",
        canQuery: Bool? = true,
        canSend: Bool? = false,
        canModify: Bool? = false
    ) {
        self.id = id
        self.storeId = storeId
        self.name = name
        self.description = description
        self.systemPrompt = systemPrompt
        self.model = model
        self.maxTokens = maxTokens
        self.maxToolCalls = maxToolCalls
        self.icon = icon
        self.accentColor = accentColor
        self.isActive = isActive
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.publishedAt = publishedAt
        self.publishedBy = publishedBy
        self.enabledTools = enabledTools
        self.temperature = temperature
        self.tone = tone
        self.verbosity = verbosity
        self.canQuery = canQuery
        self.canSend = canSend
        self.canModify = canModify
    }

    // Computed properties for status
    var isDraft: Bool {
        status == "draft" || status == nil
    }

    var isPublished: Bool {
        status == "published"
    }

    var isArchived: Bool {
        status == "archived"
    }

    var statusDisplayName: String {
        (status ?? "draft").capitalized
    }

    // Display name - use stored name only
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return "Untitled Agent"
    }

    // Display icon
    var displayIcon: String {
        icon ?? "cpu"
    }

    // Display color
    var displayColor: String {
        accentColor ?? "blue"
    }

    // Short description
    var shortDescription: String {
        description ?? "AI Agent"
    }
}

