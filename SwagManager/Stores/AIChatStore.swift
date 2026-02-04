import Foundation
import Combine
import SwiftUI

// MARK: - Streaming Text Buffer
// Dedicated class for 60fps text streaming without triggering array diffs
// This is the pattern used by Apple's Messages app and Anthropic's Claude apps

@MainActor
class StreamingTextBuffer: ObservableObject {
    @Published var text: String = ""

    func append(_ newText: String) {
        text += newText
    }

    func clear() {
        text = ""
    }
}

// MARK: - AI Chat Store
// Manages streaming chat with Claude agent via edge function
// Follows Anthropic SDK patterns for agentic conversations

@MainActor
class AIChatStore: ObservableObject {
    // MARK: - Published State
    @Published var messages: [AIChatMessage] = []
    @Published var isStreaming = false
    @Published var currentToolExecution: String?
    @Published var error: String?
    @Published var usage: ChatTokenUsage?
    @Published var useLocalAgent = true  // Use local Agent SDK server with file tools
    @Published var includeCodeTools = true  // Toggle for coding capabilities
    @Published var attachedFolders: [URL] = []  // Folders/files attached to context

    // Dedicated streaming buffer for 60fps updates (avoids array diffing)
    let streamingBuffer = StreamingTextBuffer()

    // MARK: - Configuration
    var agentId: UUID?
    var storeId: UUID?
    var currentAgent: AIAgent?  // Full agent config for local queries
    private var conversationId = UUID()

    // Fallback to Supabase edge function
    private let remoteEndpoint = "claude-agent"

    // MARK: - Types

    struct AIChatMessage: Identifiable, Equatable {
        let id: UUID
        let role: Role
        var content: String
        let timestamp: Date
        var toolCalls: [ToolCall]?
        var isStreaming: Bool = false  // True while text is being streamed

        enum Role: String {
            case user
            case assistant
            case system
        }

        struct ToolCall: Equatable, Identifiable {
            let id: UUID
            let name: String
            var status: ToolStatus
            var result: String?

            enum ToolStatus: Equatable {
                case running
                case success
                case failed
            }

            init(name: String, status: ToolStatus = .running, result: String? = nil) {
                self.id = UUID()
                self.name = name
                self.status = status
                self.result = result
            }
        }

        init(role: Role, content: String, toolCalls: [ToolCall]? = nil, isStreaming: Bool = false) {
            self.id = UUID()
            self.role = role
            self.content = content
            self.timestamp = Date()
            self.toolCalls = toolCalls
            self.isStreaming = isStreaming
        }
    }

    struct ChatTokenUsage {
        let inputTokens: Int
        let outputTokens: Int
        let totalCost: Double?

        var estimatedCost: Double {
            if let cost = totalCost { return cost }
            // Claude Sonnet pricing: $3/MTok input, $15/MTok output
            let inputCost = Double(inputTokens) * 0.000003
            let outputCost = Double(outputTokens) * 0.000015
            return inputCost + outputCost
        }

        init(inputTokens: Int, outputTokens: Int, totalCost: Double? = nil) {
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.totalCost = totalCost
        }
    }

    // MARK: - Stream Events (matches edge function output)

    private struct StreamEvent: Decodable {
        let type: String
        let text: String?
        let name: String?
        let success: Bool?
        let result: StreamAnyCodable?
        let error: String?
        let usage: UsageData?

        struct UsageData: Decodable {
            let input_tokens: Int
            let output_tokens: Int
        }
    }

    // MARK: - Public API

    func sendMessage(_ text: String) async {
        // Try local agent first if enabled
        print("[AIChatStore] sendMessage: useLocalAgent=\(useLocalAgent), isConnected=\(AgentClient.shared.isConnected)")
        if useLocalAgent && AgentClient.shared.isConnected {
            print("[AIChatStore] Using LOCAL agent")
            await sendMessageViaLocalAgent(text)
            return
        }

        // Fallback to remote (Supabase edge function)
        print("[AIChatStore] Using REMOTE agent (fallback)")
        await sendMessageViaRemote(text)
    }

