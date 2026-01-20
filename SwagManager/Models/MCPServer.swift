import Foundation

// MARK: - MCP Server Model
// Represents an MCP (Model Context Protocol) server/tool from ai_tool_registry

struct MCPServer: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: String
    let definition: MCPDefinition
    let description: String?
    let rpcFunction: String?
    let requiresUserId: Bool?
    let requiresStoreId: Bool?
    let isReadOnly: Bool?
    let isActive: Bool?
    let version: Int?
    let createdAt: Date?
    let updatedAt: Date?
    let edgeFunction: String?
    let toolMode: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case definition
        case description
        case rpcFunction = "rpc_function"
        case requiresUserId = "requires_user_id"
        case requiresStoreId = "requires_store_id"
        case isReadOnly = "is_read_only"
        case isActive = "is_active"
        case version
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case edgeFunction = "edge_function"
        case toolMode = "tool_mode"
    }
}

// MARK: - MCP Definition
struct MCPDefinition: Codable, Hashable {
    let name: String
    let type: String
    let description: String
    let inputSchema: InputSchema?

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case description
        case inputSchema = "input_schema"
    }
}

// MARK: - Input Schema
struct InputSchema: Codable, Hashable {
    let type: String
    let required: [String]?
    let properties: [String: PropertyDefinition]?
}

// MARK: - Property Definition
struct PropertyDefinition: Codable, Hashable {
    let type: String
    let description: String?
    let `default`: AnyCodableValue?
    let `enum`: [String]?
    let items: PropertyItems?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case `default`
        case `enum`
        case items
    }
}

// MARK: - Property Items (for array types)
struct PropertyItems: Codable, Hashable {
    let type: String
    let required: [String]?
    let properties: [String: PropertyDefinition]?
    let description: String?
}

// MARK: - Any Codable Value
enum AnyCodableValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(
                AnyCodableValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return String(value)
        case .null: return "null"
        }
    }
}
