import Foundation
import Supabase

// MARK: - MCP Editor
// Business logic for creating/editing MCP servers

@MainActor
class MCPEditor: ObservableObject {
    @Published var name: String = ""
    @Published var category: String = ""
    @Published var description: String = ""
    @Published var toolMode: String = "ops"
    @Published var rpcFunction: String = ""
    @Published var edgeFunction: String = ""
    @Published var requiresUserId: Bool = false
    @Published var requiresStoreId: Bool = true
    @Published var isReadOnly: Bool = false
    @Published var isActive: Bool = true
    @Published var definitionJSON: String = defaultDefinitionJSON
    @Published var jsonValidated: Bool = false
    @Published var jsonValidationError: String?
    @Published var isSaving: Bool = false

    private var serverId: UUID?
    private let supabase = SupabaseService.shared

    var isValid: Bool {
        !name.isEmpty && !category.isEmpty && jsonValidated
    }

    func load(_ server: MCPServer) {
        self.serverId = server.id
        self.name = server.name
        self.category = server.category
        self.description = server.description ?? ""
        self.toolMode = server.toolMode ?? "ops"
        self.rpcFunction = server.rpcFunction ?? ""
        self.edgeFunction = server.edgeFunction ?? ""
        self.requiresUserId = server.requiresUserId ?? false
        self.requiresStoreId = server.requiresStoreId ?? true
        self.isReadOnly = server.isReadOnly ?? false
        self.isActive = server.isActive ?? true

        // Convert definition to JSON
        if let data = try? JSONEncoder().encode(server.definition),
           let json = String(data: data, encoding: .utf8) {
            self.definitionJSON = json
            formatJSON()
        }
    }

    func validateJSON() {
        do {
            guard let data = definitionJSON.data(using: .utf8) else {
                throw NSError(domain: "MCPEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 encoding"])
            }

            let _ = try JSONSerialization.jsonObject(with: data)
            jsonValidated = true
            jsonValidationError = nil
        } catch {
            jsonValidated = false
            jsonValidationError = error.localizedDescription
        }
    }

    func formatJSON() {
        guard let data = definitionJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: formatted, encoding: .utf8) else {
            return
        }

        definitionJSON = string
        validateJSON()
    }

    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            validateJSON()
            guard jsonValidated else {
                throw NSError(domain: "MCPEditor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON definition"])
            }

            // Parse definition JSON
            guard let definitionData = definitionJSON.data(using: .utf8),
                  let definitionDict = try JSONSerialization.jsonObject(with: definitionData) as? [String: Any] else {
                throw NSError(domain: "MCPEditor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse definition"])
            }

            // Build JSON body manually
            var jsonDict: [String: Any] = [
                "name": name,
                "category": category,
                "description": description,
                "tool_mode": toolMode,
                "definition": definitionDict,
                "requires_user_id": requiresUserId,
                "requires_store_id": requiresStoreId,
                "is_read_only": isReadOnly,
                "is_active": isActive
            ]

            if !rpcFunction.isEmpty {
                jsonDict["rpc_function"] = rpcFunction
            }

            if !edgeFunction.isEmpty {
                jsonDict["edge_function"] = edgeFunction
            }

            if let serverId = serverId {
                // Update existing
                jsonDict["id"] = serverId.uuidString
            }

            // Convert to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)

            // Use raw HTTP POST to Supabase REST API
            let supabaseURL = SupabaseConfig.url.absoluteString
            let apiKey = SupabaseConfig.anonKey

            let urlString = "\(supabaseURL)/rest/v1/ai_tool_registry"
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "MCPEditor", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }

            var request = URLRequest(url: url)
            request.httpMethod = serverId == nil ? "POST" : "PATCH"
            request.httpBody = jsonData
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")

            if serverId != nil {
                request.url = URL(string: "\(urlString)?id=eq.\(serverId!.uuidString)")
            }

            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "MCPEditor", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
                NSLog("[MCPEditor] HTTP error \(httpResponse.statusCode): \(errorMessage)")
                throw NSError(domain: "MCPEditor", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Save failed: \(errorMessage)"])
            }

            NSLog("[MCPEditor] Successfully saved MCP server: \(name)")
            return true
        } catch {
            NSLog("[MCPEditor] Error saving: \(error)")
            jsonValidationError = error.localizedDescription
            return false
        }
    }

    private static let defaultDefinitionJSON = """
    {
      "name": "my_tool",
      "type": "custom",
      "description": "Description of what this tool does",
      "input_schema": {
        "type": "object",
        "required": [],
        "properties": {
          "param1": {
            "type": "string",
            "description": "First parameter"
          }
        }
      }
    }
    """
}
