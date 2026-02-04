import Foundation
import SwiftUI

// MARK: - Agent Client
// WebSocket client for communicating with the local Claude Agent SDK server
// Following Anthropic engineering patterns for agent communication

@MainActor
class AgentClient: ObservableObject {
    static let shared = AgentClient()

    // MARK: - Published State

    @Published private(set) var isConnected = false
    @Published private(set) var isRunning = false
    @Published private(set) var currentTool: String?
    @Published private(set) var serverVersion: String?
    @Published private(set) var availableTools: [ToolMetadata] = []
    @Published private(set) var debugMessages: [DebugMessage] = []
    @Published private(set) var currentModel: String?

    // MARK: - Execution Logs (Real-time tool telemetry)
    @Published private(set) var executionLogs: [ExecutionLogEntry] = []
    @Published private(set) var currentExecution: ExecutionSession?
    private var pendingToolStart: Date?
    private var pendingToolInput: [String: Any]?
    private let maxLogEntries = 100

    // MARK: - Conversation Trace (Full message history for debugging)
    @Published private(set) var conversationTrace: [ConversationMessage] = []
    @Published private(set) var thinkingBlocks: [ThinkingBlock] = []
    private var currentThinkingBlock: ThinkingBlock?

    // MARK: - Performance Metrics
    @Published private(set) var sessionMetrics: SessionMetrics = SessionMetrics()

    // MARK: - Configuration

    private let serverPort = 3847
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var reconnectTask: Task<Void, Never>?

    // MARK: - Callbacks

    private var onText: ((String) -> Void)?
    private var onToolStart: ((String, [String: Any]) -> Void)?
    private var onToolResult: ((String, Bool, Any?, String?) -> Void)?
    private var onDone: ((String, TokenUsage) -> Void)?
    private var onError: ((String) -> Void)?

    // MARK: - Initialization

    private init() {
        session = URLSession(configuration: .default)
    }

    // MARK: - Connection Management

    func connect() {
        guard webSocket == nil else { return }

        let url = URL(string: "ws://localhost:\(serverPort)")!
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        receiveMessage()

        print("[AgentClient] Connecting to ws://localhost:\(serverPort)")
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
        serverVersion = nil
    }

    // MARK: - Send Query

    func query(
        prompt: String,
        storeId: UUID?,
        config: AgentConfig? = nil,
        attachedPaths: [String] = [],
        onText: @escaping (String) -> Void,
        onToolStart: @escaping (String, [String: Any]) -> Void,
        onToolResult: @escaping (String, Bool, Any?, String?) -> Void,
        onDone: @escaping (String, TokenUsage) -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard isConnected else {
            onError("Not connected to agent server")
            return
        }

        guard !isRunning else {
            onError("Agent is already running")
            return
        }

        self.onText = onText
        self.onToolStart = onToolStart
        self.onToolResult = onToolResult
        self.onDone = onDone
        self.onError = onError

        isRunning = true

        var message: [String: Any] = [
            "type": "query",
            "prompt": prompt
        ]

        if let storeId = storeId {
            message["storeId"] = storeId.uuidString
        }

        if let config = config {
            message["config"] = config.toDict()
        }

        // Send attached paths for project context auto-reading
        if !attachedPaths.isEmpty {
            message["attachedPaths"] = attachedPaths
        }

        send(message)
    }

    func abort() {
        send(["type": "abort"])
    }

    // MARK: - WebSocket Communication