    // MARK: - Local Agent (Claude Agent SDK)

    private func sendMessageViaLocalAgent(_ text: String) async {
        error = nil
        isStreaming = true
        currentToolExecution = nil

        // Add user message
        messages.append(AIChatMessage(role: .user, content: text))

        // Create placeholder for assistant response
        // During streaming, text goes to streamingBuffer (60fps) not the message array
        let assistantMessage = AIChatMessage(role: .assistant, content: "", isStreaming: true)
        let assistantMessageId = assistantMessage.id
        messages.append(assistantMessage)

        // Clear streaming buffer for new message
        streamingBuffer.clear()

        // Build prompt with folder context
        let folderContext = buildFolderContext()
        let fullPrompt = folderContext + text

        // Extract paths from attached folders for context file reading
        let paths = attachedFolders.map { $0.path }

        // Build config from current agent if available
        print("[AIChatStore] currentAgent: \(currentAgent?.name ?? "nil")")
        print("[AIChatStore] currentAgent.systemPrompt: \(currentAgent?.systemPrompt?.prefix(50) ?? "nil")")
        print("[AIChatStore] currentAgent.enabledTools: \(String(describing: currentAgent?.enabledTools))")

        // Use agent's system prompt or a sensible default
        let systemPrompt = currentAgent?.systemPrompt ?? """
            You are a helpful AI assistant with access to business tools.
            Use the available tools to help answer questions about inventory, orders, customers, and analytics.
            Be concise and professional in your responses.
            """

        // Use agent-specific API key, or fall back to global settings key
        let agentApiKey = currentAgent?.apiKey
        let globalApiKey = UserDefaults.standard.string(forKey: "anthropicApiKey")
        let apiKeyToUse = (agentApiKey?.isEmpty == false ? agentApiKey : nil) ?? globalApiKey

        print("[AIChatStore] agentApiKey: \(agentApiKey?.prefix(20) ?? "nil")")
        print("[AIChatStore] globalApiKey: \(globalApiKey?.prefix(20) ?? "nil")")
        print("[AIChatStore] apiKeyToUse: \(apiKeyToUse?.prefix(20) ?? "nil")")

        let config = AgentConfig(
            model: currentAgent?.model,
            maxTurns: 50,
            systemPrompt: systemPrompt,
            enabledTools: currentAgent?.enabledTools,
            agentId: currentAgent?.id.uuidString,
            agentName: currentAgent?.name,
            apiKey: apiKeyToUse
        )

        print("[AIChatStore] config.systemPrompt: \(config.systemPrompt?.prefix(50) ?? "nil")")
        print("[AIChatStore] config.enabledTools: \(String(describing: config.enabledTools))")

        AgentClient.shared.query(
            prompt: fullPrompt,
            storeId: storeId,
            config: config,
            attachedPaths: paths,
            onText: { [weak self] (newText: String) in
                guard let self = self else { return }
                // Use streaming buffer for 60fps updates (no array diffing)
                self.streamingBuffer.append(newText)
            },
            onToolStart: { [weak self] (tool: String, input: [String: Any]) in
                guard let self = self else { return }
                print("[AIChatStore] onToolStart: \(tool) input: \(input)")
                self.currentToolExecution = tool
                // Add tool call immediately in "running" state
                if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    var updatedMessage = self.messages[index]
                    var tools = updatedMessage.toolCalls ?? []
                    tools.append(AIChatMessage.ToolCall(name: tool, status: .running))
                    updatedMessage.toolCalls = tools
                    self.messages[index] = updatedMessage
                }
            },
            onToolResult: { [weak self] (tool: String, success: Bool, result: Any?, error: String?) in
                guard let self = self else { return }
                print("[AIChatStore] onToolResult: \(tool) success=\(success)")
                self.currentToolExecution = nil

                // Convert result to string safely
                let resultString: String?
                if let result = result {
                    if JSONSerialization.isValidJSONObject(result),
                       let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
                       let str = String(data: data, encoding: .utf8) {
                        resultString = str
                    } else {
                        resultString = String(describing: result)
                    }
                } else {
                    resultString = error
                }

                // Update existing tool call status
                if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    var updatedMessage = self.messages[index]
                    if var tools = updatedMessage.toolCalls,
                       let toolIndex = tools.lastIndex(where: { $0.name == tool && $0.status == .running }) {
                        tools[toolIndex].status = success ? .success : .failed
                        tools[toolIndex].result = resultString
                        updatedMessage.toolCalls = tools
                        self.messages[index] = updatedMessage
                    }
                }
            },
            onDone: { [weak self] (status: String, tokenUsage: TokenUsage) in
                guard let self = self else { return }
                self.isStreaming = false
                self.currentToolExecution = nil
                // Copy final text from streaming buffer to message array (single update)
                if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    var updatedMessage = self.messages[index]
                    updatedMessage.content = self.streamingBuffer.text
                    updatedMessage.isStreaming = false
                    self.messages[index] = updatedMessage
                }
                self.usage = ChatTokenUsage(
                    inputTokens: tokenUsage.inputTokens,
                    outputTokens: tokenUsage.outputTokens,
                    totalCost: tokenUsage.totalCost
                )
            },
            onError: { [weak self] (errorMessage: String) in
                print("[AIChatStore] onError: \(errorMessage)")
                self?.error = errorMessage
                self?.isStreaming = false
                self?.currentToolExecution = nil
            }
        )
    }

    // MARK: - Remote Agent (Supabase Edge Function)

    private func sendMessageViaRemote(_ text: String) async {
        guard let agentId = agentId else {
            error = "No agent selected"
            return
        }

        // Reset state
        error = nil
        isStreaming = true
        currentToolExecution = nil

        // Add user message
        messages.append(AIChatMessage(role: .user, content: text))

        // Create placeholder for assistant response (streaming mode for performance)
        let assistantMessage = AIChatMessage(role: .assistant, content: "", isStreaming: true)
        let assistantMessageId = assistantMessage.id
        messages.append(assistantMessage)

        // Clear streaming buffer for new message
        streamingBuffer.clear()

        // Build request - use enhanced claude-agent endpoint
        guard let url = URL(string: "\(SupabaseConfig.url)/functions/v1/\(remoteEndpoint)") else {
            error = "Invalid URL"
            isStreaming = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build conversation history (exclude current exchange)
        let history: [[String: String]] = messages.dropLast(2).map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        }

        // Build message with folder context
        let folderContext = buildFolderContext()
        let fullMessage = folderContext + text

        // Build paths as simple string array
        let paths: [String] = attachedFolders.map { $0.path }

        let body: [String: Any] = [
            "agentId": agentId.uuidString,
            "storeId": storeId?.uuidString ?? "",
            "message": fullMessage,
            "conversationHistory": history,
            "includeCodeTools": includeCodeTools,
            "attachedPaths": paths
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            self.error = "Failed to encode request: \(error.localizedDescription)"
            print("[AIChatStore] JSON encoding error: \(error)")
            isStreaming = false
            return
        }

        // Stream response
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                error = "Server error"
                isStreaming = false
                return
            }

            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let jsonString = String(line.dropFirst(6))

                guard let data = jsonString.data(using: .utf8),
                      let event = try? JSONDecoder().decode(StreamEvent.self, from: data)
                else { continue }

                switch event.type {
                case "text":
                    if let text = event.text {
                        // Use streaming buffer for 60fps updates
                        streamingBuffer.append(text)
                    }

                case "tool_start":
                    currentToolExecution = event.name
                    // Add tool immediately in running state
                    if let name = event.name,
                       let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        var updatedMessage = messages[index]
                        var tools = updatedMessage.toolCalls ?? []
                        tools.append(AIChatMessage.ToolCall(name: name, status: .running))
                        updatedMessage.toolCalls = tools
                        messages[index] = updatedMessage
                    }

                case "tool_result":
                    currentToolExecution = nil
                    if let name = event.name {
                        let resultString: String?
                        if let result = event.result {
                            if JSONSerialization.isValidJSONObject(result.value ?? ""),
                               let data = try? JSONSerialization.data(withJSONObject: result.value ?? "", options: .prettyPrinted),
                               let str = String(data: data, encoding: .utf8) {
                                resultString = str
                            } else {
                                resultString = String(describing: result.value)
                            }
                        } else {
                            resultString = nil
                        }
                        // Update tool status
                        if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                            var updatedMessage = messages[index]
                            if var tools = updatedMessage.toolCalls,
                               let toolIndex = tools.lastIndex(where: { $0.name == name && $0.status == .running }) {
                                tools[toolIndex].status = (event.success ?? false) ? .success : .failed
                                tools[toolIndex].result = resultString
                                updatedMessage.toolCalls = tools
                                messages[index] = updatedMessage
                            }
                        }
                    }

                case "usage":
                    if let usageData = event.usage {
                        usage = ChatTokenUsage(
                            inputTokens: usageData.input_tokens,
                            outputTokens: usageData.output_tokens
                        )
                    }

                case "error":
                    self.error = event.error ?? "Unknown error"

                case "done":
                    // Tool calls are now updated incrementally, nothing to do here
                    break

                default:
                    break
                }
            }

        } catch {
            self.error = error.localizedDescription
        }

        // Copy final text from streaming buffer to message array (single update)
        if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
            var updatedMessage = messages[index]
            updatedMessage.content = streamingBuffer.text
            updatedMessage.isStreaming = false
            messages[index] = updatedMessage
        }

        isStreaming = false
        currentToolExecution = nil
    }

    func clearConversation() {
        messages.removeAll()
        conversationId = UUID()
        error = nil
        usage = nil
        attachedFolders.removeAll()
        streamingBuffer.clear()
    }

    // MARK: - Folder Management

    func addFolder(_ url: URL) {
        guard !attachedFolders.contains(url) else { return }
        attachedFolders.append(url)
    }

    func removeFolder(_ url: URL) {
        attachedFolders.removeAll { $0 == url }
    }

    func removeFolder(at index: Int) {
        guard attachedFolders.indices.contains(index) else { return }
        attachedFolders.remove(at: index)
    }

    /// Build context prefix for attached folders
    private func buildFolderContext() -> String {
        guard !attachedFolders.isEmpty else { return "" }

        var context = "\n\n[ATTACHED CONTEXT]\nThe user has attached the following folders/files for you to work with:\n"
        for url in attachedFolders {
            let path = url.path
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            context += "- \(path) (\(isDir ? "folder" : "file"))\n"
        }
        context += "\nYou can use the local tools (read_file, list_directory, search_files, search_content, etc.) to explore and work with these paths.\n[/ATTACHED CONTEXT]\n\n"
        return context
    }

    func retryLastMessage() async {
        guard let lastUserMessage = messages.last(where: { $0.role == .user }) else { return }

        // Remove last exchange
        if let lastAssistantIndex = messages.lastIndex(where: { $0.role == .assistant }) {
            messages.remove(at: lastAssistantIndex)
        }
        if let lastUserIndex = messages.lastIndex(where: { $0.role == .user }) {
            messages.remove(at: lastUserIndex)
        }

        await sendMessage(lastUserMessage.content)
    }
}

// MARK: - StreamAnyCodable Helper

private struct StreamAnyCodable: Decodable {
    let value: Any?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = nil
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([StreamAnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: StreamAnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = nil
        }
    }
}
