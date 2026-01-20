import SwiftUI

// MARK: - EditorStore MCP Servers Extension
// Following Apple engineering standards
// Handles MCP server operations and tab management

extension EditorStore {
    // MARK: - MCP Server Operations

    /// Load all MCP servers from ai_tool_registry
    func loadMCPServers() async {
        isLoading = true
        do {
            let response = try await supabase.client
                .from("ai_tool_registry")
                .select()
                .eq("is_active", value: true)
                .order("name")
                .execute()

            // Log raw response for debugging
            if let jsonString = String(data: response.data, encoding: .utf8) {
                NSLog("[EditorStore] Raw response (first 500 chars): \(String(jsonString.prefix(500)))")
            }

            NSLog("[EditorStore] Response data size: \(response.data.count) bytes")

            let decoder = JSONDecoder.supabaseDecoder
            mcpServers = try decoder.decode([MCPServer].self, from: response.data)

            NSLog("[EditorStore] Loaded \(mcpServers.count) MCP servers")
        } catch let DecodingError.keyNotFound(key, context) {
            self.error = "Missing key '\(key.stringValue)' at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            NSLog("[EditorStore] Decoding error - missing key: \(key.stringValue)")
            NSLog("[EditorStore] Context: \(context.debugDescription)")
        } catch let DecodingError.typeMismatch(type, context) {
            self.error = "Type mismatch for \(type) at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            NSLog("[EditorStore] Decoding error - type mismatch: \(type)")
            NSLog("[EditorStore] Context: \(context.debugDescription)")
        } catch let DecodingError.valueNotFound(type, context) {
            self.error = "Value not found for \(type) at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            NSLog("[EditorStore] Decoding error - value not found: \(type)")
            NSLog("[EditorStore] Context: \(context.debugDescription)")
        } catch {
            self.error = "Failed to load MCP servers: \(error.localizedDescription)"
            NSLog("[EditorStore] Error loading MCP servers: \(error)")
        }
        isLoading = false
    }

    /// Open MCP server in a new tab
    func openMCPServer(_ server: MCPServer) {
        selectedMCPServer = server
        let tabItem = OpenTabItem.mcpServer(server)

        // Add to tabs if not already open
        if !openTabs.contains(tabItem) {
            openTabs.append(tabItem)
        }

        // Set as active tab
        activeTab = tabItem
    }

    /// Close MCP server tab
    func closeMCPServer(_ server: MCPServer) {
        let tabItem = OpenTabItem.mcpServer(server)
        if let index = openTabs.firstIndex(of: tabItem) {
            openTabs.remove(at: index)

            // If this was the active tab, switch to another
            if activeTab == tabItem {
                if index < openTabs.count {
                    activeTab = openTabs[index]
                } else if !openTabs.isEmpty {
                    activeTab = openTabs.last
                } else {
                    activeTab = nil
                }
            }
        }

        // Clear selection if this was the selected server
        if selectedMCPServer?.id == server.id {
            selectedMCPServer = nil
        }
    }

    /// Get MCP servers by category
    func mcpServersByCategory(_ category: String) -> [MCPServer] {
        mcpServers.filter { $0.category == category }
    }

    /// Get all unique categories from MCP servers
    var mcpServerCategories: [String] {
        Array(Set(mcpServers.map { $0.category })).sorted()
    }
}
