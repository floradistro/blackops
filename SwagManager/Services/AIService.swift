import Foundation

// MARK: - AI Service (Wilson Integration)

final class AIService: @unchecked Sendable {
    static let shared = AIService()

    // Supabase config - same as Wilson uses
    private let apiUrl = "https://uaednwpxursknmwdeejn.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg"

    // Wilson CLI paths - try multiple locations
    private let wilsonPaths = [
        "/usr/local/bin/wilson",
        "/opt/homebrew/bin/wilson",
        "\(NSHomeDirectory())/.bun/bin/wilson",
        "\(NSHomeDirectory())/Desktop/wilson/dist/index.js"
    ]

    // Execution mode
    enum ExecutionMode {
        case local      // Spawn Wilson CLI subprocess
        case cloud      // Call cloud API
        case auto       // Try local first, fallback to cloud
    }

    var preferredMode: ExecutionMode = .auto

    // MARK: - Streaming Events

    enum StreamEvent: Sendable {
        case text(String)                    // Text chunk
        case toolStart(name: String, id: String)  // Tool started executing
        case toolResult(name: String, id: String) // Tool result received
        case toolsPending(names: [String])   // Tools waiting to execute
        case usage(input: Int, output: Int)  // Token usage
        case done                            // Stream complete
        case error(String)                   // Error occurred
    }

    private init() {}

    // MARK: - Slash Commands

    enum SlashCommand: String, CaseIterable {
        case summarize = "/summarize"
        case inventory = "/inventory"
        case sales = "/sales"
        case orders = "/orders"
        case products = "/products"
        case help = "/help"
        case analyze = "/analyze"
        case report = "/report"
        case lowstock = "/lowstock"
        case topsellers = "/topsellers"

        var description: String {
            switch self {
            case .summarize: return "Summarize recent activity"
            case .inventory: return "Check inventory levels"
            case .sales: return "View sales data"
            case .orders: return "View recent orders"
            case .products: return "Search products"
            case .help: return "Show available commands"
            case .analyze: return "Analyze data or trends"
            case .report: return "Generate a report"
            case .lowstock: return "Show low stock items"
            case .topsellers: return "Show top selling products"
            }
        }

        var icon: String {
            switch self {
            case .summarize: return "doc.text"
            case .inventory: return "shippingbox"
            case .sales: return "chart.bar"
            case .orders: return "bag"
            case .products: return "magnifyingglass"
            case .help: return "questionmark.circle"
            case .analyze: return "chart.xyaxis.line"
            case .report: return "doc.richtext"
            case .lowstock: return "exclamationmark.triangle"
            case .topsellers: return "star"
            }
        }
    }

    // MARK: - Quick Actions

