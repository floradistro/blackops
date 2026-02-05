import Foundation
import Combine
import SwiftUI

// MARK: - Chat Timeline Item
// Each item is a distinct entry in the chat timeline - messages, tool calls, etc.

enum ChatTimelineItem: Identifiable, Equatable {
    case userMessage(id: UUID, content: String, timestamp: Date)
    case thinking(id: UUID, timestamp: Date)
    case toolCall(id: UUID, name: String, status: ToolStatus, input: [String: Any]?, result: String?, timestamp: Date)
    case assistantMessage(id: UUID, content: String, isStreaming: Bool, timestamp: Date)
    case error(id: UUID, message: String, timestamp: Date)

    var id: UUID {
        switch self {
        case .userMessage(let id, _, _): return id
        case .thinking(let id, _): return id
        case .toolCall(let id, _, _, _, _, _): return id
        case .assistantMessage(let id, _, _, _): return id
        case .error(let id, _, _): return id
        }
    }

    var timestamp: Date {
        switch self {
        case .userMessage(_, _, let t): return t
        case .thinking(_, let t): return t
        case .toolCall(_, _, _, _, _, let t): return t
        case .assistantMessage(_, _, _, let t): return t
        case .error(_, _, let t): return t
        }
    }

    static func == (lhs: ChatTimelineItem, rhs: ChatTimelineItem) -> Bool {
        switch (lhs, rhs) {
        case (.userMessage(let id1, let c1, _), .userMessage(let id2, let c2, _)):
            return id1 == id2 && c1 == c2
        case (.thinking(let id1, _), .thinking(let id2, _)):
            return id1 == id2
        case (.toolCall(let id1, let n1, let s1, _, let r1, _), .toolCall(let id2, let n2, let s2, _, let r2, _)):
            return id1 == id2 && n1 == n2 && s1 == s2 && r1 == r2
        case (.assistantMessage(let id1, let c1, let s1, _), .assistantMessage(let id2, let c2, let s2, _)):
            return id1 == id2 && c1 == c2 && s1 == s2
        case (.error(let id1, let m1, _), .error(let id2, let m2, _)):
            return id1 == id2 && m1 == m2
        default:
            return false
        }
    }
}

enum ToolStatus: Equatable {
    case running
    case success
    case failed
}

// MARK: - Streaming Text Buffer
// Dedicated class for 60fps text streaming without triggering array diffs

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

@MainActor
class AIChatStore: ObservableObject {
    // MARK: - Published State
    @Published var timeline: [ChatTimelineItem] = []
    @Published var isStreaming = false
    @Published var isGenerating = false  // Always true while agent is working
    @Published var error: String?
    @Published var usage: ChatTokenUsage?

    // Conversation persistence
    @Published var conversationId: String?
    @Published var conversationTitle: String?

    // Dedicated streaming buffer for 60fps updates
    let streamingBuffer = StreamingTextBuffer()

    // Track current streaming message ID
    private var currentStreamingMessageId: UUID?
    private var currentThinkingId: UUID?

    // Track generation state for smooth transitions
    private var pendingThinkingRemoval: UUID?

    // MARK: - Configuration
    var agentId: UUID?
    var storeId: UUID?
    var currentAgent: AIAgent?

    // MARK: - Types

    struct ChatTokenUsage {
        let inputTokens: Int
        let outputTokens: Int
        let totalCost: Double?

        var estimatedCost: Double {
            if let cost = totalCost { return cost }
            let inputCost = Double(inputTokens) * 0.000003
            let outputCost = Double(outputTokens) * 0.000015
            return inputCost + outputCost
        }
    }

    // MARK: - Public API

