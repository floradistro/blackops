# Building AI Agents in SwagManager Mac App

## Overview

Build **native AI agents directly in your Mac app** that can autonomously execute tasks using your MCP servers. All processing happens client-side with real-time UI updates.

---

## Architecture: Client-Side Agent Runtime

```
SwagManager.app
  ├── AgentStore (manages agents)
  ├── AgentRuntime (executes agent loops)
  ├── MCPExecutor (calls your MCP tools)
  └── UI Views (monitor & control agents)
```

**Benefits:**
- ✅ Real-time UI updates
- ✅ Full control and debugging
- ✅ Offline-capable (local processing)
- ✅ Leverages native Mac features
- ✅ Integrates with existing EditorStore

---

## Step 1: Agent Runtime Engine

Create the core agent execution engine:

```swift
// SwagManager/Services/AgentRuntime.swift
import Foundation
import Supabase

@MainActor
class AgentRuntime: ObservableObject {
    @Published var isRunning = false
    @Published var currentThought: String?
    @Published var toolExecutions: [ToolExecution] = []
    @Published var conversationMessages: [ConversationMessage] = []

    private let supabase = SupabaseService.shared
    private let anthropicAPIKey: String

    // Configuration
    let maxIterations = 20
    let maxToolCallsPerTurn = 5

    struct ToolExecution: Identifiable {
        let id = UUID()
        let toolName: String
        let input: [String: Any]
        var output: String?
        var status: Status
        let timestamp: Date

        enum Status {
            case pending, running, success, failed
        }
    }

    struct ConversationMessage: Identifiable {
        let id = UUID()
        let role: String // "user", "assistant", "tool_result"
        let content: String
        let timestamp: Date
    }

    init(anthropicAPIKey: String) {
        self.anthropicAPIKey = anthropicAPIKey
    }

    // Execute agent task
    func execute(
        agent: Agent,
        initialPrompt: String,
        storeId: UUID? = nil,
        userId: UUID? = nil
    ) async throws {
        isRunning = true
        defer { isRunning = false }

        conversationMessages = []
        toolExecutions = []

        // Add initial user message
        conversationMessages.append(ConversationMessage(
            role: "user",
            content: initialPrompt,
            timestamp: Date()
        ))

        // Load available tools for this agent
        let availableTools = try await loadAgentTools(agent)
        NSLog("[AgentRuntime] Loaded \(availableTools.count) tools for agent \(agent.name)")

        // Main agent loop
        var iteration = 0
        var shouldContinue = true

        while shouldContinue && iteration < maxIterations {
            iteration += 1
            NSLog("[AgentRuntime] Starting iteration \(iteration)")

            // Call Claude API
            let response = try await callClaude(
                agent: agent,
                tools: availableTools,
                messages: conversationMessages
            )

            // Check if Claude wants to stop
            let stopReason = response["stop_reason"] as? String
            if stopReason == "end_turn" || stopReason == "max_tokens" {
                shouldContinue = false
            }

            // Process response content
            guard let content = response["content"] as? [[String: Any]] else {
                NSLog("[AgentRuntime] No content in response")
                break
            }

            // Extract text and tool calls
            var assistantText = ""
            var toolCalls: [ToolCall] = []

            for block in content {
                if let type = block["type"] as? String {
                    if type == "text", let text = block["text"] as? String {
                        assistantText += text
                    } else if type == "tool_use" {
                        if let name = block["name"] as? String,
                           let id = block["id"] as? String,
                           let input = block["input"] as? [String: Any] {
                            toolCalls.append(ToolCall(id: id, name: name, input: input))
                        }
                    }
                }
            }

            // Add assistant message
            if !assistantText.isEmpty {
                currentThought = assistantText
                conversationMessages.append(ConversationMessage(
                    role: "assistant",
                    content: assistantText,
                    timestamp: Date()
                ))
            }

            // Execute tool calls
            if toolCalls.isEmpty {
                shouldContinue = false
                break
            }

            NSLog("[AgentRuntime] Executing \(toolCalls.count) tool calls")

            // Execute tools in parallel
            await withTaskGroup(of: ToolResult.self) { group in
                for toolCall in toolCalls.prefix(maxToolCallsPerTurn) {
                    group.addTask {
                        await self.executeTool(
                            toolCall: toolCall,
                            storeId: storeId,
                            userId: userId
                        )
                    }
                }

                // Collect results
                var results: [ToolResult] = []
                for await result in group {
                    results.append(result)

                    // Add tool result message
                    conversationMessages.append(ConversationMessage(
                        role: "tool_result",
                        content: "Tool: \(result.name)\nResult: \(result.output)",
                        timestamp: Date()
                    ))
                }
            }
        }

        NSLog("[AgentRuntime] Agent finished after \(iteration) iterations")
    }

    // Call Claude API
    private func callClaude(
        agent: Agent,
        tools: [MCPToolDefinition],
        messages: [ConversationMessage]
    ) async throws -> [String: Any] {

        // Build request
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Convert messages to Claude format
        let claudeMessages = messages.compactMap { msg -> [String: Any]? in
            if msg.role == "tool_result" {
                // Parse tool result format
                let parts = msg.content.split(separator: "\n", maxSplits: 1)
                guard parts.count == 2 else { return nil }

                let toolName = String(parts[0].dropFirst(6)) // Remove "Tool: "
                let result = String(parts[1].dropFirst(8)) // Remove "Result: "

                return [
                    "role": "user",
                    "content": [
                        [
                            "type": "tool_result",
                            "tool_use_id": msg.id.uuidString, // Use message ID
                            "content": result
                        ]
                    ]
                ]
            } else {
                return [
                    "role": msg.role,
                    "content": msg.content
                ]
            }
        }

        // Convert tools to Claude format
        let claudeTools = tools.map { tool in
            [
                "name": tool.name,
                "description": tool.description,
                "input_schema": tool.inputSchema
            ]
        }

        let body: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": agent.maxTokensPerResponse ?? 4096,
            "system": agent.systemPrompt ?? "You are a helpful assistant.",
            "messages": claudeMessages,
            "tools": claudeTools
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AgentError.apiError("Claude API returned error")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json ?? [:]
    }

    // Execute MCP tool
    private func executeTool(
        toolCall: ToolCall,
        storeId: UUID?,
        userId: UUID?
    ) async -> ToolResult {

        let startTime = Date()

        // Add to UI
        let execution = ToolExecution(
            toolName: toolCall.name,
            input: toolCall.input,
            output: nil,
            status: .running,
            timestamp: startTime
        )
        toolExecutions.append(execution)

        do {
            // Load tool definition from ai_tool_registry
            let toolDef = try await loadToolDefinition(toolCall.name)

            // Prepare parameters
            var params = toolCall.input
            if let storeId = storeId {
                params["store_id"] = storeId.uuidString
            }
            if let userId = userId {
                params["user_id"] = userId.uuidString
            }

            NSLog("[AgentRuntime] Executing tool: \(toolCall.name)")

            // Execute via RPC or Edge Function
            let result: Any
            if let rpcFunction = toolDef.rpcFunction {
                result = try await executeRPC(function: rpcFunction, params: params)
            } else if let edgeFunction = toolDef.edgeFunction {
                result = try await executeEdgeFunction(function: edgeFunction, params: params)
            } else {
                throw AgentError.noExecutionMethod
            }

            let duration = Date().timeIntervalSince(startTime)
            let resultString = formatResult(result)

            // Update UI
            if let index = toolExecutions.firstIndex(where: { $0.id == execution.id }) {
                toolExecutions[index].output = resultString
                toolExecutions[index].status = .success
            }

            // Log to database
            await logToolExecution(
                toolName: toolCall.name,
                input: params,
                output: resultString,
                duration: duration,
                success: true
            )

            NSLog("[AgentRuntime] Tool \(toolCall.name) succeeded in \(String(format: "%.2f", duration))s")

            return ToolResult(
                id: toolCall.id,
                name: toolCall.name,
                output: resultString,
                success: true
            )

        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let errorMsg = error.localizedDescription

            // Update UI
            if let index = toolExecutions.firstIndex(where: { $0.id == execution.id }) {
                toolExecutions[index].output = "Error: \(errorMsg)"
                toolExecutions[index].status = .failed
            }

            // Log error
            await logToolExecution(
                toolName: toolCall.name,
                input: toolCall.input,
                output: errorMsg,
                duration: duration,
                success: false
            )

            NSLog("[AgentRuntime] Tool \(toolCall.name) failed: \(errorMsg)")

            return ToolResult(
                id: toolCall.id,
                name: toolCall.name,
                output: "Error: \(errorMsg)",
                success: false
            )
        }
    }

    // Load tools available to agent
    private func loadAgentTools(_ agent: Agent) async throws -> [MCPToolDefinition] {
        var query = supabase.client
            .from("ai_tool_registry")
            .select("*")
            .eq("is_active", value: true)

        // Filter by categories
        if !agent.enabledCategories.isEmpty {
            query = query.in("category", values: agent.enabledCategories.map { $0 as Any })
        }

        // Filter by specific tools
        if !agent.enabledTools.isEmpty {
            query = query.in("name", values: agent.enabledTools.map { $0 as Any })
        }

        let response = try await query.execute()
        let decoder = JSONDecoder.supabaseDecoder
        let servers = try decoder.decode([MCPServer].self, from: response.data)

        return servers.map { server in
            MCPToolDefinition(
                name: server.name,
                description: server.description ?? "",
                inputSchema: server.definition.inputSchema?.properties ?? [:],
                rpcFunction: server.rpcFunction,
                edgeFunction: server.edgeFunction
            )
        }
    }

    private func loadToolDefinition(_ name: String) async throws -> MCPToolDefinition {
        let response = try await supabase.client
            .from("ai_tool_registry")
            .select("*")
            .eq("name", value: name)
            .single()
            .execute()

        let decoder = JSONDecoder.supabaseDecoder
        let server = try decoder.decode(MCPServer.self, from: response.data)

        return MCPToolDefinition(
            name: server.name,
            description: server.description ?? "",
            inputSchema: [:],
            rpcFunction: server.rpcFunction,
            edgeFunction: server.edgeFunction
        )
    }

    private func executeRPC(function: String, params: [String: Any]) async throws -> Any {
        let jsonData = try JSONSerialization.data(withJSONObject: params)
        let response = try await supabase.client.rpc(function, params: params).execute()
        return try JSONSerialization.jsonObject(with: response.data)
    }

    private func executeEdgeFunction(function: String, params: [String: Any]) async throws -> Any {
        let response = try await supabase.client.functions.invoke(
            function,
            options: FunctionInvokeOptions(body: params)
        )
        return try JSONSerialization.jsonObject(with: response.data)
    }

    private func formatResult(_ result: Any) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return String(describing: result)
    }

    private func logToolExecution(
        toolName: String,
        input: [String: Any],
        output: String,
        duration: TimeInterval,
        success: Bool
    ) async {
        let log = [
            "tool_name": toolName,
            "result_status": success ? "success" : "error",
            "execution_time_ms": Int(duration * 1000),
            "error_message": success ? nil : output
        ] as [String: Any?]

        do {
            try await supabase.client
                .from("lisa_tool_execution_log")
                .insert(log)
                .execute()
        } catch {
            NSLog("[AgentRuntime] Failed to log execution: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct ToolCall {
    let id: String
    let name: String
    let input: [String: Any]
}

struct ToolResult {
    let id: String
    let name: String
    let output: String
    let success: Bool
}

struct MCPToolDefinition {
    let name: String
    let description: String
    let inputSchema: [String: PropertyDefinition]
    let rpcFunction: String?
    let edgeFunction: String?
}

enum AgentError: Error {
    case apiError(String)
    case noExecutionMethod
    case toolExecutionFailed(String)
}
```

