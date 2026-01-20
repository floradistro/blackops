import Foundation

// MARK: - EditorStore+MCPManagement
// MCP server management functionality for EditorStore

extension EditorStore {
    // MARK: - Load MCP Servers

    func loadMCPServers() async {
        do {
            isLoading = true

            // Load from .claude.json
            let config = try await loadClaudeConfig()
            var servers: [MCPServer] = []

            for (name, serverConfig) in config.mcpServers {
                let server = MCPServer(
                    name: name,
                    command: serverConfig.command,
                    args: serverConfig.args ?? [],
                    env: serverConfig.env,
                    serverType: detectServerType(command: serverConfig.command),
                    status: .unknown,
                    enabled: !(serverConfig.disabled ?? false),
                    description: nil
                )
                servers.append(server)
            }

            mcpServers = servers
            print("✅ Loaded \(mcpServers.count) MCP servers")

            // Check status of all servers
            await refreshAllServerStatus()
        } catch {
            print("❌ Error loading MCP servers: \(error)")

            // Load sample data for development
            mcpServers = MCPServer.samples
            self.error = "Using sample MCP data: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Server Actions

    func startMCPServer(_ server: MCPServer) async {
        guard let index = mcpServers.firstIndex(where: { $0.id == server.id }) else {
            return
        }

        mcpServers[index].status = .starting

        // TODO: Implement actual server start logic
        // For now, simulate starting
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        mcpServers[index].status = .running
        mcpServers[index].lastHealthCheck = Date()
        mcpServers[index].lastError = nil

        print("✅ Started MCP server: \(server.name)")
    }

    func stopMCPServer(_ server: MCPServer) async {
        guard let index = mcpServers.firstIndex(where: { $0.id == server.id }) else {
            return
        }

        // TODO: Implement actual server stop logic
        mcpServers[index].status = .stopped
        mcpServers[index].lastHealthCheck = nil

        print("✅ Stopped MCP server: \(server.name)")
    }

    func restartMCPServer(_ server: MCPServer) async {
        await stopMCPServer(server)
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        await startMCPServer(server)
    }

    func toggleMCPServer(_ server: MCPServer) async {
        guard let index = mcpServers.firstIndex(where: { $0.id == server.id }) else {
            return
        }

        mcpServers[index].enabled.toggle()

        // Update .claude.json
        await saveClaudeConfig()

        if !mcpServers[index].enabled && mcpServers[index].status == .running {
            await stopMCPServer(server)
        }
    }

    func deleteMCPServer(_ server: MCPServer) async {
        // Stop if running
        if server.status == .running {
            await stopMCPServer(server)
        }

        // Remove from list
        mcpServers.removeAll(where: { $0.id == server.id })

        // Update .claude.json
        await saveClaudeConfig()

        print("✅ Deleted MCP server: \(server.name)")
    }

    // MARK: - Server Status

    func refreshAllServerStatus() async {
        await withTaskGroup(of: Void.self) { group in
            for server in mcpServers {
                group.addTask {
                    await self.checkServerHealth(server)
                }
            }
        }
    }

    func checkServerHealth(_ server: MCPServer) async {
        guard let index = mcpServers.firstIndex(where: { $0.id == server.id }) else {
            return
        }

        // TODO: Implement actual health check logic
        // For now, simulate health check
        mcpServers[index].lastHealthCheck = Date()

        // Randomly set status for development
        if server.enabled {
            // Keep current status if already set, otherwise set to stopped
            if mcpServers[index].status == .unknown {
                mcpServers[index].status = .stopped
            }
        } else {
            mcpServers[index].status = .stopped
        }
    }

    // MARK: - Configuration Management

    private func loadClaudeConfig() async throws -> MCPConfiguration {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configPath = homeDir.appendingPathComponent(".claude.json")

        let data = try Data(contentsOf: configPath)
        let decoder = JSONDecoder()
        return try decoder.decode(MCPConfiguration.self, from: data)
    }

    private func saveClaudeConfig() async {
        do {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let configPath = homeDir.appendingPathComponent(".claude.json")

            // Convert current servers to config format
            var mcpServersConfig: [String: MCPServerConfig] = [:]
            for server in mcpServers {
                mcpServersConfig[server.name] = MCPServerConfig(
                    command: server.command,
                    args: server.args.isEmpty ? nil : server.args,
                    env: server.env,
                    disabled: !server.enabled ? true : nil
                )
            }

            let config = MCPConfiguration(mcpServers: mcpServersConfig)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)

            try data.write(to: configPath)
            print("✅ Saved MCP configuration to \(configPath.path)")
        } catch {
            print("❌ Error saving MCP configuration: \(error)")
            self.error = "Failed to save MCP configuration: \(error.localizedDescription)"
        }
    }

    // MARK: - Server Management

    func createMCPServer(
        name: String,
        command: String,
        args: [String],
        env: [String: String]? = nil,
        serverType: MCPServerType,
        autoStart: Bool = false
    ) async {
        let server = MCPServer(
            name: name,
            command: command,
            args: args,
            env: env,
            serverType: serverType,
            status: .stopped,
            enabled: true,
            autoStart: autoStart
        )

        mcpServers.append(server)

        // Save to .claude.json
        await saveClaudeConfig()

        print("✅ Created MCP server: \(name)")

        if autoStart {
            await startMCPServer(server)
        }
    }

    func updateMCPServer(
        _ server: MCPServer,
        name: String? = nil,
        command: String? = nil,
        args: [String]? = nil,
        env: [String: String]? = nil
    ) async {
        guard let index = mcpServers.firstIndex(where: { $0.id == server.id }) else {
            return
        }

        if let name = name {
            mcpServers[index].name = name
        }
        if let command = command {
            mcpServers[index].command = command
        }
        if let args = args {
            mcpServers[index].args = args
        }
        if let env = env {
            mcpServers[index].env = env
        }

        mcpServers[index].updatedAt = Date()

        // Save to .claude.json
        await saveClaudeConfig()

        print("✅ Updated MCP server: \(server.name)")
    }

    // MARK: - Helpers

    private func detectServerType(command: String) -> MCPServerType {
        if command.contains("npx") || command.contains("node") {
            return .node
        } else if command.contains("python") || command.contains("python3") {
            return .python
        } else if command.contains("docker") {
            return .docker
        } else if command.hasPrefix("/") {
            return .binary
        } else {
            return .custom
        }
    }

    // MARK: - Tab Management

    func openMCPServerTab(_ server: MCPServer) {
        selectedMCPServer = server
        let tab = OpenTabItem.mcpServer(server)

        if !openTabs.contains(where: { $0.id == tab.id }) {
            openTabs.append(tab)
        }

        activeTab = tab
    }

    func closeMCPServerTab(_ server: MCPServer) {
        let tabId = "mcp-\(server.id)"
        openTabs.removeAll(where: { $0.id == tabId })

        if activeTab?.id == tabId {
            activeTab = openTabs.last
        }

        if selectedMCPServer?.id == server.id {
            selectedMCPServer = nil
        }
    }
}
