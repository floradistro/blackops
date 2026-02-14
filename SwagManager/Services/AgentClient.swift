import Foundation
import SwiftUI

// MARK: - Agent Client
// SSE streaming client for the Fly.io agent server (whale-agent.fly.dev)
// Replaces the legacy WebSocket client that connected to localhost:3847
// All types are defined in AgentModels.swift

@MainActor
@Observable
class AgentClient {
    static let shared = AgentClient()

    // MARK: - Connection State (UNIFIED)

    private(set) var connectionState = ClientConnectionState()

    /// Convenience accessors
    var isConnected: Bool { connectionState.isConnected }
    var isRunning: Bool { connectionState.isRunning }
    var currentTool: String? { connectionState.currentTool }

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

    private var serverURL: URL { SupabaseConfig.agentServerURL }
    private var authToken: String { SupabaseConfig.serviceRoleKey }

    // MARK: - Internal

    private var currentStreamTask: Task<Void, Never>?
    private var pendingToolStart: Date?
    private var pendingToolInput: [String: Any]?
    private let maxLogEntries = 100

    // MARK: - Callbacks

    private var onText: ((String) -> Void)?
    private var onToolStart: ((String, [String: Any]) -> Void)?
    private var onToolResult: ((String, Bool, Any?, String?) -> Void)?
    private var onDone: ((String, String, TokenUsage) -> Void)?  // (status, conversationId, usage)
    private var onError: ((String) -> Void)?
    private var onConversationCreated: ((ConversationMeta) -> Void)?

    /// Callback for loading full conversation messages
    var onConversationLoaded: ((String, String, [[String: Any]]) -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - State Transition Helper

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

    /// Cloud service — marks as connected (no WebSocket needed)
    func connect() {
        FreezeDebugger.transitionAgentState(.connected, reason: "Fly.io SSE ready")
        transitionState(to: ClientConnectionState(isConnected: true, isRunning: false, currentTool: nil))
    }

    func disconnect() {
        FreezeDebugger.transitionAgentState(.disconnected, reason: "disconnect() called")
        currentStreamTask?.cancel()
        currentStreamTask = nil
        transitionState(to: ClientConnectionState(isConnected: false, isRunning: false, currentTool: nil))
        clearCallbacks()
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

        // Set running state
        transitionState(to: ClientConnectionState(isConnected: true, isRunning: true, currentTool: nil))

        // Reset telemetry for new session
        debugMessages.removeAll()
        conversationTrace.removeAll()
        sessionMetrics = SessionMetrics()
        sessionMetrics.startTime = Date()

        // Extract agent config
        let agentId = config?.agentId ?? "default"
        currentModel = config?.model

        // Build request body matching server's expected format
        var body: [String: Any] = [
            "agentId": agentId,
            "message": prompt,
            "source": "ios_app",
        ]
        if let storeId { body["storeId"] = storeId.uuidString }
        let activeConvId = conversationId ?? currentConversationId
        if let activeConvId { body["conversationId"] = activeConvId }

        // Launch SSE streaming task
        currentStreamTask = Task { [weak self] in
            await self?.streamSSE(body: body)
        }
    }

    func abort() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
        FreezeDebugger.taskCancelled("AgentClient query (aborted)")
        transitionState(to: ClientConnectionState(isConnected: true, isRunning: false, currentTool: nil))
        onError?("Aborted")
        clearCallbacks()
    }

    // MARK: - Conversation Management

    func newConversation() {
        currentConversationId = nil
    }

    func selectConversation(_ id: String) {
        currentConversationId = id
    }

    /// Load conversations from server (not yet supported in Fly.io SSE mode)
    func getConversations(storeId: UUID, limit: Int = 20) {
        // TODO: Add conversation list endpoint to Fly server
        print("[AgentClient] getConversations not yet supported in cloud mode")
    }

    /// Load full conversation messages (not yet supported in Fly.io SSE mode)
    func loadConversation(_ id: String) {
        currentConversationId = id
        print("[AgentClient] loadConversation not yet supported in cloud mode")
    }

    // MARK: - Tool Management

    func requestTools() {
        // Load tools from server via direct tool execution
        Task {
            let result = await executeTool(name: "products", args: ["action": "list_categories"])
            if result.success {
                print("[AgentClient] Tools loaded via server")
            }
        }
    }

    func ping() {
        // No-op for cloud — connection is stateless
    }

    // MARK: - SSE Streaming