    func sendMessage(_ text: String) async {
        guard AgentClient.shared.isConnected else {
            error = "Not connected to agent server"
            return
        }

        error = nil
        isStreaming = true
        isGenerating = true
        streamingBuffer.clear()

        // Add user message
        withAnimation(.easeOut(duration: 0.2)) {
            timeline.append(.userMessage(id: UUID(), content: text, timestamp: Date()))
        }

        // Add thinking indicator (will persist until content replaces it)
        let thinkingId = UUID()
        currentThinkingId = thinkingId
        withAnimation(.easeOut(duration: 0.15)) {
            timeline.append(.thinking(id: thinkingId, timestamp: Date()))
        }

        // Build config from current agent
        let systemPrompt = currentAgent?.systemPrompt ?? """
            You are a helpful AI assistant with access to business tools.
            Use the available tools to help answer questions about inventory, orders, customers, and analytics.
            """

        let agentApiKey = currentAgent?.apiKey
        let globalApiKey = UserDefaults.standard.string(forKey: "anthropicApiKey")
        let apiKeyToUse = (agentApiKey?.isEmpty == false ? agentApiKey : nil) ?? globalApiKey

        let config = AgentConfig(
            model: currentAgent?.model,
            maxTurns: 50,
            systemPrompt: systemPrompt,
            enabledTools: currentAgent?.enabledTools,
            agentId: currentAgent?.id.uuidString,
            agentName: currentAgent?.name,
            apiKey: apiKeyToUse
        )

        AgentClient.shared.query(
            prompt: text,
            storeId: storeId,
            config: config,
            conversationId: conversationId,
            onText: { [weak self] (newText: String) in
                guard let self = self else { return }

                // Create streaming message first (before removing thinking)
                if self.currentStreamingMessageId == nil {
                    let messageId = UUID()
                    self.currentStreamingMessageId = messageId

                    // Animate: remove thinking, add message in same transaction
                    withAnimation(.easeInOut(duration: 0.2)) {
                        // Remove thinking indicator
                        if let thinkingId = self.currentThinkingId {
                            self.timeline.removeAll { item in
                                if case .thinking(let id, _) = item { return id == thinkingId }
                                return false
                            }
                            self.currentThinkingId = nil
                        }

                        // Add streaming message
                        self.timeline.append(.assistantMessage(
                            id: messageId,
                            content: "",
                            isStreaming: true,
                            timestamp: Date()
                        ))
                    }
                }

                self.streamingBuffer.append(newText)
            },
            onToolStart: { [weak self] (tool: String, input: [String: Any]) in
                guard let self = self else { return }

                // Finalize any streaming message before tool
                self.finalizeStreamingMessage()

                // Animate: remove thinking, add tool call in same transaction
                withAnimation(.easeInOut(duration: 0.2)) {
                    // Remove thinking indicator
                    if let thinkingId = self.currentThinkingId {
                        self.timeline.removeAll { item in
                            if case .thinking(let id, _) = item { return id == thinkingId }
                            return false
                        }
                        self.currentThinkingId = nil
                    }

                    // Add tool call
                    self.timeline.append(.toolCall(
                        id: UUID(),
                        name: tool,
                        status: .running,
                        input: input,
                        result: nil,
                        timestamp: Date()
                    ))
                }
            },
            onToolResult: { [weak self] (tool: String, success: Bool, result: Any?, errorMsg: String?) in
                guard let self = self else { return }

                // Update last tool call with this name that's running
                if let index = self.timeline.lastIndex(where: { item in
                    if case .toolCall(_, let name, let status, _, _, _) = item {
                        return name == tool && status == .running
                    }
                    return false
                }) {
                    if case .toolCall(let id, let name, _, let input, _, let timestamp) = self.timeline[index] {
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
                            resultString = errorMsg
                        }

                        self.timeline[index] = .toolCall(
                            id: id,
                            name: name,
                            status: success ? .success : .failed,
                            input: input,
                            result: resultString,
                            timestamp: timestamp
                        )
                    }
                }

                // Add new thinking indicator for next response (animated)
                withAnimation(.easeOut(duration: 0.15)) {
                    let thinkingId = UUID()
                    self.currentThinkingId = thinkingId
                    self.timeline.append(.thinking(id: thinkingId, timestamp: Date()))
                }
            },
            onDone: { [weak self] (status: String, returnedConversationId: String, tokenUsage: TokenUsage) in
                guard let self = self else { return }

                // Finalize streaming message first
                self.finalizeStreamingMessage()

                // Remove any remaining thinking indicator (animated)
                withAnimation(.easeOut(duration: 0.2)) {
                    if let thinkingId = self.currentThinkingId {
                        self.timeline.removeAll { item in
                            if case .thinking(let id, _) = item { return id == thinkingId }
                            return false
                        }
                        self.currentThinkingId = nil
                    }
                }

                self.isStreaming = false
                self.isGenerating = false
                self.conversationId = returnedConversationId
                self.usage = ChatTokenUsage(
                    inputTokens: tokenUsage.inputTokens,
                    outputTokens: tokenUsage.outputTokens,
                    totalCost: tokenUsage.totalCost
                )
            },
            onError: { [weak self] (errorMessage: String) in
                guard let self = self else { return }

                self.finalizeStreamingMessage()

                // Animated transition: remove thinking, add error
                withAnimation(.easeInOut(duration: 0.2)) {
                    if let thinkingId = self.currentThinkingId {
                        self.timeline.removeAll { item in
                            if case .thinking(let id, _) = item { return id == thinkingId }
                            return false
                        }
                        self.currentThinkingId = nil
                    }
                    self.timeline.append(.error(id: UUID(), message: errorMessage, timestamp: Date()))
                }

                self.error = errorMessage
                self.isStreaming = false
                self.isGenerating = false
            },
            onConversationCreated: { [weak self] (conv: ConversationMeta) in
                self?.conversationId = conv.id
                self?.conversationTitle = conv.title
                TelemetryService.shared.activeConversationId = conv.id
            }
        )
    }

    private func finalizeStreamingMessage() {
        guard let messageId = currentStreamingMessageId else { return }

        if let index = timeline.firstIndex(where: { item in
            if case .assistantMessage(let id, _, _, _) = item { return id == messageId }
            return false
        }) {
            if case .assistantMessage(let id, _, _, let timestamp) = timeline[index] {
                let finalContent = streamingBuffer.text
                if !finalContent.isEmpty {
                    timeline[index] = .assistantMessage(
                        id: id,
                        content: finalContent,
                        isStreaming: false,
                        timestamp: timestamp
                    )
                } else {
                    // Remove empty message
                    timeline.remove(at: index)
                }
            }
        }

        currentStreamingMessageId = nil
        streamingBuffer.clear()
    }

    func clearConversation() {
        withAnimation(.easeOut(duration: 0.2)) {
            timeline.removeAll()
        }
        conversationId = nil
        conversationTitle = nil
        error = nil
        usage = nil
        streamingBuffer.clear()
        currentStreamingMessageId = nil
        currentThinkingId = nil
        isGenerating = false

        TelemetryService.shared.activeConversationId = nil
        AgentClient.shared.newConversation()
    }

    /// Restore timeline from stored messages (for loading past conversations)
    /// Messages are in Anthropic API format: [{role, content: [ContentBlock], createdAt}]
    func restoreTimeline(from messages: [[String: Any]], conversationId: String, title: String?) {
        self.conversationId = conversationId
        self.conversationTitle = title
        self.error = nil
        self.usage = nil
        self.streamingBuffer.clear()
        self.currentStreamingMessageId = nil
        self.currentThinkingId = nil
        self.isGenerating = false

        var restored: [ChatTimelineItem] = []
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]

        func parseDate(_ str: String?) -> Date {
            guard let str else { return Date() }
            return isoFractional.date(from: str) ?? isoBasic.date(from: str) ?? Date()
        }

        for msg in messages {
            guard let role = msg["role"] as? String,
                  let contentBlocks = msg["content"] as? [[String: Any]] else { continue }
            let timestamp = parseDate(msg["createdAt"] as? String)

            if role == "user" {
                // Check if this is a tool_result message or a regular user message
                if let firstBlock = contentBlocks.first,
                   firstBlock["type"] as? String == "tool_result" {
                    // Tool results — skip, already represented by the tool_call row
                    continue
                }
                // Regular user message — extract text
                let text = contentBlocks.compactMap { block -> String? in
                    if block["type"] as? String == "text" {
                        return block["text"] as? String
                    }
                    return nil
                }.joined()
                if !text.isEmpty {
                    restored.append(.userMessage(id: UUID(), content: text, timestamp: timestamp))
                }
            } else if role == "assistant" {
                // Assistant messages can contain text blocks and tool_use blocks
                for block in contentBlocks {
                    let blockType = block["type"] as? String
                    if blockType == "text", let text = block["text"] as? String, !text.isEmpty {
                        restored.append(.assistantMessage(id: UUID(), content: text, isStreaming: false, timestamp: timestamp))
                    } else if blockType == "tool_use" {
                        let toolName = block["name"] as? String ?? "unknown"
                        // Tool calls from history are always completed
                        restored.append(.toolCall(
                            id: UUID(),
                            name: toolName,
                            status: .success,
                            input: block["input"] as? [String: Any],
                            result: nil,
                            timestamp: timestamp
                        ))
                    }
                }
            }
        }

        withAnimation(.easeOut(duration: 0.2)) {
            timeline = restored
        }

        TelemetryService.shared.activeConversationId = conversationId
        AgentClient.shared.selectConversation(conversationId)
    }

    func retryLastMessage() async {
        // Find last user message
        guard let lastUserItem = timeline.last(where: { item in
            if case .userMessage = item { return true }
            return false
        }),
        case .userMessage(_, let content, _) = lastUserItem else { return }

        // Remove everything after and including last user message
        if let index = timeline.lastIndex(where: { $0.id == lastUserItem.id }) {
            timeline.removeSubrange(index...)
        }

        await sendMessage(content)
    }
}
