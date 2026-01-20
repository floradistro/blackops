//
//  MCPServer.swift
//  SwagManager
//
//  MCP (Model Context Protocol) server model for managing Claude integrations
//

import Foundation
import SwiftUI

// MARK: - MCP Server Model

struct MCPServer: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var command: String
    var args: [String]
    var env: [String: String]?
    var serverType: MCPServerType
    var status: MCPServerStatus
    var enabled: Bool
    var autoStart: Bool
    var description: String?
    var icon: String?
    var lastHealthCheck: Date?
    var lastError: String?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        args: [String] = [],
        env: [String: String]? = nil,
        serverType: MCPServerType = .node,
        status: MCPServerStatus = .stopped,
        enabled: Bool = true,
        autoStart: Bool = false,
        description: String? = nil,
        icon: String? = nil,
        lastHealthCheck: Date? = nil,
        lastError: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.serverType = serverType
        self.status = status
        self.enabled = enabled
        self.autoStart = autoStart
        self.description = description
        self.icon = icon
        self.lastHealthCheck = lastHealthCheck
        self.lastError = lastError
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    var displayName: String {
        name.isEmpty ? "Unnamed Server" : name
    }

    var commandDisplay: String {
        let baseCommand = command.split(separator: "/").last ?? ""
        if args.isEmpty {
            return String(baseCommand)
        }
        return "\(baseCommand) \(args.joined(separator: " "))"
    }

    var statusIcon: String {
        switch status {
        case .running: return "●"
        case .stopped: return "○"
        case .starting: return "◐"
        case .error: return "⚠"
        case .unknown: return "?"
        }
    }

    var statusColor: Color {
        switch status {
        case .running: return .green
        case .stopped: return .gray
        case .starting: return .yellow
        case .error: return .red
        case .unknown: return .secondary
        }
    }

    var typeIcon: String {
        serverType.icon
    }

    var typeColor: Color {
        serverType.color
    }

    var isHealthy: Bool {
        status == .running && lastError == nil
    }

    var canStart: Bool {
        enabled && (status == .stopped || status == .error)
    }

    var canStop: Bool {
        status == .running || status == .starting
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MCPServer, rhs: MCPServer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - MCP Server Type

enum MCPServerType: String, Codable, CaseIterable {
    case node = "node"
    case python = "python"
    case docker = "docker"
    case binary = "binary"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .node: return "Node.js"
        case .python: return "Python"
        case .docker: return "Docker"
        case .binary: return "Binary"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .node: return "cube"
        case .python: return "snake"
        case .docker: return "shippingbox"
        case .binary: return "terminal"
        case .custom: return "gear"
        }
    }

    var color: Color {
        switch self {
        case .node: return .green
        case .python: return .blue
        case .docker: return .cyan
        case .binary: return .purple
        case .custom: return .orange
        }
    }

    var terminalIcon: String {
        switch self {
        case .node: return "▣"
        case .python: return "◈"
        case .docker: return "◉"
        case .binary: return "▢"
        case .custom: return "◆"
        }
    }
}

// MARK: - MCP Server Status

enum MCPServerStatus: String, Codable, CaseIterable {
    case running = "running"
    case stopped = "stopped"
    case starting = "starting"
    case error = "error"
    case unknown = "unknown"

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - MCP Server Configuration (from .claude.json)

struct MCPConfiguration: Codable {
    var mcpServers: [String: MCPServerConfig]

    enum CodingKeys: String, CodingKey {
        case mcpServers = "mcpServers"
    }
}

struct MCPServerConfig: Codable {
    var command: String
    var args: [String]?
    var env: [String: String]?
    var disabled: Bool?
}

// MARK: - Sample Data (for development)

extension MCPServer {
    static let samples: [MCPServer] = [
        MCPServer(
            name: "Filesystem",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem", "/Users/whale"],
            serverType: .node,
            status: .running,
            description: "Access and manage local filesystem"
        ),
        MCPServer(
            name: "PostgreSQL",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-postgres", "postgresql://localhost/db"],
            serverType: .node,
            status: .stopped,
            description: "Query and manage PostgreSQL databases"
        ),
        MCPServer(
            name: "Brave Search",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-brave-search"],
            env: ["BRAVE_API_KEY": "***"],
            serverType: .node,
            status: .error,
            lastError: "API key not configured",
            description: "Search the web using Brave Search API"
        ),
        MCPServer(
            name: "GitHub",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-github"],
            env: ["GITHUB_TOKEN": "***"],
            serverType: .node,
            status: .stopped,
            description: "Interact with GitHub repositories and issues"
        )
    ]
}