    struct QuickAction: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let prompt: String
    }

    static let quickActions: [QuickAction] = [
        QuickAction(label: "Today's sales", icon: "chart.bar", prompt: "@lisa what were today's sales?"),
        QuickAction(label: "Low stock", icon: "exclamationmark.triangle", prompt: "@lisa show me low stock items"),
        QuickAction(label: "Recent orders", icon: "bag", prompt: "@lisa show recent orders"),
        QuickAction(label: "Top products", icon: "star", prompt: "@lisa what are the top selling products this week?"),
    ]

    // MARK: - Message Parsing

    struct ParsedMessage {
        let rawContent: String
        let hasAIMention: Bool
        let hasMentions: [String]
        let slashCommand: SlashCommand?
        let commandArgs: String?
        let cleanContent: String
    }

    func parseMessage(_ content: String) -> ParsedMessage {
        var hasAIMention = false
        let mentions: [String] = []
        var slashCommand: SlashCommand?
        var commandArgs: String?
        var cleanContent = content

        // Check for AI mentions
        let aiMentionPatterns = ["@lisa", "@ai", "@assistant", "@wilson"]
        for pattern in aiMentionPatterns {
            if content.lowercased().contains(pattern) {
                hasAIMention = true
                cleanContent = cleanContent.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
            }
        }

        // Check for slash commands
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        for cmd in SlashCommand.allCases {
            if trimmed.lowercased().hasPrefix(cmd.rawValue) {
                slashCommand = cmd
                hasAIMention = true
                let afterCommand = String(trimmed.dropFirst(cmd.rawValue.count)).trimmingCharacters(in: .whitespaces)
                commandArgs = afterCommand.isEmpty ? nil : afterCommand
                cleanContent = afterCommand
                break
            }
        }

        return ParsedMessage(
            rawContent: content,
            hasAIMention: hasAIMention,
            hasMentions: mentions,
            slashCommand: slashCommand,
            commandArgs: commandArgs,
            cleanContent: cleanContent.trimmingCharacters(in: .whitespaces)
        )
    }

    // MARK: - AI Context

    struct AIContext {
        let storeId: UUID?
        let storeName: String?
        let catalogId: UUID?
        let catalogName: String?
        let locationId: UUID?
        let locationName: String?
        let selectedProductId: UUID?
        let selectedProductName: String?
        let selectedCategoryId: UUID?
        let selectedCategoryName: String?
        let conversationHistory: [ChatMessage]
        let slashCommand: SlashCommand?
        let commandArgs: String?
    }

    // MARK: - Find Wilson CLI

    private func findWilsonPath() -> String? {
        // Check if wilson is in PATH
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["wilson"]
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        whichProcess.standardError = FileHandle.nullDevice

        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            if whichProcess.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {}

        // Check known paths
        for path in wilsonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }

    // MARK: - Invoke AI (Main Entry Point)

    func invokeAI(
        message: String,
        context: AIContext,
        supabase: SupabaseService
    ) async throws -> String {
        switch preferredMode {
        case .local:
            return try await invokeWilsonLocal(message: message, context: context)
        case .cloud:
            return try await invokeWilsonCloud(message: message, context: context, supabase: supabase)
        case .auto:
            // Try local first, fallback to cloud
            if findWilsonPath() != nil {
                do {
                    return try await invokeWilsonLocal(message: message, context: context)
                } catch AIError.wilsonNotInstalled {
                    // Fall through to cloud
                } catch {
                    // Log but try cloud as backup
                    print("Wilson local failed: \(error.localizedDescription), falling back to cloud")
                }
            }
            return try await invokeWilsonCloud(message: message, context: context, supabase: supabase)
        }
    }

    // MARK: - Streaming AI (Returns AsyncThrowingStream)

    func streamAI(
        message: String,
        context: AIContext,
        supabase: SupabaseService
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Always use cloud API for streaming - most reliable
                    guard let session = try? await supabase.client.auth.session else {
                        continuation.finish(throwing: AIError.notAuthenticated)
                        return
                    }

                    let accessToken = session.accessToken

                    let history = context.conversationHistory.suffix(20).map { msg -> [String: Any] in
                        return ["role": msg.role, "content": msg.content]
                    }

                    let body: [String: Any] = [
                        "message": message,
                        "history": Array(history),
                        "store_id": context.storeId?.uuidString ?? "",
                        "platform": "darwin",
                        "client": "swagmanager-desktop",
                        "format_hint": "markdown",
                        "execute_tools": true,  // Execute tools server-side, don't pause for client
                        "auto_execute": true,   // Auto-continue after tool execution
                        "style_instructions": """
                            SwagManager Desktop App. Format for rich display:
                            - Use markdown tables for data
                            - Use code blocks for technical output
                            - Keep responses concise but complete
                            - Include relevant metrics and numbers
                            """
                    ]

                    guard let url = URL(string: "\(self.apiUrl)/functions/v1/agentic-loop") else {
                        continuation.finish(throwing: AIError.invalidURL)
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    request.setValue(self.anonKey, forHTTPHeaderField: "apikey")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    request.timeoutInterval = 120

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AIError.invalidResponse)
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: AIError.apiError(statusCode: httpResponse.statusCode))
                        return
                    }

                    // Parse SSE stream
                    for try await line in bytes.lines {
                        NSLog("[AIService] SSE line: \(line.prefix(200))")

                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))

                            if jsonString == "[DONE]" {
                                NSLog("[AIService] Stream done")
                                continuation.yield(.done)
                                break
                            }

                            if let data = jsonString.data(using: .utf8),
                               let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                                NSLog("[AIService] Event type: \(event["type"] ?? "none")")

                                if let streamEvent = self.parseStreamEvent(event) {
                                    NSLog("[AIService] Yielding event: \(streamEvent)")
                                    continuation.yield(streamEvent)

                                    // Check for error
                                    if case .error(let msg) = streamEvent {
                                        continuation.finish(throwing: AIError.backendError(msg))
                                        return
                                    }
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // Parse SSE event JSON into StreamEvent
    private func parseStreamEvent(_ event: [String: Any]) -> StreamEvent? {
        guard let eventType = event["type"] as? String else {
            // Check for direct text
            if let text = event["text"] as? String {
                return .text(text)
            }
            return nil
        }

        switch eventType {
        case "text_delta", "text", "chunk":
            if let text = event["text"] as? String {
                return .text(text)
            }
            return nil

        case "content_block_delta":
            if let delta = event["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                return .text(text)
            }
            return nil

        case "tool_start", "tool_use":
            let name = event["tool_name"] as? String ?? (event["tool"] as? [String: Any])?["name"] as? String ?? "tool"
            let id = event["tool_id"] as? String ?? (event["tool"] as? [String: Any])?["id"] as? String ?? ""
            return .toolStart(name: name, id: id)

        case "content_block_start":
            if let block = event["content_block"] as? [String: Any],
               block["type"] as? String == "tool_use" {
                let name = block["name"] as? String ?? "tool"
                let id = block["id"] as? String ?? ""
                return .toolStart(name: name, id: id)
            }
            return nil

        case "tool_result", "tool_error":
            let name = event["tool_name"] as? String ?? "tool"
            let id = event["tool_id"] as? String ?? ""
            return .toolResult(name: name, id: id)

        case "pause_for_tools":
            // SwagManager doesn't execute tools locally - just extract any text
            // from the assistant_content and treat it as the response
            if let assistantContent = event["assistant_content"] as? [[String: Any]] {
                var textParts: [String] = []
                for block in assistantContent {
                    if block["type"] as? String == "text",
                       let text = block["text"] as? String {
                        textParts.append(text)
                    }
                }
                if !textParts.isEmpty {
                    return .text(textParts.joined(separator: "\n\n"))
                }
            }
            // If there's no text but tools are pending, show a message
            if let tools = event["pending_tools"] as? [[String: Any]] {
                let names = tools.compactMap { $0["name"] as? String }
                if !names.isEmpty {
                    return .toolsPending(names: names)
                }
            }
            return nil

        case "usage", "message_delta":
            if let usage = event["usage"] as? [String: Any] {
                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                return .usage(input: input, output: output)
            }
            return nil

        case "error":
            let msg = event["error"] as? String ?? event["message"] as? String ?? "Unknown error"
            return .error(msg)

        case "done", "message_stop":
            return .done

        default:
            return nil
        }
    }

    // MARK: - Invoke Wilson CLI (Local Subprocess)

    func invokeWilsonLocal(
        message: String,
        context: AIContext
    ) async throws -> String {
        guard let wilsonPath = findWilsonPath() else {
            throw AIError.wilsonNotInstalled
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()

                // Determine how to run wilson
                if wilsonPath.hasSuffix(".js") {
                    // Run via bun
                    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/bun")
                    if !FileManager.default.fileExists(atPath: "/usr/local/bin/bun") {
                        // Try homebrew bun
                        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/bun")
                    }
                    process.arguments = ["run", wilsonPath, "test", message]
                } else {
                    // Run directly
                    process.executableURL = URL(fileURLWithPath: wilsonPath)
                    process.arguments = ["test", message]
                }

                // Set environment with store context
                var env = ProcessInfo.processInfo.environment
                if let storeId = context.storeId {
                    env["WILSON_STORE_ID"] = storeId.uuidString
                }
                if let storeName = context.storeName {
                    env["WILSON_STORE_NAME"] = storeName
                }
                process.environment = env

                // Capture output
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                // Set timeout
                let timeoutItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: timeoutItem)

                do {
                    try process.run()
                    process.waitUntilExit()
                    timeoutItem.cancel()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    if process.terminationStatus != 0 {
                        let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: AIError.wilsonProcessError(errorString))
                        return
                    }

                    guard let output = String(data: outputData, encoding: .utf8) else {
                        continuation.resume(throwing: AIError.emptyResponse)
                        return
                    }

                    // Parse Wilson output - strip ANSI codes and extract response
                    let cleanedOutput = self.stripANSICodes(output)
                    let responseText = self.extractWilsonResponse(cleanedOutput)

                    if responseText.isEmpty {
                        continuation.resume(throwing: AIError.emptyResponse)
                    } else {
                        continuation.resume(returning: responseText)
                    }
                } catch {
                    timeoutItem.cancel()
                    continuation.resume(throwing: AIError.wilsonProcessError(error.localizedDescription))
                }
            }
        }
    }

    // Strip ANSI escape codes from terminal output
    private func stripANSICodes(_ text: String) -> String {
        // Match ANSI escape sequences: ESC[ followed by params and ending with a letter
        let pattern = "\\x1B\\[[0-9;]*[A-Za-z]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    // Extract the actual response from Wilson CLI output
    private func extractWilsonResponse(_ output: String) -> String {
        let lines = output.components(separatedBy: "\n")

        // Skip header lines, tool output markers, and capture the main response
        var responseLines: [String] = []
        var inResponse = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines at start
            if !inResponse && trimmed.isEmpty { continue }

            // Skip Wilson CLI header
            if trimmed.contains("Wilson CLI Test") { continue }
            if trimmed.hasPrefix("Store:") { continue }
            if trimmed.hasPrefix("❯") { continue }

            // Skip tool execution markers
            if trimmed.hasPrefix("⟳") || trimmed.hasPrefix("✓") || trimmed.hasPrefix("✗") { continue }
            if trimmed.hasPrefix("╭─") || trimmed.hasPrefix("╰─") || trimmed.hasPrefix("│") { continue }
            if trimmed.hasPrefix("[TOOL") { continue }
            if trimmed.contains("Continuation") { continue }

            // Skip final separator
            if trimmed.hasPrefix("─────") {
                if inResponse { break }
                continue
            }

            // Start capturing response content
            inResponse = true
            responseLines.append(line)
        }

        return responseLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Invoke Wilson Cloud API

    func invokeWilsonCloud(
        message: String,
        context: AIContext,
        supabase: SupabaseService
    ) async throws -> String {
        // Get the user's access token
        guard let session = try? await supabase.client.auth.session else {
            throw AIError.notAuthenticated
        }

        let accessToken = session.accessToken

        // Build conversation history for the API
        let history = context.conversationHistory.suffix(20).map { msg -> [String: Any] in
            return [
                "role": msg.role,
                "content": msg.content
            ]
        }

        // Build the request body (matching Wilson's format)
        let body: [String: Any] = [
            "message": message,
            "history": Array(history),
            "store_id": context.storeId?.uuidString ?? "",
            "platform": "darwin",
            "client": "swagmanager-desktop",
            "format_hint": "markdown",
            "execute_tools": true,  // Execute tools server-side
            "auto_execute": true,   // Auto-continue after tool execution
            "style_instructions": """
                SwagManager Desktop App. Format for rich display:
                - Use markdown tables for data
                - Use code blocks for technical output
                - Keep responses concise but complete
                - Include relevant metrics and numbers
                """
        ]

        // Create the request
        guard let url = URL(string: "\(apiUrl)/functions/v1/agentic-loop") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        // Make the request and collect SSE response
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIError.apiError(statusCode: httpResponse.statusCode)
        }

        // Parse SSE stream and collect text
        var fullResponse = ""

        for try await line in bytes.lines {
            // SSE format: "data: {...}"
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))

                if jsonString == "[DONE]" {
                    break
                }

                if let data = jsonString.data(using: .utf8),
                   let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    // Handle different event types
                    if let eventType = event["type"] as? String {
                        switch eventType {
                        case "text_delta":
                            if let text = event["text"] as? String {
                                fullResponse += text
                            }
                        case "content_block_delta":
                            if let delta = event["delta"] as? [String: Any],
                               let text = delta["text"] as? String {
                                fullResponse += text
                            }
                        case "error":
                            if let errorMsg = event["error"] as? String {
                                throw AIError.backendError(errorMsg)
                            }
                        default:
                            break
                        }
                    }

                    // Also check for direct text field (some backends)
                    if let text = event["text"] as? String, fullResponse.isEmpty {
                        fullResponse += text
                    }
                }
            }
        }

        if fullResponse.isEmpty {
            // Fallback if streaming didn't work - might be direct response
            throw AIError.emptyResponse
        }

        return fullResponse
    }

    // MARK: - Errors

    enum AIError: LocalizedError {
        case notAuthenticated
        case invalidURL
        case invalidResponse
        case apiError(statusCode: Int)
        case backendError(String)
        case emptyResponse
        case wilsonNotInstalled
        case wilsonProcessError(String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Not authenticated. Please log in."
            case .invalidURL:
                return "Invalid API URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .apiError(let code):
                return "API error: \(code)"
            case .backendError(let msg):
                return "Backend error: \(msg)"
            case .emptyResponse:
                return "Empty response from AI"
            case .wilsonNotInstalled:
                return "Wilson CLI not installed. Install with: bun install -g wilson"
            case .wilsonProcessError(let msg):
                return "Wilson error: \(msg)"
            }
        }
    }

    // MARK: - Status Check

    /// Check if Wilson CLI is available locally
    var isWilsonAvailable: Bool {
        findWilsonPath() != nil
    }

    /// Get the current execution mode description
    var executionModeDescription: String {
        switch preferredMode {
        case .local:
            return isWilsonAvailable ? "Local (Wilson CLI)" : "Local (not available)"
        case .cloud:
            return "Cloud API"
        case .auto:
            return isWilsonAvailable ? "Auto (local preferred)" : "Auto (cloud only)"
        }
    }
}

// MARK: - String Extensions

extension String {
    var containsAIMention: Bool {
        let patterns = ["@lisa", "@ai", "@assistant", "@wilson"]
        let lowercased = self.lowercased()
        return patterns.contains { lowercased.contains($0) }
    }

    var startsWithSlashCommand: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespaces).lowercased()
        return AIService.SlashCommand.allCases.contains { trimmed.hasPrefix($0.rawValue) }
    }

    var shouldInvokeAI: Bool {
        containsAIMention || startsWithSlashCommand
    }
}
