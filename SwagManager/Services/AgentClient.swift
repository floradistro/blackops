import Foundation
import SwiftUI

// MARK: - Client Connection State (Unified)
// Single source of truth for connection status - prevents multiple @Published mutations

struct ClientConnectionState: Equatable {
    var isConnected: Bool = false
    var isRunning: Bool = false
    var currentTool: String? = nil
}

// MARK: - Agent Client
// WebSocket client for communicating with local agent server
// Implements Anthropic multi-turn conversation pattern with persistent storage

@MainActor
@Observable
class AgentClient {
    static let shared = AgentClient()

    // MARK: - Connection State (UNIFIED)

    private(set) var connectionState = ClientConnectionState()

    /// Convenience accessors for backwards compatibility
    var isConnected: Bool { connectionState.isConnected }
    var isRunning: Bool { connectionState.isRunning }
    var currentTool: String? { connectionState.currentTool }

    private(set) var serverVersion: String?
    private(set) var availableTools: [ToolMetadata] = []

    // MARK: - Conversation State

    private(set) var currentConversationId: String?
    private(set) var conversations: [ConversationMeta] = []

    // MARK: - Execution State

    private(set) var currentModel: String?
    private(set) var executionLogs: [ExecutionLogEntry] = []
    private(set) var debugMessages: [DebugMessage] = []
    private(set) var conversationTrace: [ConversationMessage] = []
    private(set) var sessionMetrics: SessionMetrics = SessionMetrics()

    // MARK: - Configuration

    private let serverPort = 3847
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var hasEverConnected = false

    // MARK: - Callbacks

    private var onText: ((String) -> Void)?
    private var onToolStart: ((String, [String: Any]) -> Void)?
    private var onToolResult: ((String, Bool, Any?, String?) -> Void)?
    private var onDone: ((String, String, TokenUsage) -> Void)?  // (status, conversationId, usage)
    private var onError: ((String) -> Void)?
    private var onConversationCreated: ((ConversationMeta) -> Void)?

    // Tool execution tracking
    private var pendingToolStart: Date?
    private var pendingToolInput: [String: Any]?
    private let maxLogEntries = 100

    // MARK: - Initialization

    private init() {
        session = URLSession(configuration: .default)
    }

    // MARK: - Port Check