    private func streamSSE(body: [String: Any]) async {
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            await MainActor.run {
                self.handleError("Failed to encode request")
            }
            return
        }

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        var pendingInputTokens = 0
        var pendingOutputTokens = 0
        var pendingCostUsd = 0.0
        var pendingCacheCreation = 0
        var pendingCacheRead = 0

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                var errorBody = ""
                for try await line in bytes.lines { errorBody += line }
                await MainActor.run {
                    self.handleError("Server error \(httpResponse.statusCode): \(String(errorBody.prefix(500)))")
                }
                return
            }

            for try await line in bytes.lines {
                guard !Task.isCancelled else { break }

                guard line.hasPrefix("data: "),
                      let jsonData = String(line.dropFirst(6)).data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let type = json["type"] as? String else { continue }

                await MainActor.run {
                    self.handleSSEEvent(
                        type: type,
                        json: json,
                        pendingTokens: (pendingInputTokens, pendingOutputTokens, pendingCostUsd, pendingCacheCreation, pendingCacheRead)
                    )
                }

                // Update pending values from usage events
                if type == "usage", let u = json["usage"] as? [String: Any] {
                    pendingInputTokens = u["input_tokens"] as? Int ?? pendingInputTokens
                    pendingOutputTokens = u["output_tokens"] as? Int ?? pendingOutputTokens
                    pendingCostUsd = u["cost_usd"] as? Double ?? pendingCostUsd
                    pendingCacheCreation = u["cache_creation_tokens"] as? Int ?? pendingCacheCreation
                    pendingCacheRead = u["cache_read_tokens"] as? Int ?? pendingCacheRead
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.handleError("Connection error: \(error.localizedDescription)")
            }
        }
    }

    private func handleSSEEvent(type: String, json: [String: Any], pendingTokens: (Int, Int, Double, Int, Int)) {
        switch type {
        case "text":
            if let text = json["text"] as? String {
                sessionMetrics.textChunks += 1
                onText?(text)
            }

        case "tool_start":
            if let tool = json["name"] as? String {
                transitionState(to: ClientConnectionState(isConnected: true, isRunning: true, currentTool: tool))
                let input = json["input"] as? [String: Any] ?? [:]
                pendingToolStart = Date()
                pendingToolInput = input
                sessionMetrics.toolCalls += 1
                conversationTrace.append(ConversationMessage(
                    role: .toolUse,
                    content: tool,
                    toolInput: input,
                    timestamp: Date()
                ))
                onToolStart?(tool, input)
            }

        case "tool_result":
            if let tool = json["name"] as? String {
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

                if !success { sessionMetrics.errors += 1 }
                if let d = duration { sessionMetrics.totalToolTime += d }

                conversationTrace.append(ConversationMessage(
                    role: .toolResult,
                    content: success ? formatResult(result) : (error ?? "Unknown error"),
                    toolName: tool,
                    isError: !success,
                    timestamp: Date()
                ))

                pendingToolStart = nil
                pendingToolInput = nil
                transitionState(to: ClientConnectionState(isConnected: true, isRunning: true, currentTool: nil))
                onToolResult?(tool, success, result, error)
            }

        case "usage":
            // Tracked in streamSSE() — no action needed here
            break

        case "done":
            let conversationId = json["conversationId"] as? String ?? currentConversationId ?? ""
            currentConversationId = conversationId

            let usage = TokenUsage(
                inputTokens: pendingTokens.0,
                outputTokens: pendingTokens.1,
                totalCost: pendingTokens.2,
                cacheCreationTokens: pendingTokens.3,
                cacheReadTokens: pendingTokens.4
            )

            sessionMetrics.endTime = Date()
            sessionMetrics.finalUsage = usage

            transitionState(to: ClientConnectionState(isConnected: true, isRunning: false, currentTool: nil))
            onDone?("completed", conversationId, usage)
            clearCallbacks()

        case "error":
            handleError(json["error"] as? String ?? "Unknown error")

        default:
            print("[AgentClient] Unknown SSE event: \(type)")
        }
    }

    private func handleError(_ message: String) {
        FreezeDebugger.asyncError("AgentClient query", error: NSError(domain: "Agent", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
        transitionState(to: ClientConnectionState(isConnected: true, isRunning: false, currentTool: nil))
        onError?(message)
        clearCallbacks()
    }

    private func clearCallbacks() {
        onText = nil
        onToolStart = nil
        onToolResult = nil
        onDone = nil
        onError = nil
        onConversationCreated = nil
    }

    // MARK: - Direct Tool Execution

    /// Execute a single tool on the Fly.io server without the agent loop
    func executeTool(name: String, args: [String: Any], storeId: UUID? = nil) async -> (success: Bool, output: String) {
        var body: [String: Any] = [
            "mode": "tool",
            "tool_name": name,
            "args": args,
        ]
        if let storeId { body["store_id"] = storeId.uuidString }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return (false, "Failed to encode request")
        }

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return (false, "Server error")
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                let output = json["data"] ?? json["error"] ?? "No output"
                let outputStr: String
                if let str = output as? String {
                    outputStr = str
                } else if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
                          let str = String(data: data, encoding: .utf8) {
                    outputStr = str
                } else {
                    outputStr = String(describing: output)
                }
                return (success, outputStr)
            }
            return (false, "Invalid response")
        } catch {
            return (false, "Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Execution Log Management

    private func addExecutionLog(_ entry: ExecutionLogEntry) {
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
        curl += "  '\(serverURL.absoluteString)' \\\n"
        curl += "  -H 'Content-Type: application/json' \\\n"
        curl += "  -H 'Authorization: Bearer <token>' \\\n"

        var body: [String: Any] = [
            "mode": "tool",
            "tool_name": log.toolName,
            "args": log.input
        ]

        if let data = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            let escaped = json.replacingOccurrences(of: "'", with: "'\\''")
            curl += "  -d '\(escaped)'"
        } else {
            curl += "  -d '{}'"
        }

        return curl
    }
}
