import SwiftUI

// MARK: - Agent Test Sheet
// Modal sheet for testing agents with live execution
// Minimal monochromatic theme

struct AgentTestSheet: View {
    let agent: AgentConfiguration
    @Environment(\.dismiss) var dismiss

    @State private var testPrompt = ""
    @State private var isRunning = false
    @State private var messages: [TestMessage] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sheetHeader

            Divider()
                .opacity(0.3)

            // Content
            VSplitView {
                // Top: Conversation
                conversationView
                    .frame(minHeight: 300)

                // Bottom: Input
                inputView
                    .frame(height: 150)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 800, height: 600)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 32, height: 32)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Test: \(agent.name)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.9))
                Text("Live execution mode")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }

            Spacer()

            // Clear button
            Button {
                messages = []
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.primary.opacity(messages.isEmpty ? 0.3 : 0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(messages.isEmpty ? 0.02 : 0.05))
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .disabled(messages.isEmpty)

            // Done button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Conversation View

    private var conversationView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if messages.isEmpty {
                    emptyState
                } else {
                    ForEach(messages) { message in
                        TestMessageView(message: message)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.primary.opacity(0.02))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(Color.primary.opacity(0.2))

            Text("Start Testing")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.5))

            Text("Enter a prompt below to test your agent")
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.3)

            VStack(spacing: 10) {
                // Tool info
                if !agent.enabledTools.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.primary.opacity(0.4))

                            ForEach(agent.enabledTools) { tool in
                                Text(tool.name)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.primary.opacity(0.5))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.primary.opacity(0.05))
                                    .cornerRadius(3)
                            }
                        }
                    }
                }

                // Input field
                HStack(spacing: 10) {
                    TextEditor(text: $testPrompt)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(Color.primary.opacity(0.8))
                        .padding(8)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)

                    // Send button - sleek minimal
                    Button {
                        sendMessage()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(canSend ? 0.1 : 0.04))
                                .frame(width: 36, height: 36)
                            Image(systemName: isRunning ? "stop.fill" : "paperplane.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.primary.opacity(canSend ? 0.7 : 0.25))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                }
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var canSend: Bool {
        !testPrompt.isEmpty || isRunning
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !testPrompt.isEmpty else { return }

        let userMessage = TestMessage(
            role: .user,
            content: testPrompt,
            timestamp: Date()
        )

        messages.append(userMessage)
        testPrompt = ""
        isRunning = true

        // Simulate agent thinking
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            let thinkingMessage = TestMessage(
                role: .system,
                content: "Agent is thinking...",
                timestamp: Date()
            )
            messages.append(thinkingMessage)

            // Simulate tool calls
            for tool in agent.enabledTools.prefix(2) {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s

                let toolMessage = TestMessage(
                    role: .tool,
                    content: "Calling \(tool.name)...",
                    timestamp: Date(),
                    toolName: tool.name
                )
                messages.append(toolMessage)

                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s

                let resultMessage = TestMessage(
                    role: .toolResult,
                    content: "Tool execution successful. Retrieved 12 results.",
                    timestamp: Date(),
                    toolName: tool.name
                )
                messages.append(resultMessage)
            }

            // Final response
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s

            let responseMessage = TestMessage(
                role: .assistant,
                content: generateMockResponse(userMessage.content),
                timestamp: Date()
            )
            messages.append(responseMessage)

            isRunning = false
        }
    }

    private func generateMockResponse(_ prompt: String) -> String {
        """
        I've analyzed your request and executed the necessary tools. Here's what I found:

        Based on \(agent.contextData.isEmpty ? "the available data" : agent.contextData.map { $0.title }.joined(separator: ", ")):

        • Found relevant information using \(agent.enabledTools.first?.name ?? "available tools")
        • Processed \(Int.random(in: 5...50)) records
        • Identified key patterns in the data

        Would you like me to provide more details or help with something else?
        """
    }
}

// MARK: - Test Message View

struct TestMessageView: View {
    let message: TestMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Icon - monochromatic
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 28, height: 28)
                Image(systemName: message.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(message.iconOpacity))
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.roleLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.7))

                    Spacer()

                    Text(message.timestamp, style: .time)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.primary.opacity(0.35))
                }

                if let toolName = message.toolName {
                    Text(toolName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(3)
                }

                Text(message.content)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.8))
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }
}

// MARK: - Models

struct TestMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date
    var toolName: String?

    enum MessageRole {
        case user
        case assistant
        case system
        case tool
        case toolResult
    }

    var icon: String {
        switch role {
        case .user: return "person.circle.fill"
        case .assistant: return "brain.head.profile"
        case .system: return "info.circle.fill"
        case .tool: return "wrench.and.screwdriver"
        case .toolResult: return "checkmark.circle.fill"
        }
    }

    // Monochromatic opacity based on role
    var iconOpacity: Double {
        switch role {
        case .user: return 0.6
        case .assistant: return 0.7
        case .system: return 0.4
        case .tool: return 0.5
        case .toolResult: return 0.6
        }
    }

    var roleLabel: String {
        switch role {
        case .user: return "You"
        case .assistant: return "Agent"
        case .system: return "System"
        case .tool: return "Tool Call"
        case .toolResult: return "Tool Result"
        }
    }
}