    private func send(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else {
            return
        }

        webSocket?.send(.string(string)) { error in
            if let error = error {
                print("[AgentClient] Send error: \(error)")
            }
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    Task { @MainActor in
                        self.handleMessage(text)
                    }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        Task { @MainActor in
                            self.handleMessage(text)
                        }
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                print("[AgentClient] Receive error: \(error)")
                Task { @MainActor in
                    self.handleDisconnect()
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "ready":
            isConnected = true
            serverVersion = json["version"] as? String
            // Parse tools from server (now includes category)
            if let toolsArray = json["tools"] as? [[String: Any]] {
                availableTools = toolsArray.compactMap { dict in
                    guard let id = dict["id"] as? String,
                          let name = dict["name"] as? String,
                          let description = dict["description"] as? String else { return nil }
                    let category = dict["category"] as? String ?? "other"
                    return ToolMetadata(id: id, name: name, description: description, category: category)
                }
            }
            // Log tool categories
            let categories = Set(availableTools.map { $0.category })
            print("[AgentClient] Connected, server version: \(serverVersion ?? "unknown"), tools: \(availableTools.count) in \(categories.count) categories")

        case "pong":
            break

        case "tools":
            // Handle tools refresh response (same format as ready)
            if let toolsArray = json["tools"] as? [[String: Any]] {
                availableTools = toolsArray.compactMap { dict in
                    guard let id = dict["id"] as? String,
                          let name = dict["name"] as? String,
                          let description = dict["description"] as? String else { return nil }
                    let category = dict["category"] as? String ?? "other"
                    return ToolMetadata(id: id, name: name, description: description, category: category)
                }
                let categories = Set(availableTools.map { $0.category })
                print("[AgentClient] Tools refreshed: \(availableTools.count) tools in \(categories.count) categories")
            }

        case "started":
            isRunning = true
            currentModel = json["model"] as? String
            debugMessages.removeAll() // Clear debug messages for new query
            conversationTrace.removeAll() // Clear conversation trace
            thinkingBlocks.removeAll() // Clear thinking blocks
            sessionMetrics = SessionMetrics() // Reset metrics
            sessionMetrics.startTime = Date()
            // Start new execution session
            currentExecution = ExecutionSession(
                model: json["model"] as? String ?? "unknown",
                storeId: json["storeId"] as? String
            )
            // Add initial user message to trace
            if let prompt = json["prompt"] as? String {
                conversationTrace.append(ConversationMessage(
                    role: .user,
                    content: prompt,
                    timestamp: Date()
                ))
            }

        case "text":
            if let text = json["text"] as? String {
                // Track text for conversation trace (accumulate assistant response)
                if let lastMsg = conversationTrace.last, lastMsg.role == .assistant {
                    // Append to existing assistant message
                    var updated = lastMsg
                    updated.content += text
                    conversationTrace[conversationTrace.count - 1] = updated
                } else {
                    // Start new assistant message
                    conversationTrace.append(ConversationMessage(
                        role: .assistant,
                        content: text,
                        timestamp: Date()
                    ))
                }
                sessionMetrics.textChunks += 1
                onText?(text)
            }

        case "thinking":
            // Capture Claude's thinking/reasoning (extended thinking feature)
            if let thinking = json["thinking"] as? String {
                let block = ThinkingBlock(
                    content: thinking,
                    timestamp: Date(),
                    turnNumber: sessionMetrics.turns
                )
                thinkingBlocks.append(block)
            }

        case "tool_start":
            if let tool = json["tool"] as? String {
                print("[AgentClient] Tool start: \(tool)")
                currentTool = tool
                let input = json["input"] as? [String: Any] ?? [:]
                // Track for execution log
                pendingToolStart = Date()
                pendingToolInput = input
                sessionMetrics.toolCalls += 1
                // Add to conversation trace
                conversationTrace.append(ConversationMessage(
                    role: .toolUse,
                    content: tool,
                    toolInput: input,
                    timestamp: Date()
                ))
                onToolStart?(tool, input)
            }

        case "tool_result":
            if let tool = json["tool"] as? String {
                let success = json["success"] as? Bool ?? false
                let result = json["result"]
                let error = json["error"] as? String
                print("[AgentClient] Tool result: \(tool) success=\(success)")

                // Create execution log entry
                let duration = pendingToolStart.map { Date().timeIntervalSince($0) }
                let logEntry = ExecutionLogEntry(
                    toolName: tool,
                    status: success ? .success : .error,
                    input: pendingToolInput ?? [:],
                    output: result,
                    error: error,
                    duration: duration,
                    startedAt: pendingToolStart ?? Date()
                )
                addExecutionLog(logEntry)
                pendingToolStart = nil
                pendingToolInput = nil

                // Add tool result to conversation trace
                conversationTrace.append(ConversationMessage(
                    role: .toolResult,
                    content: success ? formatResult(result) : (error ?? "Unknown error"),
                    toolName: tool,
                    isError: !success,
                    timestamp: Date()
                ))

                // Update metrics
                if !success { sessionMetrics.errors += 1 }
                if let d = duration { sessionMetrics.totalToolTime += d }

                onToolResult?(tool, success, result, error)
            }
            currentTool = nil

        case "done":
            isRunning = false
            currentTool = nil
            let status = json["status"] as? String ?? "unknown"
            var usage = TokenUsage(inputTokens: 0, outputTokens: 0, totalCost: 0)
            if let usageDict = json["usage"] as? [String: Any] {
                usage = TokenUsage(
                    inputTokens: usageDict["inputTokens"] as? Int ?? 0,
                    outputTokens: usageDict["outputTokens"] as? Int ?? 0,
                    totalCost: usageDict["totalCost"] as? Double ?? 0
                )
            }
            // Finalize execution session
            if var session = currentExecution {
                session.completedAt = Date()
                session.status = status == "end_turn" ? .success : (status == "error" ? .error : .success)
                session.usage = usage
                currentExecution = session
            }
            // Finalize metrics
            sessionMetrics.endTime = Date()
            sessionMetrics.finalUsage = usage
            sessionMetrics.turns = json["num_turns"] as? Int ?? sessionMetrics.turns
            print("[AgentClient] Done: \(status), tokens: \(usage.totalTokens)")
            onDone?(status, usage)
            clearCallbacks()

        case "error":
            isRunning = false
            currentTool = nil
            let error = json["error"] as? String ?? "Unknown error"
            print("[AgentClient] Error: \(error)")
            onError?(error)
            clearCallbacks()

        case "aborted":
            isRunning = false
            currentTool = nil
            onError?("Aborted")
            clearCallbacks()

        case "debug":
            let level = json["level"] as? String ?? "info"
            let message = json["message"] as? String ?? ""
            let data = json["data"] as? [String: Any]
            let debugMsg = DebugMessage(
                level: DebugLevel(rawValue: level) ?? .info,
                message: message,
                data: data,
                timestamp: Date()
            )
            debugMessages.append(debugMsg)
            print("[AgentClient] Debug [\(level)]: \(message)")

        default:
            print("[AgentClient] Unknown message type: \(type)")
        }
    }

    private func handleDisconnect() {
        isConnected = false
        isRunning = false
        currentTool = nil
        webSocket = nil

        // Auto-reconnect
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if !Task.isCancelled {
                connect()
            }
        }
    }

