import SwiftUI

// MARK: - EditorStore MCP Servers Extension
// Following Apple engineering standards
// Handles MCP server operations and tab management

extension EditorStore {
    // MARK: - MCP Server Operations

    /// Load all MCP servers from ai_tool_registry
    func loadMCPServers() async {
        await MainActor.run { isLoadingMCPServers = true }

        do {
            let response = try await supabase.client
                .from("ai_tool_registry")
                .select("*")
                .eq("is_active", value: true)
                .order("name")
                .execute()

            // Log raw response for debugging
            if let jsonString = String(data: response.data, encoding: .utf8),
               let jsonData = jsonString.data(using: .utf8),
               let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]],
               let firstServer = jsonArray.first {
                NSLog("[EditorStore] 🔍 First server raw JSON keys: \(firstServer.keys.sorted().joined(separator: ", "))")
                NSLog("[EditorStore] 🔍 rpc_function = \(firstServer["rpc_function"] ?? "NULL")")
                NSLog("[EditorStore] 🔍 edge_function = \(firstServer["edge_function"] ?? "NULL")")
                NSLog("[EditorStore] 🔍 tool_mode = \(firstServer["tool_mode"] ?? "NULL")")
            }

            let decoder = JSONDecoder.supabaseDecoder
            let decodedServers = try decoder.decode([MCPServer].self, from: response.data)

            NSLog("[EditorStore] Loaded \(decodedServers.count) MCP servers")

            // Log details of first few servers to debug rpcFunction/edgeFunction
            for (index, server) in decodedServers.prefix(5).enumerated() {
                NSLog("[EditorStore] Server[\(index)] name=\(server.name), rpcFunction=\(server.rpcFunction ?? "nil"), edgeFunction=\(server.edgeFunction ?? "nil"), category=\(server.category)")
            }

            await MainActor.run {
                mcpServers = decodedServers
                isLoadingMCPServers = false
            }
        } catch let DecodingError.keyNotFound(key, context) {
            await MainActor.run {
                self.error = "Missing key '\(key.stringValue)' at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                isLoadingMCPServers = false
            }
            NSLog("[EditorStore] Decoding error - missing key: \(key.stringValue)")
            NSLog("[EditorStore] Context: \(context.debugDescription)")
        } catch let DecodingError.typeMismatch(type, context) {
            await MainActor.run {
                self.error = "Type mismatch for \(type) at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                isLoadingMCPServers = false
            }
            NSLog("[EditorStore] Decoding error - type mismatch: \(type)")
            NSLog("[EditorStore] Context: \(context.debugDescription)")
        } catch let DecodingError.valueNotFound(type, context) {
            await MainActor.run {
                self.error = "Value not found for \(type) at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                isLoadingMCPServers = false
            }
            NSLog("[EditorStore] Decoding error - value not found: \(type)")
            NSLog("[EditorStore] Context: \(context.debugDescription)")
        } catch {
            await MainActor.run {
                self.error = "Failed to load MCP servers: \(error.localizedDescription)"
                isLoadingMCPServers = false
            }
            NSLog("[EditorStore] Error loading MCP servers: \(error)")
        }
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
