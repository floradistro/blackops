import SwiftUI

// MARK: - Agent Test Sheet
// Modal sheet for testing agents with live execution

struct AgentTestSheet: View {
    let agent: AgentConfiguration
    @Environment(\.dismiss) var dismiss

    @State private var testPrompt = ""
    @State private var isRunning = false
    @State private var messages: [TestMessage] = []

    var body: some View {
        NavigationView {
            VSplitView {
                // Top: Conversation
                conversationView
                    .frame(minHeight: 300)

                // Bottom: Input
                inputView
                    .frame(height: 150)
            }
            .navigationTitle("Test: \(agent.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        messages = []
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(messages.isEmpty)
                }
            }
        }
        .frame(width: 800, height: 600)
    }

    private var conversationView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                if messages.isEmpty {
                    emptyState
                } else {
                    ForEach(messages) { message in
                        TestMessageView(message: message)
                    }
                }
            }
            .padding(DesignSystem.Spacing.xl)
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Start Testing")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(.secondary)

            Text("Enter a prompt below to test your agent")
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inputView: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: DesignSystem.Spacing.md) {
                // Tool info
                if !agent.enabledTools.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            ForEach(agent.enabledTools) { tool in
                                Text(tool.name)
                                    .font(.system(size: 11))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DesignSystem.Colors.surfaceTertiary)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }

                // Input field
                HStack(spacing: DesignSystem.Spacing.md) {
                    TextEditor(text: $testPrompt)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(DesignSystem.Colors.surfaceTertiary)
                        .cornerRadius(DesignSystem.Radius.md)

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: isRunning ? "stop.fill" : "paperplane.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(testPrompt.isEmpty && !isRunning)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(VisualEffectBackground(material: .sidebar))
        }
    }

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
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Icon
            Image(systemName: message.icon)
                .font(.system(size: 18))
                .foregroundStyle(message.color)
                .frame(width: 32, height: 32)
                .background(message.color.opacity(0.1))
                .cornerRadius(8)

            // Content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text(message.roleLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(message.color)

                    Spacer()

                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                if let toolName = message.toolName {
                    Text(toolName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.surfaceTertiary)
                        .cornerRadius(4)
                }

                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceTertiary)
        .cornerRadius(DesignSystem.Radius.lg)
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
        case .tool: return "wrench.and.screwdriver.fill"
        case .toolResult: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch role {
        case .user: return .blue
        case .assistant: return .green
        case .system: return .gray
        case .tool: return .orange
        case .toolResult: return .green
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