---

## Step 2: Agent Store (State Management)

```swift
// SwagManager/Stores/AgentStore.swift
import SwiftUI
import Supabase

@MainActor
class AgentStore: ObservableObject {
    @Published var agents: [Agent] = []
    @Published var selectedAgent: Agent?
    @Published var isLoadingAgents = false
    @Published var error: String?

    // Agent execution
    @Published var activeRuntimes: [UUID: AgentRuntime] = [:]
    @Published var runHistory: [AgentRun] = []

    private let supabase = SupabaseService.shared
    private let anthropicAPIKey: String

    struct AgentRun: Identifiable {
        let id = UUID()
        let agentId: UUID
        let agentName: String
        let prompt: String
        let startedAt: Date
        var completedAt: Date?
        var status: RunStatus
        var executionCount: Int = 0

        enum RunStatus {
            case running, completed, failed, cancelled
        }
    }

    init(anthropicAPIKey: String) {
        self.anthropicAPIKey = anthropicAPIKey
    }

    // Load all agents from database
    func loadAgents() async {
        isLoadingAgents = true
        error = nil

        do {
            let response = try await supabase.client
                .from("agents")
                .select("*")
                .order("name")
                .execute()

            let decoder = JSONDecoder.supabaseDecoder
            agents = try decoder.decode([Agent].self, from: response.data)

            NSLog("[AgentStore] Loaded \(agents.count) agents")
        } catch {
            self.error = error.localizedDescription
            NSLog("[AgentStore] Error loading agents: \(error)")
        }

        isLoadingAgents = false
    }

    // Create new agent
    func createAgent(
        name: String,
        description: String?,
        systemPrompt: String,
        enabledCategories: [String],
        enabledTools: [String] = []
    ) async throws -> Agent {

        let insert: [String: Any] = [
            "name": name,
            "description": description as Any,
            "system_prompt": systemPrompt,
            "enabled_categories": enabledCategories,
            "enabled_tools": enabledTools
        ]

        let response = try await supabase.client
            .from("agents")
            .insert(insert)
            .select()
            .single()
            .execute()

        let decoder = JSONDecoder.supabaseDecoder
        let agent = try decoder.decode(Agent.self, from: response.data)

        agents.append(agent)
        return agent
    }

    // Update agent
    func updateAgent(_ agent: Agent) async throws {
        let update: [String: Any] = [
            "name": agent.name,
            "description": agent.description as Any,
            "system_prompt": agent.systemPrompt as Any,
            "enabled_categories": agent.enabledCategories,
            "enabled_tools": agent.enabledTools,
            "updated_at": Date().ISO8601Format()
        ]

        try await supabase.client
            .from("agents")
            .update(update)
            .eq("id", value: agent.id.uuidString)
            .execute()

        // Reload
        await loadAgents()
    }

    // Delete agent
    func deleteAgent(_ agent: Agent) async throws {
        try await supabase.client
            .from("agents")
            .delete()
            .eq("id", value: agent.id.uuidString)
            .execute()

        agents.removeAll { $0.id == agent.id }
    }

    // Run agent
    func runAgent(
        _ agent: Agent,
        prompt: String,
        storeId: UUID? = nil
    ) async {
        let runtime = AgentRuntime(anthropicAPIKey: anthropicAPIKey)
        activeRuntimes[agent.id] = runtime

        var run = AgentRun(
            agentId: agent.id,
            agentName: agent.name,
            prompt: prompt,
            startedAt: Date(),
            status: .running
        )
        runHistory.insert(run, at: 0)

        do {
            try await runtime.execute(
                agent: agent,
                initialPrompt: prompt,
                storeId: storeId
            )

            // Update run
            if let index = runHistory.firstIndex(where: { $0.id == run.id }) {
                runHistory[index].completedAt = Date()
                runHistory[index].status = .completed
                runHistory[index].executionCount = runtime.toolExecutions.count
            }

        } catch {
            NSLog("[AgentStore] Agent run failed: \(error)")

            if let index = runHistory.firstIndex(where: { $0.id == run.id }) {
                runHistory[index].completedAt = Date()
                runHistory[index].status = .failed
            }

            self.error = error.localizedDescription
        }

        activeRuntimes.removeValue(forKey: agent.id)
    }

    // Cancel running agent
    func cancelAgent(_ agentId: UUID) {
        // In real implementation, add cancellation support to AgentRuntime
        activeRuntimes.removeValue(forKey: agentId)

        if let index = runHistory.firstIndex(where: { $0.agentId == agentId && $0.status == .running }) {
            runHistory[index].completedAt = Date()
            runHistory[index].status = .cancelled
        }
    }

    // Get runtime for agent
    func runtime(for agentId: UUID) -> AgentRuntime? {
        activeRuntimes[agentId]
    }
}
```

