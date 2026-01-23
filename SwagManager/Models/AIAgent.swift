import Foundation

// MARK: - AI Agent Model
// Represents an AI agent from ai_agent_config table

struct AIAgent: Codable, Identifiable, Hashable {
    let id: UUID
    let storeId: UUID?
    let name: String?
    let description: String?
    let icon: String?
    let accentColor: String?
    let systemPrompt: String?
    let model: String?
    let maxToolCalls: Int?
    let maxTokens: Int?
    let version: Int?
    let isActive: Bool
    let createdAt: Date?
    let updatedAt: Date?

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
        updatedAt: Date?
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
    }

    // Display name - use stored name or parse from prompt
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        // Fallback: parse from system prompt
        if let prompt = systemPrompt?.lowercased() {
            if prompt.contains("you are lisa") {
                return "Lisa"
            } else if prompt.contains("you are wilson") {
                return "Wilson"
            }
        }
        return "AI Agent"
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
