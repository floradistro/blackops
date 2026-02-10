import Foundation

// MARK: - Unified Agent Service
// Runs the agentic loop locally in Swift
// Handles both remote (Supabase) and local (file/shell) tools
// Mirrors Claude Code architecture

@MainActor
@Observable
class UnifiedAgentService {
    static let shared = UnifiedAgentService()

    // MARK: - State

    var isRunning = false
    var currentTool: String?

    // MARK: - Configuration

    private let anthropicEndpoint = "https://api.anthropic.com/v1/messages"
    private let maxTurns = 20

    // Remote tools endpoint (Supabase)
    private var remoteToolsEndpoint: String {
        "\(SupabaseConfig.url)/functions/v1/execute-tool"
    }

    // MARK: - Run Agent

    /// Run the unified agent with both local and remote tools
    func run(
        prompt: String,
        systemPrompt: String,
        storeId: UUID?,
        includeLocalTools: Bool = true,
        onText: @escaping (String) -> Void,
        onToolStart: @escaping (String) -> Void,
        onToolResult: @escaping (String, Bool, String) -> Void,
        onError: @escaping (String) -> Void,
        onComplete: @escaping (Int, Int) -> Void  // input tokens, output tokens
    ) async {
        isRunning = true
        defer { isRunning = false; currentTool = nil }

        // Build tool definitions
        var tools: [[String: Any]] = []
        if includeLocalTools {
            tools.append(contentsOf: LocalToolService.toolDefinitions)
        }
        // Build messages
        var messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]

        var totalInputTokens = 0
        var totalOutputTokens = 0
        var turnCount = 0

        // Agentic loop
        while turnCount < maxTurns {
            turnCount += 1

            // Call Anthropic API
            let response = await callAnthropic(
                messages: messages,
                systemPrompt: systemPrompt,
                tools: tools,
                storeId: storeId
            )

            guard let response = response else {
                onError("Failed to get response from API")
                break
            }

            // Track tokens
            if let usage = response["usage"] as? [String: Any] {
                totalInputTokens += usage["input_tokens"] as? Int ?? 0
                totalOutputTokens += usage["output_tokens"] as? Int ?? 0
            }

            // Process content blocks
            guard let content = response["content"] as? [[String: Any]] else {
                onError("Invalid response format")
                break
            }

            var hasToolUse = false
            var toolResults: [[String: Any]] = []
            var assistantContent: [[String: Any]] = []

            for block in content {
                guard let type = block["type"] as? String else { continue }

                if type == "text", let text = block["text"] as? String {
                    onText(text)
                    assistantContent.append(block)
                }
                else if type == "tool_use" {
                    hasToolUse = true
                    assistantContent.append(block)

                    guard let toolId = block["id"] as? String,
                          let toolName = block["name"] as? String,
                          let toolInput = block["input"] as? [String: Any] else {
                        continue
                    }

                    currentTool = toolName
                    onToolStart(toolName)

                    // Execute tool (local or remote)
                    let result: ToolResult
                    if LocalToolService.isLocalTool(toolName) {
                        result = await LocalToolService.shared.execute(tool: toolName, input: toolInput)
                    } else {
                        result = await executeRemoteTool(
                            name: toolName,
                            input: toolInput,
                            storeId: storeId
                        )
                    }

                    currentTool = nil
                    onToolResult(toolName, result.success, result.output)

                    toolResults.append([
                        "type": "tool_result",
                        "tool_use_id": toolId,
                        "content": result.asJSON
                    ])
                }
            }

            // If no tool use, we're done
            if !hasToolUse {
                break
            }

            // Add assistant message and tool results to conversation
            messages.append(["role": "assistant", "content": assistantContent])
            messages.append(["role": "user", "content": toolResults])
        }

        onComplete(totalInputTokens, totalOutputTokens)
    }

    // MARK: - Anthropic API Call

    private func callAnthropic(
        messages: [[String: Any]],
        systemPrompt: String,
        tools: [[String: Any]],
        storeId: UUID?
    ) async -> [String: Any]? {
        guard let apiKey = getAnthropicAPIKey() else {
            print("Missing Anthropic API key")
            return nil
        }

        var body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 8192,
            "system": systemPrompt + (storeId != nil ? "\n\nStore context: store_id=\(storeId!.uuidString)" : ""),
            "messages": messages
        ]

        if !tools.isEmpty {
            body["tools"] = tools
        }

        guard let url = URL(string: anthropicEndpoint) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("Anthropic API error: \(errorText)")
                return nil
            }

            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            print("Anthropic API call failed: \(error)")
            return nil
        }
    }

    // MARK: - Remote Tool Execution

    private func executeRemoteTool(
        name: String,
        input: [String: Any],
        storeId: UUID?
    ) async -> ToolResult {
        // Call Supabase edge function to execute remote tool
        guard let url = URL(string: remoteToolsEndpoint) else {
            return ToolResult(success: false, output: "Invalid remote tools endpoint")
        }

        var body = input
        if let storeId = storeId, body["store_id"] == nil {
            body["store_id"] = storeId.uuidString
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Get user's actual JWT token for user tracking in Edge Function
        let authToken: String
        if let session = try? await SupabaseService.shared.client.auth.session,
           let accessToken = session.accessToken {
            authToken = accessToken
        } else {
            authToken = SupabaseConfig.anonKey // Fallback to anon key
        }

        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "tool": name,
            "input": body
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return ToolResult(success: false, output: "Remote tool execution failed")
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                let output = json["data"] ?? json["error"] ?? "No output"
                let outputString: String
                if let str = output as? String {
                    outputString = str
                } else if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
                          let str = String(data: data, encoding: .utf8) {
                    outputString = str
                } else {
                    outputString = String(describing: output)
                }
                return ToolResult(success: success, output: outputString)
            }

            return ToolResult(success: false, output: "Invalid response format")
        } catch {
            return ToolResult(success: false, output: "Error: \(error.localizedDescription)")
        }
    }

    // MARK: - API Key

    private static let apiKeyName = "anthropic_api_key"

    private func getAnthropicAPIKey() -> String? {
        // Try environment variable first
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            return key
        }
        // Try Keychain
        if let key = KeychainService.read(Self.apiKeyName), !key.isEmpty {
            return key
        }
        // Migrate from UserDefaults (old key names) to Keychain
        let legacyKeys = ["anthropic_api_key", "anthropicApiKey"]
        for legacyKey in legacyKeys {
            if let key = UserDefaults.standard.string(forKey: legacyKey), !key.isEmpty {
                _ = KeychainService.save(Self.apiKeyName, value: key)
                UserDefaults.standard.removeObject(forKey: legacyKey)
                return key
            }
        }
        return nil
    }

    func setAPIKey(_ key: String) {
        _ = KeychainService.save(Self.apiKeyName, value: key)
    }

    var hasAPIKey: Bool {
        getAnthropicAPIKey() != nil
    }
}