    private func isPortInUse(_ port: Int) -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-i", ":\(port)"]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return !output.isEmpty && output.contains("LISTEN")
        } catch {
            return false
        }
    }

    // MARK: - State Transition Helper

    /// Transition to new connection state with animations disabled
    /// This prevents layout recursion when observing views update during animations
    private func transitionState(to newState: ClientConnectionState) {
        guard connectionState != newState else { return }
        FreezeDebugger.logStateChange("connectionState", old: connectionState, new: newState)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            connectionState = newState
        }
    }

    // MARK: - Connection Management

    func connect() {
        print("[AgentClient] connect() called, webSocket=\(webSocket != nil ? "exists" : "nil")")
        guard webSocket == nil else {
            print("[AgentClient] WebSocket already exists, skipping")
            return
        }

        FreezeDebugger.printRunloopContext("AgentClient.connect()")

        // Don't attempt connection if we know the server isn't running
        // But always try if this is coming from AgentProcessManager detecting an existing server
        print("[AgentClient] isRunning=\(AgentProcessManager.shared.isRunning), hasEverConnected=\(hasEverConnected)")
        if !AgentProcessManager.shared.isRunning && !hasEverConnected {
            // Double-check by looking at the port directly
            if !isPortInUse(3847) {
                print("[AgentClient] Skipping connect - agent server not running and port not in use")
                return
            }
            print("[AgentClient] Port 3847 in use - attempting connection to external server")
        }

        let url = URL(string: "ws://localhost:\(serverPort)")!
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        receiveMessage()
    }

    func disconnect() {
        FreezeDebugger.transitionAgentState(.disconnected, reason: "disconnect() called")
        FreezeDebugger.printRunloopContext("AgentClient.disconnect()")

        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempts = 0
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        // ONE state change - use transitionState to disable animations
        transitionState(to: ClientConnectionState(isConnected: false, isRunning: connectionState.isRunning, currentTool: nil))
        serverVersion = nil
    }

    // MARK: - Query (Main API)

    func query(
        prompt: String,
        storeId: UUID?,
        config: AgentConfig? = nil,
        conversationId: String? = nil,
        onText: @escaping (String) -> Void,
        onToolStart: @escaping (String, [String: Any]) -> Void,
        onToolResult: @escaping (String, Bool, Any?, String?) -> Void,
        onDone: @escaping (String, String, TokenUsage) -> Void,
        onError: @escaping (String) -> Void,
        onConversationCreated: ((ConversationMeta) -> Void)? = nil
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
        self.onConversationCreated = onConversationCreated

        // Update connectionState.isRunning - use transitionState to disable animations
        transitionState(to: ClientConnectionState(isConnected: connectionState.isConnected, isRunning: true, currentTool: nil))

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

        // Pass conversation ID to continue existing conversation
        if let conversationId = conversationId ?? currentConversationId {
            message["conversationId"] = conversationId
        }

        send(message)
    }

    func abort() {
        send(["type": "abort"])
    }

    // MARK: - Conversation Management

    func newConversation() {
        currentConversationId = nil
        send(["type": "new_conversation"])
    }

    func getConversations(storeId: UUID, limit: Int = 20) {
        send([
            "type": "get_conversations",
            "storeId": storeId.uuidString,
            "limit": limit
        ])
    }

    func selectConversation(_ id: String) {
        currentConversationId = id
    }

    /// Load full conversation messages from server for timeline restoration
    var onConversationLoaded: ((String, String, [[String: Any]]) -> Void)?  // (id, title, messages)

    func loadConversation(_ id: String) {
        send([
            "type": "load_conversation",
            "conversationId": id
        ])
    }

    // MARK: - Tool Management

    func requestTools() {
        guard isConnected else { return }
        send(["type": "get_tools"])
    }

    func ping() {
        send(["type": "ping"])
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
            FreezeDebugger.transitionAgentState(.connected, reason: "WebSocket ready")
            // ONE state change - use transitionState to disable animations
            transitionState(to: ClientConnectionState(isConnected: true, isRunning: connectionState.isRunning, currentTool: connectionState.currentTool))
            hasEverConnected = true
            reconnectAttempts = 0
            serverVersion = json["version"] as? String
            parseTools(from: json["tools"])
            print("[AgentClient] Connected v\(serverVersion ?? "?"), \(availableTools.count) tools")

        case "tools":
            parseTools(from: json["tools"])
            print("[AgentClient] Tools refreshed: \(availableTools.count)")

        case "pong":
            break

        case "started":
            // ONE state change - use transitionState to disable animations
            transitionState(to: ClientConnectionState(isConnected: connectionState.isConnected, isRunning: true, currentTool: nil))
            currentModel = json["model"] as? String
            if let convId = json["conversationId"] as? String {
                currentConversationId = convId
            }
            // Reset telemetry for new session
            debugMessages.removeAll()
            conversationTrace.removeAll()
            sessionMetrics = SessionMetrics()
            sessionMetrics.startTime = Date()

        case "text":
            if let text = json["text"] as? String {
                sessionMetrics.textChunks += 1
                // NOTE: Conversation trace updates are batched - only update on done/tool events
                // This prevents 100s of array mutations during streaming
                onText?(text)
            }

        case "tool_start":
            if let tool = json["tool"] as? String {
                // Update currentTool via connectionState - use transitionState to disable animations
                transitionState(to: ClientConnectionState(isConnected: connectionState.isConnected, isRunning: connectionState.isRunning, currentTool: tool))
                let input = json["input"] as? [String: Any] ?? [:]
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

                // Create execution log
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

                // Update metrics
                if !success { sessionMetrics.errors += 1 }
                if let d = duration { sessionMetrics.totalToolTime += d }

                // Add to conversation trace
                conversationTrace.append(ConversationMessage(
                    role: .toolResult,
                    content: success ? formatResult(result) : (error ?? "Unknown error"),
                    toolName: tool,
                    isError: !success,
                    timestamp: Date()
                ))

                pendingToolStart = nil
                pendingToolInput = nil

                onToolResult?(tool, success, result, error)
            }
            // Clear currentTool after tool result - use transitionState to disable animations
            transitionState(to: ClientConnectionState(isConnected: connectionState.isConnected, isRunning: connectionState.isRunning, currentTool: nil))

        case "done":
            // ONE state change - clear isRunning and currentTool - use transitionState to disable animations
            transitionState(to: ClientConnectionState(isConnected: connectionState.isConnected, isRunning: false, currentTool: nil))
            let status = json["status"] as? String ?? "unknown"
            let conversationId = json["conversationId"] as? String ?? currentConversationId ?? ""
            var usage = TokenUsage(inputTokens: 0, outputTokens: 0, totalCost: 0)
            if let usageDict = json["usage"] as? [String: Any] {
                usage = TokenUsage(
                    inputTokens: usageDict["inputTokens"] as? Int ?? 0,
                    outputTokens: usageDict["outputTokens"] as? Int ?? 0,
                    totalCost: usageDict["totalCost"] as? Double ?? 0
                )
            }
            // Finalize metrics
            sessionMetrics.endTime = Date()
            sessionMetrics.finalUsage = usage

            onDone?(status, conversationId, usage)
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

        case "error":
            // ONE state change - clear isRunning and currentTool - use transitionState to disable animations
            transitionState(to: ClientConnectionState(isConnected: connectionState.isConnected, isRunning: false, currentTool: nil))
            let error = json["error"] as? String ?? "Unknown error"
            FreezeDebugger.asyncError("AgentClient query", error: NSError(domain: "Agent", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
            onError?(error)
            clearCallbacks()

        case "aborted":
            // ONE state change - clear isRunning and currentTool - use transitionState to disable animations
            transitionState(to: ClientConnectionState(isConnected: connectionState.isConnected, isRunning: false, currentTool: nil))
            FreezeDebugger.taskCancelled("AgentClient query (aborted)")
            onError?("Aborted")
            clearCallbacks()

        case "conversation_created":
            if let convData = json["conversation"] as? [String: Any] {
                let conv = parseConversationMeta(convData)
                currentConversationId = conv.id
                onConversationCreated?(conv)
            }

        case "conversations":
            if let convsData = json["conversations"] as? [[String: Any]] {
                conversations = convsData.map { parseConversationMeta($0) }
            }

        case "conversation_loaded":
            if let convId = json["conversationId"] as? String,
               let title = json["title"] as? String,
               let msgs = json["messages"] as? [[String: Any]] {
                currentConversationId = convId
                onConversationLoaded?(convId, title, msgs)
            }

        default:
            print("[AgentClient] Unknown message type: \(type)")
        }
    }

    private func handleDisconnect() {
        FreezeDebugger.transitionAgentState(.disconnected, reason: "WebSocket disconnected")
        FreezeDebugger.printRunloopContext("AgentClient.handleDisconnect()")

        // Defer state mutations off current runloop to avoid layout recursion
        // CRITICAL: ONE state change instead of THREE - use transitionState to disable animations
        let newState = ClientConnectionState(isConnected: false, isRunning: false, currentTool: nil)
        if connectionState != newState {
            DispatchQueue.main.async { [weak self] in
                self?.transitionState(to: newState)
            }
        }
        webSocket = nil

        reconnectAttempts += 1

        // Safety checks before attempting reconnect:
        // 1. Must have connected successfully before
        // 2. Haven't exceeded max attempts
        // 3. Agent process is still running
        guard hasEverConnected,
              reconnectAttempts <= maxReconnectAttempts,
              AgentProcessManager.shared.isRunning else {
            print("[AgentClient] Not reconnecting - server not running or max attempts reached")
            return
        }

        // Exponential backoff: 2s, 4s, 8s, 16s, 30s (capped)
        let delay = min(UInt64(pow(2.0, Double(reconnectAttempts))) * 1_000_000_000, 30_000_000_000)
        print("[AgentClient] Reconnecting in \(delay / 1_000_000_000)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")

        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: delay)
            if !Task.isCancelled && AgentProcessManager.shared.isRunning {
                self.connect()
            }
        }
    }

    private func clearCallbacks() {
        onText = nil
        onToolStart = nil
        onToolResult = nil
        onDone = nil
        onError = nil
        onConversationCreated = nil
    }

    // MARK: - Parsing Helpers

    private func parseTools(from toolsAny: Any?) {
        guard let toolsArray = toolsAny as? [[String: Any]] else { return }
        availableTools = toolsArray.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String,
                  let description = dict["description"] as? String else { return nil }
            let category = dict["category"] as? String ?? "other"
            return ToolMetadata(id: id, name: name, description: description, category: category)
        }
    }

    private func parseConversationMeta(_ dict: [String: Any]) -> ConversationMeta {
        ConversationMeta(
            id: dict["id"] as? String ?? "",
            title: dict["title"] as? String ?? "Untitled",
            agentId: dict["agentId"] as? String,
            agentName: dict["agentName"] as? String,
            messageCount: dict["messageCount"] as? Int ?? 0,
            createdAt: dict["createdAt"] as? String ?? "",
            updatedAt: dict["updatedAt"] as? String ?? ""
        )
    }

    // MARK: - Execution Log Management

    private func addExecutionLog(_ entry: ExecutionLogEntry) {
        // Append instead of insert(at:0) for O(1) instead of O(n)
        // Views should use .reversed() for newest-first display
        executionLogs.append(entry)
        if executionLogs.count > maxLogEntries {
            executionLogs.removeFirst(executionLogs.count - maxLogEntries)
        }
    }

    private func formatResult(_ result: Any?) -> String {
        guard let result = result else { return "null" }
        if let str = result as? String { return str }
        if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return String(describing: result)
    }

    func clearExecutionLogs() {
        executionLogs.removeAll()
    }

    func clearAllTelemetry() {
        executionLogs.removeAll()
        debugMessages.removeAll()
        conversationTrace.removeAll()
        sessionMetrics = SessionMetrics()
        currentConversationId = nil
    }

    // MARK: - Export Methods

    func exportSessionJSON() -> String {
        var session: [String: Any] = [
            "conversationId": currentConversationId ?? "none",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        // Export execution logs
        let logs = executionLogs.map { log -> [String: Any] in
            var entry: [String: Any] = [
                "tool": log.toolName,
                "timestamp": ISO8601DateFormatter().string(from: log.startedAt),
                "status": String(describing: log.status)
            ]
            if let duration = log.duration { entry["duration"] = duration }
            entry["input"] = log.input
            if let output = log.output { entry["output"] = String(describing: output) }
            if let error = log.error { entry["error"] = error }
            return entry
        }
        session["executionLogs"] = logs

        // Export conversation trace
        let trace = conversationTrace.map { msg -> [String: Any] in
            var entry: [String: Any] = [
                "role": msg.role.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: msg.timestamp),
                "content": msg.content,
                "isError": msg.isError
            ]
            if let tool = msg.toolName { entry["tool"] = tool }
            if let input = msg.toolInput { entry["input"] = input }
            return entry
        }
        session["conversationTrace"] = trace

        // Export metrics
        session["metrics"] = [
            "toolCalls": sessionMetrics.toolCalls,
            "textChunks": sessionMetrics.textChunks,
            "errors": sessionMetrics.errors,
            "totalToolTime": sessionMetrics.totalToolTime
        ]

        if let data = try? JSONSerialization.data(withJSONObject: session, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    func exportToolAsCurl(_ log: ExecutionLogEntry) -> String {
        var curl = "curl -X POST \\\n"
        curl += "  'https://your-api-endpoint/tools/\(log.toolName)' \\\n"
        curl += "  -H 'Content-Type: application/json' \\\n"

        let input = log.input
        if !input.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: input, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            let escaped = json.replacingOccurrences(of: "'", with: "'\\''")
            curl += "  -d '\(escaped)'"
        } else {
            curl += "  -d '{}'"
        }

        return curl
    }
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

    var formattedCost: String {
        String(format: "$%.4f", totalCost)
    }

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

struct ToolMetadata: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let category: String
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