    private func clearCallbacks() {
        onText = nil
        onToolStart = nil
        onToolResult = nil
        onDone = nil
        onError = nil
    }

    // MARK: - Ping

    func ping() {
        send(["type": "ping"])
    }

    // MARK: - Request Tools Refresh

    /// Request fresh tools list from server (useful when already connected)
    func requestTools() {
        guard isConnected else { return }
        send(["type": "get_tools"])
    }

    // MARK: - Execution Log Management

    private func addExecutionLog(_ entry: ExecutionLogEntry) {
        executionLogs.insert(entry, at: 0)
        // Trim to max entries
        if executionLogs.count > maxLogEntries {
            executionLogs.removeLast(executionLogs.count - maxLogEntries)
        }
    }

    func clearExecutionLogs() {
        executionLogs.removeAll()
        currentExecution = nil
    }

    func clearAllTelemetry() {
        executionLogs.removeAll()
        currentExecution = nil
        conversationTrace.removeAll()
        thinkingBlocks.removeAll()
        debugMessages.removeAll()
        sessionMetrics = SessionMetrics()
    }

    // MARK: - Export Functions

    /// Export full session as JSON for debugging/sharing
    func exportSessionJSON() -> String {
        var export: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "model": currentExecution?.model ?? currentModel ?? "unknown",
            "serverVersion": serverVersion ?? "unknown"
        ]

