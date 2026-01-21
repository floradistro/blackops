import SwiftUI
import Supabase

// MARK: - Agent Builder Store
// Manages state for the visual agent builder

@MainActor
class AgentBuilderStore: ObservableObject {
    // Current agent being edited
    @Published var currentAgent: AgentConfiguration?

    // Source list data
    @Published var mcpTools: [MCPServer] = []
    @Published var products: [AgentProduct] = []
    @Published var locations: [StoreLocation] = []
    @Published var customerSegments: [CustomerSegment] = []
    @Published var promptTemplates: [PromptTemplate] = []

    // UI State
    @Published var searchQuery = ""
    @Published var expandedCategories: Set<String> = []
    @Published var toolsSectionExpanded = true
    @Published var contextSectionExpanded = true
    @Published var templatesSectionExpanded = true

    // Test state
    @Published var testPrompt = ""
    @Published var isRunningTest = false
    @Published var testResult: String?

    private let supabase = SupabaseService.shared

    // MARK: - Load Resources

    func loadResources(editorStore: EditorStore) async {
        // Just reference existing data - don't load anything
        mcpTools = editorStore.mcpServers

        // Simple mock data for product categories
        products = []  // Don't load products - just use categories

        // Use existing locations
        locations = editorStore.locations.map { loc in
            StoreLocation(id: loc.id, name: loc.name, address: loc.address)
        }

        // Mock customer segments
        customerSegments = [
            CustomerSegment(name: "VIP Customers", count: 87, filter: "total_orders > 10"),
            CustomerSegment(name: "New Customers", count: 234, filter: "created_at > NOW() - INTERVAL '30 days'"),
            CustomerSegment(name: "Inactive", count: 156, filter: "last_order_at < NOW() - INTERVAL '90 days'")
        ]

        // Load prompt templates
        promptTemplates = [
            PromptTemplate(
                name: "Greeting",
                content: "Always greet customers warmly and professionally. Start with 'Hello! How can I help you today?'",
                description: "Standard customer greeting"
            ),
            PromptTemplate(
                name: "Apology",
                content: "If there's an issue with an order, apologize sincerely and offer to help resolve it immediately.",
                description: "Apologetic tone for issues"
            ),
            PromptTemplate(
                name: "Follow-up",
                content: "After resolving an issue, always ask if there's anything else you can help with.",
                description: "Follow-up after resolution"
            ),
            PromptTemplate(
                name: "Product Expert",
                content: "You have deep knowledge of all our products. When asked about products, provide detailed information including materials, sizing, and care instructions.",
                description: "Product expertise persona"
            ),
            PromptTemplate(
                name: "Sales Focus",
                content: "Your goal is to help customers find products they'll love. Suggest complementary items and mention any current promotions.",
                description: "Sales-oriented behavior"
            )
        ]
    }

    // MARK: - Agent Management

    func createNewAgent() {
        currentAgent = AgentConfiguration(
            id: UUID(),
            name: "Untitled Agent",
            description: nil,
            category: "general",
            systemPrompt: "You are a helpful AI assistant.",
            enabledTools: [],
            contextData: [],
            personality: AgentPersonality(
                tone: "professional",
                verbosity: "moderate",
                creativity: 0.7
            ),
            capabilities: AgentCapabilities(
                canQuery: true,
                canSend: false,
                canModify: false
            ),
            maxTokensPerResponse: 4096,
            maxTurnsPerConversation: 50,
            model: "claude-sonnet-4",
            temperature: 0.7
        )
    }

    func saveAgent() async {
        guard let agent = currentAgent else { return }

        do {
            // Convert to database format using Codable
            struct AgentInsert: Encodable {
                let id: String
                let name: String
                let description: String?
                let system_prompt: String
                let enabled_tools: [String]
                let enabled_categories: [String]
                let personality: Data?
                let max_tokens_per_response: Int
                let max_turns_per_conversation: Int
            }

            let insert = AgentInsert(
                id: agent.id.uuidString,
                name: agent.name,
                description: agent.description,
                system_prompt: agent.systemPrompt,
                enabled_tools: agent.enabledTools.map { $0.name },
                enabled_categories: agent.enabledTools.map { $0.category },
                personality: try? JSONEncoder().encode(agent.personality),
                max_tokens_per_response: agent.maxTokensPerResponse ?? 4096,
                max_turns_per_conversation: agent.maxTurnsPerConversation ?? 50
            )

            try await supabase.client
                .from("agents")
                .upsert(insert)
                .execute()

            NSLog("[AgentBuilder] Saved agent: \(agent.name)")
        } catch {
            NSLog("[AgentBuilder] Error saving agent: \(error)")
        }
    }