---

## Step 3: Agent Management UI

```swift
// SwagManager/Views/Agents/AgentManagementView.swift
import SwiftUI

struct AgentManagementView: View {
    @StateObject private var store: AgentStore
    @State private var showingCreateSheet = false

    init(anthropicAPIKey: String) {
        _store = StateObject(wrappedValue: AgentStore(anthropicAPIKey: anthropicAPIKey))
    }

    var body: some View {
        HSplitView {
            // Agent List
            agentListView
                .frame(minWidth: 250, maxWidth: 350)

            // Agent Detail / Playground
            if let agent = store.selectedAgent {
                AgentDetailView(agent: agent, store: store)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("AI Agents")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("New Agent", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateAgentSheet(store: store)
        }
        .task {
            await store.loadAgents()
        }
    }

    private var agentListView: some View {
        List(selection: $store.selectedAgent) {
            ForEach(store.agents) { agent in
                AgentRowView(agent: agent, store: store)
                    .tag(agent)
            }
        }
        .listStyle(.sidebar)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Agent Selected")
                .font(.title2)
                .fontWeight(.medium)

            Text("Select an agent or create a new one")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Agent Row

struct AgentRowView: View {
    let agent: Agent
    @ObservedObject var store: AgentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isRunning ? "brain.head.profile.fill" : "brain.head.profile")
                    .foregroundColor(isRunning ? .green : .primary)

                Text(agent.name)
                    .fontWeight(.medium)

                Spacer()

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            if let description = agent.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Categories
            if !agent.enabledCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(agent.enabledCategories, id: \.self) { category in
                            Text(category)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var isRunning: Bool {
        store.activeRuntimes[agent.id] != nil
    }
}

// MARK: - Agent Detail View

struct AgentDetailView: View {
    let agent: Agent
    @ObservedObject var store: AgentStore

    @State private var promptText = ""
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Tab View
            TabView(selection: $selectedTab) {
                // Playground Tab
                playgroundView
                    .tabItem {
                        Label("Playground", systemImage: "play.circle")
                    }
                    .tag(0)

                // Configuration Tab
                configurationView
                    .tabItem {
                        Label("Configuration", systemImage: "gear")
                    }
                    .tag(1)

                // History Tab
                historyView
                    .tabItem {
                        Label("History", systemImage: "clock")
                    }
                    .tag(2)
            }
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundColor(.blue)

            VStack(alignment: .leading) {
                Text(agent.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if let description = agent.description {
                    Text(description)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }

    private var playgroundView: some View {
        HSplitView {
            // Input/Control
            VStack(spacing: 16) {
                GroupBox("Prompt") {
                    TextEditor(text: $promptText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                }

                Button {
                    Task {
                        await store.runAgent(agent, prompt: promptText)
                    }
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Run Agent")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(promptText.isEmpty || store.activeRuntimes[agent.id] != nil)

                if let runtime = store.runtime(for: agent.id) {
                    // Real-time execution view
                    AgentExecutionView(runtime: runtime)
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 300, maxWidth: 400)

            // Results
            if let runtime = store.runtime(for: agent.id) {
                AgentConversationView(runtime: runtime)
            } else {
                emptyPlaygroundView
            }
        }
    }

    private var emptyPlaygroundView: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Ready to Run")
                .font(.title3)

            Text("Enter a prompt and click Run Agent")
                .foregroundColor(.secondary)
        }
    }

    private var configurationView: some View {
        Form {
            Section("Basic Info") {
                TextField("Name", text: .constant(agent.name))
                TextField("Description", text: .constant(agent.description ?? ""))
            }

            Section("System Prompt") {
                TextEditor(text: .constant(agent.systemPrompt ?? ""))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
            }

            Section("Enabled Categories") {
                ForEach(agent.enabledCategories, id: \.self) { category in
                    Text(category)
                }
            }

            Section("Limits") {
                LabeledContent("Max Tokens", value: "\(agent.maxTokensPerResponse ?? 4096)")
                LabeledContent("Max Turns", value: "\(agent.maxTurnsPerConversation ?? 50)")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var historyView: some View {
        List {
            ForEach(store.runHistory.filter { $0.agentId == agent.id }) { run in
                AgentRunRowView(run: run)
            }
        }
    }
}

// MARK: - Agent Execution View

struct AgentExecutionView: View {
    @ObservedObject var runtime: AgentRuntime

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Current Thought") {
                Text(runtime.currentThought ?? "Thinking...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Tool Executions") {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(runtime.toolExecutions) { execution in
                            ToolExecutionRowView(execution: execution)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
}

struct ToolExecutionRowView: View {
    let execution: AgentRuntime.ToolExecution

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(execution.toolName)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)

                if let output = execution.output {
                    Text(output)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer()

            Text(execution.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(backgroundColor)
        .cornerRadius(6)
    }

    private var statusIcon: some View {
        Group {
            switch execution.status {
            case .pending:
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            case .running:
                ProgressView()
                    .scaleEffect(0.6)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }

    private var backgroundColor: Color {
        switch execution.status {
        case .success: return Color.green.opacity(0.05)
        case .failed: return Color.red.opacity(0.05)
        default: return Color.gray.opacity(0.05)
        }
    }
}

// MARK: - Agent Conversation View

struct AgentConversationView: View {
    @ObservedObject var runtime: AgentRuntime

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(runtime.conversationMessages) { message in
                    MessageBubble(message: message)
                }
            }
            .padding()
        }
    }
}

struct MessageBubble: View {
    let message: AgentRuntime.ConversationMessage

    var body: some View {
        HStack {
            if message.role == "assistant" {
                Spacer(minLength: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(roleLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(roleColor)

                Text(message.content)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .background(backgroundColor)
                    .cornerRadius(8)
            }

            if message.role == "user" {
                Spacer(minLength: 40)
            }
        }
    }

    private var roleLabel: String {
        switch message.role {
        case "user": return "USER"
        case "assistant": return "AGENT"
        case "tool_result": return "TOOL RESULT"
        default: return message.role.uppercased()
        }
    }

    private var roleColor: Color {
        switch message.role {
        case "user": return .blue
        case "assistant": return .green
        case "tool_result": return .orange
        default: return .gray
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case "user": return Color.blue.opacity(0.1)
        case "assistant": return Color.green.opacity(0.1)
        case "tool_result": return Color.orange.opacity(0.1)
        default: return Color.gray.opacity(0.1)
        }
    }
}

// MARK: - Create Agent Sheet

struct CreateAgentSheet: View {
    @ObservedObject var store: AgentStore
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var systemPrompt = ""
    @State private var selectedCategories: Set<String> = []

    let availableCategories = [
        "crm", "orders", "products", "inventory",
        "customers", "analytics", "email", "notifications"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }

                Section("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                }

                Section("Tool Categories") {
                    ForEach(availableCategories, id: \.self) { category in
                        Toggle(category, isOn: Binding(
                            get: { selectedCategories.contains(category) },
                            set: { if $0 { selectedCategories.insert(category) } else { selectedCategories.remove(category) } }
                        ))
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Agent")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            try? await store.createAgent(
                                name: name,
                                description: description,
                                systemPrompt: systemPrompt,
                                enabledCategories: Array(selectedCategories)
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || systemPrompt.isEmpty)
                }
            }
        }
        .frame(width: 600, height: 700)
    }
}

// MARK: - Agent Run Row

struct AgentRunRowView: View {
    let run: AgentStore.AgentRun

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                statusIcon
                Text(run.prompt)
                    .lineLimit(1)
                Spacer()
                Text(run.startedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                if run.executionCount > 0 {
                    Text("\(run.executionCount) tools")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let completed = run.completedAt {
                    let duration = completed.timeIntervalSince(run.startedAt)
                    Text(String(format: "%.1fs", duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: some View {
        Group {
            switch run.status {
            case .running:
                ProgressView()
                    .scaleEffect(0.6)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .cancelled:
                Image(systemName: "stop.circle.fill")
                    .foregroundColor(.orange)
            }
        }
    }
}
```