        // Metrics
        export["metrics"] = [
            "toolCalls": sessionMetrics.toolCalls,
            "errors": sessionMetrics.errors,
            "turns": sessionMetrics.turns,
            "totalDuration": sessionMetrics.totalDuration ?? 0,
            "totalToolTime": sessionMetrics.totalToolTime,
            "inputTokens": sessionMetrics.finalUsage?.inputTokens ?? 0,
            "outputTokens": sessionMetrics.finalUsage?.outputTokens ?? 0,
            "totalCost": sessionMetrics.finalUsage?.totalCost ?? 0
        ]

        // Tool calls
        export["toolCalls"] = executionLogs.map { log -> [String: Any] in
            [
                "tool": log.toolName,
                "status": log.status == .success ? "success" : "error",
                "duration": log.duration ?? 0,
                "input": log.input,
                "output": log.outputSummary,
                "error": log.error as Any,
                "timestamp": ISO8601DateFormatter().string(from: log.startedAt)
            ]
        }

        // Conversation trace
        export["conversation"] = conversationTrace.map { msg -> [String: Any] in
            var m: [String: Any] = [
                "role": msg.role.rawValue,
                "content": msg.content,
                "timestamp": ISO8601DateFormatter().string(from: msg.timestamp)
            ]
            if let input = msg.toolInput {
                m["toolInput"] = input
            }
            if let name = msg.toolName {
                m["toolName"] = name
            }
            return m
        }

        // Debug messages
        export["debug"] = debugMessages.map { d -> [String: Any] in
            [
                "level": d.level.rawValue,
                "message": d.message,
                "data": d.data as Any,
                "timestamp": ISO8601DateFormatter().string(from: d.timestamp)
            ]
        }

        if let data = try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    /// Export single tool call as curl command for replay
    func exportToolAsCurl(_ log: ExecutionLogEntry) -> String {
        let inputJson = (try? JSONSerialization.data(withJSONObject: log.input, options: []))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        return """
        curl -X POST 'https://uaednwpxursknmwdeejn.supabase.co/functions/v1/tools-gateway' \\
          -H 'Authorization: Bearer YOUR_KEY' \\
          -H 'Content-Type: application/json' \\
          -d '{"tool": "\(log.toolName)", "input": \(inputJson)}'
        """
    }

    // MARK: - Private Helpers

    private func formatResult(_ result: Any?) -> String {
        guard let result = result else { return "(no result)" }
        if let str = result as? String {
            return String(str.prefix(500))
        }
        if let data = try? JSONSerialization.data(withJSONObject: result, options: []),
           let str = String(data: data, encoding: .utf8) {
            return String(str.prefix(500))
        }
        return String(describing: result).prefix(500).description
    }
}

// MARK: - Supporting Types

struct AgentConfig {
    var model: String?
    var maxTurns: Int?
    var permissionMode: String?
    var systemPrompt: String?
    var enabledTools: [String]?  // Filter to only these tool IDs
    var agentId: String?         // AI Agent UUID for telemetry
    var agentName: String?       // AI Agent name for telemetry
    var apiKey: String?          // Anthropic API key

    func toDict() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let model = model { dict["model"] = model }
        if let maxTurns = maxTurns { dict["maxTurns"] = maxTurns }
        if let permissionMode = permissionMode { dict["permissionMode"] = permissionMode }
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

    var formattedCost: String {
        String(format: "$%.4f", totalCost)
    }

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

// MARK: - Tool Metadata (from server)

struct ToolMetadata: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let category: String
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

    var levelColor: String {
        switch level {
        case .info: return "blue"
        case .warn: return "orange"
        case .error: return "red"
        }
    }
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

// MARK: - Execution Session

struct ExecutionSession: Identifiable {
    let id = UUID()
    let model: String
    let storeId: String?
    let startedAt = Date()
    var completedAt: Date?
    var status: ExecutionStatus = .running
    var usage: TokenUsage?

    var duration: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "..." }
        return String(format: "%.2fs", duration)
    }
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

// MARK: - Thinking Block (extended thinking capture)

struct ThinkingBlock: Identifiable {
    let id = UUID()
    let content: String
    let timestamp: Date
    let turnNumber: Int
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