    // MARK: - Tool Management

    func addTool(_ tool: MCPServer) {
        guard var agent = currentAgent else { return }

        // Check if already added
        if agent.enabledTools.contains(where: { $0.name == tool.name }) {
            return
        }

        agent.enabledTools.append(AgentToolReference(
            name: tool.name,
            category: tool.category
        ))

        currentAgent = agent
    }

    func removeTool(_ toolName: String) {
        guard var agent = currentAgent else { return }
        agent.enabledTools.removeAll { $0.name == toolName }
        currentAgent = agent
    }

    func getTool(_ name: String) -> MCPServer? {
        mcpTools.first { $0.name == name }
    }

    // MARK: - Context Management

    func addContext(_ type: AgentContextType) {
        guard var agent = currentAgent else { return }

        let contextData: AgentContextData

        switch type {
        case .products:
            contextData = AgentContextData(
                id: UUID(),
                type: "products",
                title: "All Products",
                subtitle: "\(products.count) products",
                icon: "cube.fill",
                color: .blue,
                filter: nil
            )

        case .productCategory(let category):
            let count = productsInCategory(category).count
            contextData = AgentContextData(
                id: UUID(),
                type: "product_category",
                title: category,
                subtitle: "\(count) products",
                icon: "tag.fill",
                color: .blue,
                filter: ["category": category]
            )

        case .location(let location):
            contextData = AgentContextData(
                id: UUID(),
                type: "location",
                title: location.name,
                subtitle: location.address ?? "Store location",
                icon: "mappin.circle.fill",
                color: .green,
                filter: ["location_id": location.id.uuidString]
            )

        case .customers:
            contextData = AgentContextData(
                id: UUID(),
                type: "customers",
                title: "All Customers",
                subtitle: "Full customer database",
                icon: "person.2.fill",
                color: .purple,
                filter: nil
            )

        case .customerSegment(let segmentName):
            if let segment = customerSegments.first(where: { $0.name == segmentName }) {
                contextData = AgentContextData(
                    id: UUID(),
                    type: "customer_segment",
                    title: segment.name,
                    subtitle: "\(segment.count) customers",
                    icon: "person.crop.circle.fill",
                    color: .purple,
                    filter: ["segment": segment.filter]
                )
            } else {
                return
            }
        }

        // Check if already added
        if !agent.contextData.contains(where: { $0.type == contextData.type && $0.title == contextData.title }) {
            agent.contextData.append(contextData)
            currentAgent = agent
        }
    }

    func removeContext(_ id: UUID) {
        guard var agent = currentAgent else { return }
        agent.contextData.removeAll { $0.id == id }
        currentAgent = agent
    }

    // MARK: - Prompt Management

    func appendToSystemPrompt(_ template: PromptTemplate) {
        guard var agent = currentAgent else { return }
        agent.systemPrompt += "\n\n" + template.content
        currentAgent = agent
    }

    // MARK: - Property Updates

    func updateSystemPrompt(_ text: String) {
        guard var agent = currentAgent else { return }
        agent.systemPrompt = text
        currentAgent = agent
    }

    func updateName(_ name: String) {
        guard var agent = currentAgent else { return }
        agent.name = name
        currentAgent = agent
    }

    func updateDescription(_ description: String) {
        guard var agent = currentAgent else { return }
        agent.description = description.isEmpty ? nil : description
        currentAgent = agent
    }

    func updateCategory(_ category: String) {
        guard var agent = currentAgent else { return }
        agent.category = category
        currentAgent = agent
    }

    func updateTone(_ tone: String) {
        guard var agent = currentAgent else { return }
        agent.personality?.tone = tone
        currentAgent = agent
    }

    func updateCreativity(_ creativity: Double) {
        guard var agent = currentAgent else { return }
        agent.personality?.creativity = creativity
        currentAgent = agent
    }

    func updateVerbosity(_ verbosity: String) {
        guard var agent = currentAgent else { return }
        agent.personality?.verbosity = verbosity
        currentAgent = agent
    }

