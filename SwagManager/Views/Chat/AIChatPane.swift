import SwiftUI
import UniformTypeIdentifiers

// MARK: - AI Chat Pane

struct AIChatPane: View {
    @StateObject private var chatStore = AIChatStore()
    @Environment(EditorStore.self) var editorStore
    @State private var inputText = ""
    @State private var showSettings = false
    @State private var isDropTargeted = false
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            // Messages - full height, edge to edge
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if chatStore.messages.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Spacer(minLength: 80)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(.quaternary)
                                Text("Ask anything")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.tertiary)
                                Text("Drop files to add context")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.quaternary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ForEach(chatStore.messages) { message in
                                MessageBubble(
                                    message: message,
                                    streamingBuffer: chatStore.streamingBuffer
                                )
                                .id(message.id)
                            }

                            // Streaming indicator - only show when executing tools
                            if chatStore.isStreaming, let tool = chatStore.currentToolExecution {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(cleanToolName(tool))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .id("streaming")
                            }
                        }

                        // Error - minimal
                        if let error = chatStore.error {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 11))
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.primary.opacity(0.03))
                        }
                    }
                }
                .onAppear { scrollProxy = proxy }
                .onChange(of: chatStore.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(chatStore.messages.last?.id, anchor: .bottom)
                    }
                }
            }

            // Input bar - minimal
            VStack(spacing: 0) {
                // Context chips above input (inline) - minimal
                if !chatStore.attachedFolders.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(chatStore.attachedFolders.enumerated()), id: \.offset) { index, url in
                                HStack(spacing: 3) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.tertiary)
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Button {
                                        chatStore.removeFolder(at: index)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.04), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.top, 6)
                }

                HStack(spacing: 10) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    TextField("Message...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .lineLimit(1...5)
                        .onSubmit(sendMessage)

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(inputText.isEmpty ? Color.secondary.opacity(0.2) : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty || chatStore.isStreaming)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let path = String(data: data, encoding: .utf8),
                          let url = URL(string: path) else { return }
                    DispatchQueue.main.async {
                        chatStore.addFolder(url)
                    }
                }
            }
            return true
        }
        .overlay {
            if isDropTargeted {
                ZStack {
                    Color.primary.opacity(0.04)
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("Drop to add context")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            ChatSettingsView(chatStore: chatStore, agents: editorStore.aiAgents)
        }
        .task {
            await editorStore.loadAIAgents()
            syncAgentState()
            chatStore.storeId = editorStore.selectedStore?.id
        }
        .onChange(of: editorStore.selectedStore?.id) { _, newId in
            guard chatStore.storeId != newId else { return }  // Avoid redundant updates
            chatStore.clearConversation()  // Clear chat when switching stores
            chatStore.storeId = newId
            Task {
                await editorStore.loadAIAgents()
                syncAgentState()
            }
        }
        .onChange(of: editorStore.aiAgents.count) { _, _ in  // Use count instead of full array comparison
            syncAgentState()
        }
        .onChange(of: chatStore.agentId) { oldId, newId in
            guard oldId != newId else { return }  // Avoid redundant updates
            // Update currentAgent when agent selection changes
            if let newId = newId {
                chatStore.currentAgent = editorStore.aiAgents.first { $0.id == newId }
            } else {
                chatStore.currentAgent = nil
            }
        }
    }

    /// Sync agent selection state - consolidates logic to avoid cascading updates
    private func syncAgentState() {
        let agents = editorStore.aiAgents
        if chatStore.agentId == nil, let first = agents.first {
            chatStore.agentId = first.id
            chatStore.currentAgent = first
        } else if let id = chatStore.agentId, let agent = agents.first(where: { $0.id == id }) {
            // Always update currentAgent with fresh data from the list
            // This ensures enabledTools and other fields are current
            chatStore.currentAgent = agent
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task {
            await chatStore.sendMessage(text)
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: AIChatStore.AIChatMessage
    // For streaming messages, observe the buffer directly (60fps updates)
    @ObservedObject var streamingBuffer: StreamingTextBuffer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if message.role == .user {
                // User message - right aligned, minimal dark bubble
                HStack {
                    Spacer(minLength: 60)
                    Text(message.content)
                        .font(.system(size: 13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.08))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            } else {
                // Assistant message - full width, structured
                VStack(alignment: .leading, spacing: 8) {
                    // Tool calls at top
                    if let tools = message.toolCalls, !tools.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(tools) { tool in
                                ToolChip(tool: tool)
                            }
                        }
                        .padding(.bottom, 4)
                    }

                    // Content rendering - 60fps streaming or final markdown
                    if message.isStreaming {
                        // STREAMING: Observe buffer directly (no array diffs)
                        if streamingBuffer.text.isEmpty {
                            TypewriterCursor()
                        } else {
                            Text(streamingBuffer.text)
                                .font(.system(size: 13))
                                .textSelection(.enabled)
                        }
                    } else {
                        // COMPLETE: Full markdown parsing (once)
                        if message.content.isEmpty {
                            Text(" ")
                                .font(.system(size: 13))
                        } else {
                            MarkdownText(message.content)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.02))
            }
        }
    }
}

// MARK: - Tool Chip

private struct ToolChip: View {
    let tool: AIChatStore.AIChatMessage.ToolCall

    var body: some View {
        HStack(spacing: 4) {
            switch tool.status {
            case .running:
                ProgressView()
                    .controlSize(.mini)
            case .success:
                Text("OK")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            case .failed:
                Text("ERR")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text(cleanToolName(tool.name))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.04), in: Capsule())
    }
}

// MARK: - Typewriter Cursor

private struct TypewriterCursor: View {
    @State private var isVisible = true

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.6))
            .frame(width: 2, height: 16)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isVisible.toggle()
                }
            }
    }
}

// MARK: - Tool Name Cleanup

private func cleanToolName(_ name: String) -> String {
    name
        .replacingOccurrences(of: "mcp__swagmanager__", with: "")
        .replacingOccurrences(of: "mcp__local__", with: "")
        .replacingOccurrences(of: "mcp__business__", with: "")
        .replacingOccurrences(of: "_", with: " ")
        .localizedCapitalized
}

// Note: Uses FlowLayout from SelectableChip.swift
// Note: Uses MarkdownText from MarkdownText.swift

// MARK: - Chat Settings View

private struct ChatSettingsView: View {
    @ObservedObject var chatStore: AIChatStore
    let agents: [AIAgent]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Chat Settings")
                .font(.headline)

            Form {
                Picker("Agent", selection: $chatStore.agentId) {
                    Text("None").tag(UUID?.none)
                    ForEach(agents) { agent in
                        Text(agent.displayName).tag(Optional(agent.id))
                    }
                }

                Toggle("Local Agent", isOn: $chatStore.useLocalAgent)
                Toggle("Code Tools", isOn: $chatStore.includeCodeTools)

                Button("Clear Chat", role: .destructive) {
                    chatStore.clearConversation()
                }
            }
            .formStyle(.grouped)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 300, height: 300)
    }
}

#Preview {
    AIChatPane()
        .environment(EditorStore())
        .frame(width: 400, height: 600)
}