---

## Step 4: Add to EditorStore

```swift
// Add to SwagManager/Stores/EditorStore.swift

extension EditorStore {
    // Add agent management
    func openAgentManagement() {
        let tabItem = OpenTabItem.agentManagement
        if !openTabs.contains(tabItem) {
            openTabs.append(tabItem)
        }
        activeTab = tabItem
    }
}

// Add to OpenTabItem enum
enum OpenTabItem: Hashable {
    // ... existing cases ...
    case agentManagement
    case agent(Agent)

    var icon: String {
        switch self {
        // ... existing cases ...
        case .agentManagement: return "brain"
        case .agent: return "brain.head.profile"
        }
    }

    var title: String {
        switch self {
        // ... existing cases ...
        case .agentManagement: return "AI Agents"
        case .agent(let agent): return agent.name
        }
    }
}
```

---

## Step 5: Add to Sidebar

```swift
// In SwagManager/Views/Editor/Sidebar/EditorSidebarView.swift

Section("AI") {
    NavigationLink(
        destination: AgentManagementView(anthropicAPIKey: getAnthropicKey()),
        tag: OpenTabItem.agentManagement,
        selection: $store.activeTab
    ) {
        Label("Agents", systemImage: "brain")
    }

    // Show running agents
    ForEach(getRunningAgents()) { agent in
        HStack {
            ProgressView()
                .scaleEffect(0.6)
            Text(agent.name)
                .font(.caption)
        }
    }
}
```

