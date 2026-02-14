import Foundation
import SwiftUI

// MARK: - Client Connection State (Unified)
// Single source of truth for connection status - prevents multiple @Published mutations

struct ClientConnectionState: Equatable {
    var isConnected: Bool = false
    var isRunning: Bool = false
    var currentTool: String? = nil
}

// MARK: - Supporting Types

struct AgentConfig {
    var model: String?
    var maxTurns: Int?
    var systemPrompt: String?
    var enabledTools: [String]?
    var agentId: String?
    var agentName: String?
    var apiKey: String?

    func toDict() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let model = model { dict["model"] = model }
        if let maxTurns = maxTurns { dict["maxTurns"] = maxTurns }
        if let systemPrompt = systemPrompt { dict["systemPrompt"] = systemPrompt }
        if let enabledTools = enabledTools { dict["enabledTools"] = enabledTools }
        if let agentId = agentId { dict["agentId"] = agentId }
        if let agentName = agentName { dict["agentName"] = agentName }
        if let apiKey = apiKey { dict["apiKey"] = apiKey }
        return dict
    }
}

struct TokenUsage {
    let inputTokens: Int
    let outputTokens: Int
    let totalCost: Double
    let cacheCreationTokens: Int
    let cacheReadTokens: Int

    init(inputTokens: Int, outputTokens: Int, totalCost: Double, cacheCreationTokens: Int = 0, cacheReadTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalCost = totalCost
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
    }

    var formattedCost: String {
        String(format: "$%.4f", totalCost)
    }

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

struct ConversationMeta: Identifiable, Equatable {
    let id: String
    let title: String
    let agentId: String?
    let agentName: String?
    let messageCount: Int
    let createdAt: String
    let updatedAt: String
}

struct ToolMetadata: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let category: String
}

// MARK: - Execution Log Entry

enum ExecutionStatus {
    case running
    case success
    case error

    var color: Color {
        switch self {
        case .running: return .blue
        case .success: return .green
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .running: return "circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}

struct ExecutionLogEntry: Identifiable {
    let id = UUID()
    let toolName: String
    let status: ExecutionStatus
    let input: [String: Any]
    let output: Any?
    let error: String?
    let duration: TimeInterval?
    let startedAt: Date

    var formattedDuration: String {
        guard let duration = duration else { return "..." }
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        }
        return String(format: "%.2fs", duration)
    }

    var inputSummary: String {
        guard !input.isEmpty else { return "(no input)" }
        let keys = input.keys.sorted().prefix(3)
        return keys.joined(separator: ", ")
    }

    var outputSummary: String {
        guard let output = output else { return error ?? "(no output)" }
        if let str = output as? String {
            return String(str.prefix(100))
        }
        if let dict = output as? [String: Any] {
            return "{\(dict.count) keys}"
        }
        if let arr = output as? [Any] {
            return "[\(arr.count) items]"
        }
        return String(describing: output).prefix(100).description
    }
}

// MARK: - Debug Message

enum DebugLevel: String {
    case info
    case warn
    case error
}

struct DebugMessage: Identifiable {
    let id = UUID()
    let level: DebugLevel
    let message: String
    let data: [String: Any]?
    let timestamp: Date
}

// MARK: - Conversation Message (for trace view)

enum ConversationRole: String {
    case user
    case assistant
    case toolUse = "tool_use"
    case toolResult = "tool_result"
    case system
}

struct ConversationMessage: Identifiable {
    let id = UUID()
    let role: ConversationRole
    var content: String
    var toolInput: [String: Any]?
    var toolName: String?
    var isError: Bool = false
    let timestamp: Date

    var icon: String {
        switch role {
        case .user: return "person.fill"
        case .assistant: return "sparkles"
        case .toolUse: return "wrench.fill"
        case .toolResult: return "arrow.left.circle.fill"
        case .system: return "gear"
        }
    }

    var roleColor: Color {
        switch role {
        case .user: return .blue
        case .assistant: return .purple
        case .toolUse: return .orange
        case .toolResult: return isError ? .red : .green
        case .system: return .gray
        }
    }
}

// MARK: - Session Metrics

struct SessionMetrics {
    var startTime: Date?
    var endTime: Date?
    var toolCalls: Int = 0
    var errors: Int = 0
    var turns: Int = 0
    var textChunks: Int = 0
    var totalToolTime: TimeInterval = 0
    var finalUsage: TokenUsage?

    var totalDuration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }

    var successRate: Double {
        guard toolCalls > 0 else { return 1.0 }
        return Double(toolCalls - errors) / Double(toolCalls)
    }

    var avgToolTime: TimeInterval {
        guard toolCalls > 0 else { return 0 }
        return totalToolTime / Double(toolCalls)
    }

    var formattedDuration: String {
        guard let duration = totalDuration else { return "..." }
        return String(format: "%.2fs", duration)
    }

    var costPerTool: Double {
        guard toolCalls > 0, let cost = finalUsage?.totalCost else { return 0 }
        return cost / Double(toolCalls)
    }
}
