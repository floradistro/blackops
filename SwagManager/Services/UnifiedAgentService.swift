import Foundation

// MARK: - Unified Agent Service
// SSE streaming client for the Fly.io agent server (whale-agent.fly.dev)
// Replaces direct Anthropic API calls — server handles API keys, tools, context management
// Works on both macOS and iOS

@MainActor
@Observable
class UnifiedAgentService {
    static let shared = UnifiedAgentService()

    // MARK: - State

    var isRunning = false
    var currentTool: String?

    // MARK: - Configuration

    private let maxTurns = 20

    // MARK: - Run Agent via SSE

    /// Run agent query through the Fly.io server via SSE streaming
    func run(
        prompt: String,
        agentId: String,
        storeId: UUID?,
        conversationId: String? = nil,
        conversationHistory: [[String: Any]]? = nil,
        onText: @escaping (String) -> Void,
        onToolStart: @escaping (String) -> Void,
        onToolResult: @escaping (String, Bool, String) -> Void,
        onError: @escaping (String) -> Void,
        onComplete: @escaping (TokenUsage) -> Void
    ) async {
        isRunning = true
        defer { isRunning = false; currentTool = nil }

        let url = SupabaseConfig.agentServerURL

        // Build request body — matches server's expected format
        var body: [String: Any] = [
            "agentId": agentId,
            "message": prompt,
            "source": "ios_app",
        ]
        if let storeId { body["storeId"] = storeId.uuidString }
        if let conversationId { body["conversationId"] = conversationId }
        if let history = conversationHistory, !history.isEmpty {
            body["conversationHistory"] = history
        }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            onError("Failed to encode request")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.serviceRoleKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                var errorBody = ""
                for try await line in bytes.lines { errorBody += line }
                onError("Server error \(httpResponse.statusCode): \(errorBody.prefix(500))")
                return
            }

            var pendingInputTokens = 0
            var pendingOutputTokens = 0
            var pendingCostUsd = 0.0
            var pendingCacheCreation = 0
            var pendingCacheRead = 0

            for try await line in bytes.lines {
                guard line.hasPrefix("data: "),
                      let jsonData = String(line.dropFirst(6)).data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let type = json["type"] as? String else { continue }

                switch type {
                case "text":
                    if let text = json["text"] as? String { onText(text) }

                case "tool_start":
                    if let tool = json["name"] as? String {
                        currentTool = tool
                        onToolStart(tool)
                    }

                case "tool_result":
                    if let tool = json["name"] as? String {
                        let success = json["success"] as? Bool ?? false
                        let resultStr: String
                        if let result = json["result"] {
                            if let str = result as? String {
                                resultStr = str
                            } else if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
                                      let str = String(data: data, encoding: .utf8) {
                                resultStr = str
                            } else {
                                resultStr = String(describing: result)
                            }
                        } else {
                            resultStr = json["error"] as? String ?? "No output"
                        }
                        currentTool = nil
                        onToolResult(tool, success, resultStr)
                    }

                case "usage":
                    if let u = json["usage"] as? [String: Any] {
                        pendingInputTokens = u["input_tokens"] as? Int ?? 0
                        pendingOutputTokens = u["output_tokens"] as? Int ?? 0
                        pendingCostUsd = u["cost_usd"] as? Double ?? 0
                        pendingCacheCreation = u["cache_creation_tokens"] as? Int ?? 0
                        pendingCacheRead = u["cache_read_tokens"] as? Int ?? 0
                    }

                case "done":
                    let usage = TokenUsage(
                        inputTokens: pendingInputTokens,
                        outputTokens: pendingOutputTokens,
                        totalCost: pendingCostUsd,
                        cacheCreationTokens: pendingCacheCreation,
                        cacheReadTokens: pendingCacheRead
                    )
                    onComplete(usage)

                case "error":
                    onError(json["error"] as? String ?? "Unknown error")

                default: break
                }
            }
        } catch {
            onError("Connection error: \(error.localizedDescription)")
        }
    }

    // MARK: - Direct Tool Execution

    /// Execute a single tool on the Fly.io server without the agent loop
    func executeTool(
        name: String,
        args: [String: Any],
        storeId: UUID?
    ) async -> ToolResult {
        let url = SupabaseConfig.agentServerURL

        var body: [String: Any] = [
            "mode": "tool",
            "tool_name": name,
            "args": args,
        ]
        if let storeId { body["store_id"] = storeId.uuidString }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return ToolResult(success: false, output: "Failed to encode request")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.serviceRoleKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return ToolResult(success: false, output: "Server error")
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
                return ToolResult(success: success, output: outputStr)
            }
            return ToolResult(success: false, output: "Invalid response")
        } catch {
            return ToolResult(success: false, output: "Error: \(error.localizedDescription)")
        }
    }
}