---

## Quick Start

### 1. Add API Key to Settings

```swift
// SwagManager/Views/Settings/SettingsView.swift

@AppStorage("anthropic_api_key") private var anthropicAPIKey = ""

Section("AI Configuration") {
    SecureField("Anthropic API Key", text: $anthropicAPIKey)
        .textFieldStyle(.roundedBorder)

    Text("Your API key is stored securely in your Keychain")
        .font(.caption)
        .foregroundColor(.secondary)
}
```

### 2. Create Your First Agent

1. Run SwagManager.app
2. Go to sidebar → AI → Agents
3. Click "+" to create new agent
4. Configure:
   - Name: "Customer Service Bot"
   - System Prompt: "You help customers with orders and products"
   - Categories: crm, orders, products
5. Click "Create"

### 3. Test the Agent

1. Select your new agent
2. Go to "Playground" tab
3. Enter prompt: "Get me all pending orders from today"
4. Click "Run Agent"
5. Watch in real-time as it:
   - Calls `order_query` MCP tool
   - Formats results
   - Provides answer

---

## Integration Examples

### Auto-Run Agent on Event

```swift
// In OrderDetailPanel.swift

.task {
    // Run agent when order is viewed
    if let agent = editorStore.getAgent(name: "Order Assistant") {
        await agentStore.runAgent(
            agent,
            prompt: "Analyze this order and suggest next steps: \(order.id)"
        )
    }
}
```