    func updateCanQuery(_ value: Bool) {
        guard var agent = currentAgent else { return }
        agent.capabilities.canQuery = value
        currentAgent = agent
    }

    func updateCanSend(_ value: Bool) {
        guard var agent = currentAgent else { return }
        agent.capabilities.canSend = value
        currentAgent = agent
    }

    func updateCanModify(_ value: Bool) {
        guard var agent = currentAgent else { return }
        agent.capabilities.canModify = value
        currentAgent = agent
    }

    func updateMaxTokens(_ value: Int) {
        guard var agent = currentAgent else { return }
        agent.maxTokensPerResponse = value
        currentAgent = agent
    }

    func updateMaxTurns(_ value: Int) {
        guard var agent = currentAgent else { return }
        agent.maxTurnsPerConversation = value
        currentAgent = agent
    }

    func updateModel(_ model: String) {
        guard var agent = currentAgent else { return }
        agent.model = model
        currentAgent = agent
    }

    func updateTemperature(_ temperature: Double) {
        guard var agent = currentAgent else { return }
        agent.temperature = temperature
        currentAgent = agent
    }

    // MARK: - Testing

    func runTest() async {
        guard let agent = currentAgent else { return }

        isRunningTest = true
        testResult = nil

        // Simulate agent execution
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        testResult = """
        Agent Response:

        I understand you're asking about \(testPrompt). Let me help you with that.

        [Agent would use tools: \(agent.enabledTools.map { $0.name }.joined(separator: ", "))]
        [With context: \(agent.contextData.map { $0.title }.joined(separator: ", "))]

        This is a test response. In production, the agent would actually execute these tools and provide real results.
        """

        isRunningTest = false
    }

    // MARK: - Filtering & Search

    var filteredToolCategories: [String] {
        let allCategories = Set(mcpTools.map { $0.category })

        if searchQuery.isEmpty {
            return Array(allCategories).sorted()
        }

        return allCategories.filter { category in
            category.localizedCaseInsensitiveContains(searchQuery) ||
            tools(for: category).contains { tool in
                tool.name.localizedCaseInsensitiveContains(searchQuery)
            }
        }.sorted()
    }

    func tools(for category: String) -> [MCPServer] {
        let categoryTools = mcpTools.filter { $0.category == category }

        if searchQuery.isEmpty {
            return categoryTools
        }

        return categoryTools.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var productCategories: [String] {
        Array(Set(products.compactMap { $0.category })).sorted()
    }

    func productsInCategory(_ category: String) -> [AgentProduct] {
        products.filter { $0.category == category }
    }
}

// MARK: - Models

struct AgentConfiguration: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String?
    var category: String?
    var systemPrompt: String
    var enabledTools: [AgentToolReference]
    var contextData: [AgentContextData]
    var personality: AgentPersonality?
    var capabilities: AgentCapabilities
    var maxTokensPerResponse: Int?
    var maxTurnsPerConversation: Int?
    var model: String?
    var temperature: Double?
}

struct AgentToolReference: Identifiable, Codable {
    var id: String { name }
    let name: String
    let category: String
}

struct AgentContextData: Identifiable, Codable {
    let id: UUID
    let type: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let filter: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id, type, title, subtitle, icon, filter
    }

    init(id: UUID, type: String, title: String, subtitle: String, icon: String, color: Color, filter: [String: String]?) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.filter = filter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        icon = try container.decode(String.self, forKey: .icon)
        color = .blue // Default, not stored
        filter = try container.decodeIfPresent([String: String].self, forKey: .filter)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(icon, forKey: .icon)
        try container.encodeIfPresent(filter, forKey: .filter)
    }
}

struct AgentPersonality: Codable {
    var tone: String
    var verbosity: String
    var creativity: Double
}

struct AgentCapabilities: Codable {
    var canQuery: Bool
    var canSend: Bool
    var canModify: Bool
}

struct CustomerSegment {
    let name: String
    let count: Int
    let filter: String
}

struct PromptTemplate: Identifiable, Codable {
    let id = UUID()
    let name: String
    let content: String
    let description: String?
}

struct StoreLocation: Identifiable, Codable {
    let id: UUID
    let name: String
    let address: String?
}

// Simplified Product model for builder
struct AgentProduct: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: String?
    let price: Decimal?
}