### Background Agent Loop

```swift
// Create a background agent that runs periodically

class BackgroundAgentRunner: ObservableObject {
    func startMonitoring(agent: Agent, interval: TimeInterval) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                await self.runAgentCheck(agent)
            }
        }
    }

    private func runAgentCheck(_ agent: Agent) async {
        // Run agent to check conditions
        let runtime = AgentRuntime(anthropicAPIKey: getKey())
        try? await runtime.execute(
            agent: agent,
            initialPrompt: "Check inventory levels and alert if any items are low"
        )
    }
}
```

---

## Benefits of Mac App Agents

1. **Real-Time Monitoring** - See agent thinking and tool calls live
2. **Native Performance** - Fast, no round-trips to backend
3. **Debugging** - Full visibility into agent behavior
4. **Offline Capable** - Works without internet (if using local models)
5. **UI Integration** - Agents can directly update your UI
6. **User Control** - Easy to start/stop/modify agents

---

## Next Steps

1. ✅ Copy code above into your project
2. ✅ Add Agent section to sidebar
3. ✅ Get Anthropic API key, add to Settings
4. ✅ Create your first agent
5. ✅ Test in Playground
6. ✅ Integrate with existing workflows
7. ✅ Monitor in MCPMonitoringView

Your SwagManager app now has autonomous AI agents! 🧠
