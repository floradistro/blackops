import SwiftUI

// MARK: - Agent Config Panel (Full Editor)
// Comprehensive agent configuration with all settings
// PERFORMANCE: Uses child views with @StateObject to isolate reactive updates

struct AgentConfigPanel: View {
    @Environment(\.editorStore) private var store
    let agent: AIAgent
    @Binding var selection: SDSidebarItem?

    // Editable state (copy of agent)
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var systemPrompt: String = ""
    @State private var model: String = "claude-sonnet-4-20250514"
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Int = 32000
    @State private var isActive: Bool = true
    @State private var enabledTools: Set<String> = []
    @State private var tone: String = "professional"
    @State private var verbosity: String = "moderate"

    @State private var hasChanges = false
    @State private var isSaving = false

    private let models = [
        ("claude-opus-4-6", "Claude Opus 4.6", "Most powerful"),
        ("claude-sonnet-4-5-20250929", "Claude Sonnet 4.5", "Fast & intelligent"),
        ("claude-opus-4-5-20251101", "Claude Opus 4.5", "Previous flagship"),
        ("claude-sonnet-4-20250514", "Claude Sonnet 4", "Fast & capable"),
        ("claude-haiku-4-5-20251001", "Claude Haiku 4.5", "Fastest")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with status - isolated in own view
                AgentHeaderSection(
                    name: name,
                    description: description,
                    isActive: isActive
                )

                Divider()

                // Basic Info
                basicInfoSection

                Divider()

                // Model & Parameters
                modelSection

                Divider()

                // Tools - isolated in own view to prevent parent re-renders
                AgentToolsSection(enabledTools: $enabledTools, hasChanges: $hasChanges)

                Divider()

                // Custom User Tools - create your own tools
                CustomToolsSection()

                Divider()

                // Triggers - automate tool execution
                TriggersSection()

                Divider()

                // System Prompt
                systemPromptSection

                Divider()

                // Actions
                actionsSection
            }
            .padding()
        }
        .onAppear { loadAgent() }
        .onChange(of: agent.id) { _, _ in loadAgent() }
    }

    // MARK: - Sections

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BASIC INFO")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)

            VStack(spacing: 10) {
                HStack {
                    Text("name")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    TextField("", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced, weight: .medium))
                        .padding(8)
                        .background(Color.primary.opacity(0.03))
                        .frame(maxWidth: 300)
                        .onChange(of: name) { _, _ in hasChanges = true }
                }

                HStack {
                    Text("description")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    TextField("", text: $description)
                        .textFieldStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color.primary.opacity(0.03))
                        .frame(maxWidth: 300)
                        .onChange(of: description) { _, _ in hasChanges = true }
                }

                HStack {
                    Text("status")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isActive ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                        Text(isActive ? "active" : "inactive")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $isActive)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                        .onChange(of: isActive) { _, _ in hasChanges = true }
                }
            }
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MODEL")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)

            VStack(spacing: 10) {
                // Model picker
                HStack {
                    Text("model")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: $model) {
                        ForEach(models, id: \.0) { id, name, _ in
                            Text(name).tag(id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: model) { _, _ in hasChanges = true }
                    Spacer()
                }

                // Temperature
                HStack {
                    Text("temperature")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $temperature, in: 0...1, step: 0.1)
                        .frame(width: 150)
                        .onChange(of: temperature) { _, _ in hasChanges = true }
                    Text(String(format: "%.1f", temperature))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 30)
                    Spacer()
                }

                // Max Tokens
                HStack {
                    Text("max tokens")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    MonoOptionSelector(
                        options: [4096, 8192, 16384, 32000],
                        selection: $maxTokens,
                        labels: [4096: "4K", 8192: "8K", 16384: "16K", 32000: "32K"]
                    )
                    .onChange(of: maxTokens) { _, _ in hasChanges = true }
                    Spacer()
                }

                // Tone
                HStack {
                    Text("tone")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    MonoOptionSelector(
                        options: ["professional", "friendly", "concise", "detailed"],
                        selection: $tone
                    )
                    .onChange(of: tone) { _, _ in hasChanges = true }
                    Spacer()
                }

                // Verbosity
                HStack {
                    Text("verbosity")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    MonoOptionSelector(
                        options: ["minimal", "moderate", "verbose"],
                        selection: $verbosity
                    )
                    .onChange(of: verbosity) { _, _ in hasChanges = true }
                    Spacer()
                }
            }
        }
    }

    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SYSTEM PROMPT")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)

            TextEditor(text: $systemPrompt)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color.primary.opacity(0.03))
                .onChange(of: systemPrompt) { _, _ in hasChanges = true }
        }
    }

    private var actionsSection: some View {
        HStack(spacing: 16) {
            Button {
                selection = .aiChat
            } label: {
                Text("test chat")
                    .font(.system(size: 11, design: .monospaced))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            if hasChanges {
                Button {
                    loadAgent()
                    hasChanges = false
                } label: {
                    Text("discard")
                        .font(.system(size: 11, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }

            if isSaving {
                Text("saving...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Button {
                Task { await saveAgent() }
            } label: {
                Text("save")
                    .font(.system(size: 11, design: .monospaced))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!hasChanges || isSaving)
        }
    }

    // MARK: - Actions

    private func loadAgent() {
        name = agent.name ?? ""
        description = agent.description ?? ""
        systemPrompt = agent.systemPrompt ?? ""
        model = agent.model ?? "claude-sonnet-4-20250514"
        temperature = agent.temperature ?? 0.7
        maxTokens = agent.maxTokens ?? 32000
        isActive = agent.isActive
        enabledTools = Set(agent.enabledTools ?? [])
        tone = agent.tone ?? "professional"
        verbosity = agent.verbosity ?? "moderate"
        hasChanges = false
    }

    private func saveAgent() async {
        isSaving = true

        var updated = agent
        updated.name = name
        updated.description = description
        updated.systemPrompt = systemPrompt
        updated.model = model
        updated.temperature = temperature
        updated.maxTokens = maxTokens
        updated.isActive = isActive
        updated.enabledTools = Array(enabledTools)
        updated.tone = tone
        updated.verbosity = verbosity

        await store.updateAgent(updated)

        hasChanges = false
        isSaving = false
    }
}

// MARK: - Tool Toggle Component

private struct ToolToggle: View {
    let id: String
    let name: String
    let description: String
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(!isEnabled)
        } label: {
            HStack(spacing: 6) {
                Text(isEnabled ? "✓" : "○")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isEnabled ? .primary : .tertiary)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(isEnabled ? .primary : .secondary)
                    Text(description)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isEnabled ? Color.primary.opacity(0.04) : Color.primary.opacity(0.01))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Agent Header Section (Isolated)
// CRITICAL: Uses snapshot state to prevent layout recursion when chat panel opens
// Instead of @ObservedObject (which causes immediate re-renders), we use @State
// snapshots that only update via explicit timer, avoiding layout conflicts

private struct AgentHeaderSection: View {
    let name: String
    let description: String
    let isActive: Bool

    // Use @State snapshots instead of @ObservedObject to prevent layout recursion
    // These are updated via timer, not immediately on object change
    @State private var isConnected = false
    @State private var isServerRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name.isEmpty ? "Untitled" : name)
                        .font(.system(.title2, design: .monospaced, weight: .medium))
                    if !description.isEmpty {
                        Text(description)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Status indicators - minimal
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isConnected ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: 5, height: 5)
                        Text(isConnected ? "connected" : "offline")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(isActive ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: 5, height: 5)
                        Text(isActive ? "active" : "inactive")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Server Control - minimal
            serverControlSection
        }
        .onAppear {
            updateSnapshot()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            updateSnapshot()
        }
    }

    private func updateSnapshot() {
        // Update snapshots on a timer to avoid layout recursion
        // The actual shared objects are only accessed here, not observed
        let newConnected = AgentClient.shared.isConnected
        let newRunning = AgentProcessManager.shared.isRunning
        if isConnected != newConnected { isConnected = newConnected }
        if isServerRunning != newRunning { isServerRunning = newRunning }
    }

    private var serverControlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("SERVER")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Text(isConnected ? "online" : "offline")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(isConnected ? .primary : .tertiary)
                }

                Spacer()

                // Server control buttons - minimal text
                HStack(spacing: 10) {
                    if isServerRunning {
                        Button {
                            AgentProcessManager.shared.restart()
                        } label: {
                            Text("restart")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                        Button {
                            AgentProcessManager.shared.stop()
                        } label: {
                            Text("stop")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    } else if isConnected {
                        Button {
                            killExternalServer()
                        } label: {
                            Text("kill")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                        Button {
                            AgentClient.shared.disconnect()
                        } label: {
                            Text("disconnect")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    } else {
                        Button {
                            AgentProcessManager.shared.start()
                        } label: {
                            Text("start")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    if !isConnected && !isServerRunning {
                        Button {
                            AgentClient.shared.connect()
                        } label: {
                            Text("connect")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = AgentProcessManager.shared.error {
                Text(error)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if !AgentProcessManager.shared.lastOutput.isEmpty {
                Text(AgentProcessManager.shared.lastOutput)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.02))
        // NOTE: Removed .onAppear and .onChange(of: agentClient.isConnected) to prevent
        // observation-based layout recursion when chat panel opens
    }

    private func killExternalServer() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "lsof -ti :3847 | xargs kill -9 2>/dev/null"]
        try? process.run()
        process.waitUntilExit()
        AgentClient.shared.disconnect()
    }
}

// MARK: - Telemetry Section (Minimal)

private struct TelemetrySection: View {
    let storeId: UUID?
    @StateObject private var telemetry = TelemetryService.shared
    @ObservedObject private var agentClient = AgentClient.shared
    @State private var isExpanded = true
    @State private var showFullPanel = false
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header - compact
            HStack(spacing: 6) {
                Text("TELEMETRY")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)

                // Live indicator - minimal
                if telemetry.isLive {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 5, height: 5)
                }

                Spacer()

                // Compact stats
                if let stats = telemetry.stats {
                    HStack(spacing: 6) {
                        Text("\(stats.totalTraces)tr")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        if stats.errors > 0 {
                            Text("\(stats.errors)err")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    showFullPanel = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }

            if isExpanded {
                // Tab picker - compact
                HStack(spacing: 2) {
                    ForEach([0, 1, 2], id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(["live", "hist", "dbg"][tab])
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(selectedTab == tab ? Color.primary.opacity(0.1) : Color.clear)
                                .foregroundStyle(selectedTab == tab ? .primary : .tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                switch selectedTab {
                case 0:
                    liveToolsPanel
                case 1:
                    recentTracesPanel
                case 2:
                    debugPanel
                default:
                    liveToolsPanel
                }
            }
        }
        .task {
            await telemetry.fetchStats(storeId: storeId)
            await telemetry.fetchRecentTraces(storeId: storeId)
            telemetry.startRealtime(storeId: storeId)
        }
        .sheet(isPresented: $showFullPanel) {
            TelemetryPanel(storeId: storeId)
                .frame(minWidth: 900, minHeight: 600)
        }
    }

    // MARK: - Live Tools Panel

    private var liveToolsPanel: some View {
        Group {
            if agentClient.executionLogs.isEmpty {
                emptyState("No executions yet")
            } else {
                VStack(spacing: 6) {
                    sessionMetricsBar
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(agentClient.executionLogs) { log in
                                LiveToolRow(log: log)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                    .background(Color.primary.opacity(0.02))
                }
            }
        }
    }

    private var sessionMetricsBar: some View {
        let metrics = agentClient.sessionMetrics
        return HStack(spacing: 8) {
            metricItem("\(metrics.toolCalls)", "c")
            if metrics.errors > 0 {
                metricItem("\(metrics.errors)", "e")
            }
            metricItem(String(format: "%.0f%%", metrics.successRate * 100), "")
            metricItem(String(format: "%.0f", metrics.avgToolTime * 1000), "ms")
            Spacer()
            if let usage = metrics.finalUsage {
                Text(usage.formattedCost)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func metricItem(_ value: String, _ label: String) -> some View {
        HStack(spacing: 1) {
            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    // MARK: - Recent Traces Panel

    private var recentTracesPanel: some View {
        Group {
            if telemetry.isLoading && telemetry.recentTraces.isEmpty {
                Text("loading...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if telemetry.recentTraces.isEmpty {
                emptyState("No traces")
            } else {
                VStack(spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(TelemetryService.TimeRange.allCases, id: \.self) { range in
                            Button {
                                telemetry.timeRange = range
                                Task { await telemetry.fetchRecentTraces(storeId: storeId) }
                            } label: {
                                Text(range.rawValue)
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 3)
                                    .background(telemetry.timeRange == range ? Color.primary.opacity(0.1) : Color.clear)
                                    .foregroundStyle(telemetry.timeRange == range ? .primary : .tertiary)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Button {
                            Task { await telemetry.fetchRecentTraces(storeId: storeId) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                    }

                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(telemetry.recentTraces.prefix(20)) { trace in
                                CompactTraceRow(trace: trace)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                    .background(Color.primary.opacity(0.02))
                }
            }
        }
    }

    // MARK: - Debug Panel

    private var debugPanel: some View {
        Group {
            if agentClient.debugMessages.isEmpty {
                emptyState("No debug messages")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(agentClient.debugMessages) { msg in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(msg.level == .error ? Color.red : msg.level == .warn ? Color.orange : Color.secondary)
                                    .frame(width: 6, height: 6)
                                Text(msg.message)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 180)
                .background(Color.primary.opacity(0.02))
            }
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 60)
    }
}

// MARK: - Live Tool Row

private struct LiveToolRow: View {
    let log: ExecutionLogEntry

    private var statusIcon: String {
        switch log.status {
        case .success: return "✓"
        case .running: return "○"
        case .error: return "×"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(statusIcon)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(log.status == .error ? .secondary : .tertiary)
                .frame(width: 12)

            Text(log.toolName)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Text(log.formattedDuration)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)

            Text(log.startedAt, style: .time)
                .font(.system(size: 8))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
    }
}

// MARK: - Compact Trace Row

private struct CompactTraceRow: View {
    let trace: Trace

    var body: some View {
        HStack(spacing: 4) {
            // Status + ID
            HStack(spacing: 3) {
                Text(trace.hasErrors ? "×" : "✓")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(trace.hasErrors ? .secondary : .tertiary)

                Text(trace.id.prefix(6))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Tool count
            Text("\(trace.toolCount)t")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)

            Spacer()

            // Duration + time
            Text(trace.formattedDuration)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)

            Text(trace.startTime, style: .time)
                .font(.system(size: 8))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
    }
}

// MARK: - Agent Tools Section (Isolated)
// Contains tool list and observes AgentClient independently

private struct AgentToolsSection: View {
    @Binding var enabledTools: Set<String>
    @Binding var hasChanges: Bool

    // Observe AgentClient only in this child view
    @ObservedObject private var agentClient = AgentClient.shared

    // Cached tools by category
    @State private var toolsByCategoryCache: [(category: String, tools: [ToolMetadata])] = []
    @State private var lastToolsCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Enabled Tools (\(agentClient.availableTools.count) total)")
                    .font(.headline)
                Spacer()
                Text("\(enabledTools.count) enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Enable All") {
                    enabledTools = Set(agentClient.availableTools.map { $0.id })
                    hasChanges = true
                }
                .buttonStyle(.link)
                Button("Disable All") {
                    enabledTools = []
                    hasChanges = true
                }
                .buttonStyle(.link)
            }

            if agentClient.availableTools.isEmpty {
                GroupBox {
                    VStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Connect to agent server to load tools")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                ForEach(toolsByCategoryCache, id: \.category) { categoryGroup in
                    DisclosureGroup {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 8) {
                            ForEach(categoryGroup.tools) { tool in
                                ToolToggle(
                                    id: tool.id,
                                    name: tool.name,
                                    description: tool.description,
                                    isEnabled: enabledTools.contains(tool.id),
                                    onToggle: { enabled in
                                        if enabled {
                                            enabledTools.insert(tool.id)
                                        } else {
                                            enabledTools.remove(tool.id)
                                        }
                                        hasChanges = true
                                    }
                                )
                            }
                        }
                        .padding(8)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: categoryIcon(categoryGroup.category))
                                .foregroundStyle(.tertiary)
                                .frame(width: 20)
                            Text(categoryDisplayName(categoryGroup.category))
                                .font(.subheadline.weight(.medium))
                            Text("\(categoryGroup.tools.count)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            let enabledCount = categoryGroup.tools.filter { enabledTools.contains($0.id) }.count
                            if enabledCount > 0 {
                                Text("\(enabledCount)")
                                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .onAppear { updateToolsCache() }
        .onChange(of: agentClient.availableTools.count) { _, _ in updateToolsCache() }
    }

    private func updateToolsCache() {
        let newCount = agentClient.availableTools.count
        guard newCount != lastToolsCount else { return }
        lastToolsCount = newCount
        let grouped = Dictionary(grouping: agentClient.availableTools) { $0.category }
        toolsByCategoryCache = grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private func categoryDisplayName(_ category: String) -> String {
        switch category {
        case "github": return "GitHub"
        case "supabase": return "Supabase"
        case "vercel": return "Vercel"
        case "inventory": return "Inventory"
        case "orders": return "Orders"
        case "customers": return "Customers"
        case "analytics": return "Analytics"
        case "images": return "Images"
        case "email": return "Email"
        case "build": return "Build"
        case "server": return "Server"
        case "database": return "Database"
        case "codebase": return "Codebase"
        case "collections": return "Collections"
        case "locations": return "Locations"
        default: return category.capitalized
        }
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "github": return "chevron.left.forwardslash.chevron.right"
        case "supabase": return "server.rack"
        case "vercel": return "triangle.fill"
        case "inventory": return "shippingbox"
        case "orders": return "cart"
        case "customers": return "person.2"
        case "products": return "tag"
        case "analytics": return "chart.bar"
        case "browser": return "safari"
        case "images": return "photo"
        case "email": return "envelope"
        case "build": return "hammer"
        case "server": return "server.rack"
        case "database": return "cylinder"
        case "codebase": return "doc.text"
        case "collections": return "folder"
        case "locations": return "mappin"
        default: return "wrench"
        }
    }
}

// MARK: - Custom Tools Section (User-Created Tools)

private struct CustomToolsSection: View {
    @Environment(\.editorStore) private var store
    @State private var tools: [UserTool] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var editingTool: UserTool?
    @State private var deletingTool: UserTool?
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CUSTOM TOOLS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text("\(tools.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Text("+ new")
                        .font(.system(size: 10, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if isLoading {
                Text("loading...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            } else if tools.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No tools defined")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Create tools for RPC, HTTP APIs, or SQL queries")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Button {
                        showCreateSheet = true
                    } label: {
                        Text("create first tool")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.02))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: 8) {
                    ForEach(tools) { tool in
                        UserToolCard(
                            tool: tool,
                            onEdit: { editingTool = tool },
                            onDelete: {
                                deletingTool = tool
                                showDeleteConfirm = true
                            },
                            onRefresh: loadTools
                        )
                    }
                }
            }
        }
        .task { await loadTools() }
        .sheet(isPresented: $showCreateSheet, onDismiss: { Task { await loadTools() } }) {
            UserToolEditorSheet(tool: nil)
        }
        .sheet(item: $editingTool, onDismiss: { Task { await loadTools() } }) { tool in
            UserToolEditorSheet(tool: tool)
        }
        .alert("Delete Tool?", isPresented: $showDeleteConfirm, presenting: deletingTool) { tool in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    _ = await store.deleteUserTool(tool)
                    await loadTools()
                }
            }
        } message: { tool in
            Text("This will permanently delete \"\(tool.displayName)\" and any associated triggers.")
        }
    }

    private func loadTools() async {
        isLoading = true
        await store.loadUserTools()
        tools = store.userTools
        isLoading = false
    }
}

// MARK: - User Tool Card

private struct UserToolCard: View {
    let tool: UserTool
    @Environment(\.editorStore) private var store
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onRefresh: (() async -> Void)?

    @State private var showTestSheet = false
    @State private var testInput: String = "{}"
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: tool.icon)
                    .font(.caption)
                    .foregroundStyle(tool.isActive ? .primary : .tertiary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(tool.displayName)
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    Text(tool.name)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Status indicators - minimal
                HStack(spacing: 6) {
                    if tool.isTested {
                        Text("✓")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    if tool.requiresApproval {
                        Text("!")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text(tool.executionType.rawValue.uppercased())
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            // Description
            Text(tool.description)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Divider()

            // Actions - minimal
            HStack(spacing: 12) {
                Button {
                    // Build default test input from schema
                    if let schema = tool.inputSchema, let props = schema.properties {
                        var defaultInput: [String: Any] = [:]
                        for (key, prop) in props {
                            if prop.type == "string" {
                                defaultInput[key] = prop.description ?? "test_value"
                            } else if prop.type == "number" {
                                defaultInput[key] = 0
                            } else if prop.type == "boolean" {
                                defaultInput[key] = true
                            } else if prop.type == "array" {
                                defaultInput[key] = []
                            }
                        }
                        if let jsonData = try? JSONSerialization.data(withJSONObject: defaultInput, options: .prettyPrinted),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            testInput = jsonString
                        }
                    }
                    showTestSheet = true
                } label: {
                    Text("test")
                        .font(.system(size: 10, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onEdit()
                } label: {
                    Text("edit")
                        .font(.system(size: 10, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    onDelete()
                } label: {
                    Text("delete")
                        .font(.system(size: 10, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.02))
        .sheet(isPresented: $showTestSheet) {
            testToolSheet
        }
    }

    private var testToolSheet: some View {
        VStack(spacing: 0) {
            // Header - Anthropic style
            HStack {
                Text("TEST")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(tool.name)
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                Spacer()
                Button("Close") { showTestSheet = false }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // Input
                VStack(alignment: .leading, spacing: 6) {
                    Text("INPUT")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    TextEditor(text: $testInput)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Color.primary.opacity(0.03))
                }

                // Result
                if let result = testResult {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OUTPUT")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        ScrollView {
                            Text(result)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 180)
                        .padding(10)
                        .background(Color.primary.opacity(0.03))
                    }
                }
            }
            .padding(20)

            Divider()

            // Footer
            HStack {
                if isTesting {
                    Text("Running...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Run") {
                    Task { await runTest() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isTesting)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 480, height: 420)
    }

    private func runTest() async {
        isTesting = true
        testResult = nil

        // Parse input JSON
        guard let inputData = testInput.data(using: .utf8),
              let inputDict = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] else {
            testResult = "Error: Invalid JSON input"
            isTesting = false
            return
        }

        // Call the actual test
        let result = await store.testUserTool(tool, args: inputDict)

        // Format result
        if result.success {
            if let output = result.output?.value {
                if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
                   let jsonString = String(data: data, encoding: .utf8) {
                    testResult = "SUCCESS (\(result.executionTimeMs ?? 0)ms)\n\n\(jsonString)"
                } else {
                    testResult = "SUCCESS (\(result.executionTimeMs ?? 0)ms)\n\n\(output)"
                }
            } else {
                testResult = "SUCCESS (\(result.executionTimeMs ?? 0)ms)"
            }
        } else {
            testResult = "FAILED (\(result.executionTimeMs ?? 0)ms)\n\nError: \(result.error ?? "Unknown error")"
        }

        isTesting = false
    }
}

// MARK: - Triggers Section

private struct TriggersSection: View {
    @Environment(\.editorStore) private var store
    @State private var triggers: [UserTrigger] = []
    @State private var tools: [UserTool] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var editingTrigger: UserTrigger?
    @State private var deletingTrigger: UserTrigger?
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TRIGGERS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text("\(triggers.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Text("+ new")
                        .font(.system(size: 10, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(tools.isEmpty)
            }

            if isLoading {
                Text("loading...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            } else if tools.isEmpty {
                Text("Create a tool first to add triggers")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.02))
            } else if triggers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No triggers defined")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Triggers run tools on events, schedules, or conditions")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Button {
                        showCreateSheet = true
                    } label: {
                        Text("create first trigger")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.02))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: 8) {
                    ForEach(triggers) { trigger in
                        TriggerCard(
                            trigger: trigger,
                            tool: tools.first { $0.id == trigger.toolId },
                            onEdit: { editingTrigger = trigger },
                            onDelete: {
                                deletingTrigger = trigger
                                showDeleteConfirm = true
                            },
                            onFire: {
                                Task { _ = await store.fireTrigger(trigger, payload: nil) }
                            }
                        )
                    }
                }
            }
        }
        .task { await loadData() }
        .sheet(isPresented: $showCreateSheet, onDismiss: { Task { await loadData() } }) {
            TriggerEditorSheet(trigger: nil)
        }
        .sheet(item: $editingTrigger, onDismiss: { Task { await loadData() } }) { trigger in
            TriggerEditorSheet(trigger: trigger)
        }
        .alert("Delete Trigger?", isPresented: $showDeleteConfirm, presenting: deletingTrigger) { trigger in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    _ = await store.deleteUserTrigger(trigger)
                    await loadData()
                }
            }
        } message: { trigger in
            Text("This will permanently delete the trigger \"\(trigger.name)\".")
        }
    }

    private func loadData() async {
        isLoading = true
        await store.loadUserTriggers()
        triggers = store.userTriggers
        tools = store.userTools
        isLoading = false
    }
}

// MARK: - Trigger Card

private struct TriggerCard: View {
    let trigger: UserTrigger
    let tool: UserTool?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onFire: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: trigger.triggerType.icon)
                    .font(.caption)
                    .foregroundStyle(trigger.isActive ? .primary : .tertiary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(trigger.name)
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    if let tool = tool {
                        Text("→ \(tool.displayName)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Text(trigger.triggerType.displayName.uppercased())
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            // Description
            if let description = trigger.description {
                Text(description)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Event details - minimal
            if trigger.triggerType == .event {
                HStack(spacing: 8) {
                    if let table = trigger.eventTable {
                        Text(table)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if let op = trigger.eventOperation {
                        Text(op.displayName.uppercased())
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            } else if trigger.triggerType == .schedule, let cron = trigger.cronExpression {
                Text(cron)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Actions - minimal
            HStack(spacing: 12) {
                Button {
                    onFire()
                } label: {
                    Text("fire")
                        .font(.system(size: 10, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onEdit()
                } label: {
                    Text("edit")
                        .font(.system(size: 10, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    onDelete()
                } label: {
                    Text("delete")
                        .font(.system(size: 10, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.02))
    }
}

// MARK: - User Tool Editor Sheet

private struct UserToolEditorSheet: View {
    @Environment(\.editorStore) private var store
    let tool: UserTool?
    @Environment(\.dismiss) private var dismiss

    // Basic Info
    @State private var name = ""
    @State private var displayName = ""
    @State private var description = ""
    @State private var category = "custom"
    @State private var icon = "wrench.fill"

    // Execution
    @State private var executionType: UserTool.ExecutionType = .rpc
    @State private var rpcFunction = ""
    @State private var httpUrl = ""
    @State private var httpMethod: HTTPConfig.HTTPMethod = .GET
    @State private var httpHeaders: [String: String] = [:]
    @State private var sqlTemplate = ""
    @State private var selectedTables: Set<String> = []

    // API Secrets
    @State private var apiSecrets: [String: String] = [:]
    @State private var existingSecretNames: Set<String> = []

    // Batch Config
    @State private var batchEnabled = false
    @State private var batchMaxConcurrent = 5
    @State private var batchDelayMs = 100
    @State private var batchSize = 10
    @State private var batchInputPath = ""
    @State private var batchContinueOnError = true

    // Response Mapping
    @State private var resultPath = ""
    @State private var errorPath = ""

    // Input Parameters
    @State private var inputParameters: [InputParameter] = []
    @State private var showAddParameter = false

    // Settings
    @State private var isReadOnly = true
    @State private var requiresApproval = false
    @State private var isActive = true
    @State private var maxExecutionTimeMs = 5000

    @State private var isSaving = false

    // Available tables for SQL queries (store-scoped tables only)
    private let availableTables = [
        ("orders", "Customer orders"),
        ("order_items", "Line items in orders"),
        ("customers", "Customer profiles"),
        ("customer_loyalty", "Loyalty points & tiers"),
        ("inventory", "Stock levels by location"),
        ("locations", "Store locations"),
        ("carts", "Active shopping carts"),
        ("cart_items", "Items in carts")
    ]

    private let icons = [
        "wrench.fill", "function", "network", "tablecells", "gear",
        "bolt.fill", "cube.fill", "doc.text", "chart.bar", "envelope",
        "cart.fill", "person.fill", "shippingbox.fill", "tag.fill"
    ]

    private let categories = [
        ("custom", "Custom"),
        ("orders", "Orders"),
        ("inventory", "Inventory"),
        ("customers", "Customers"),
        ("analytics", "Analytics"),
        ("notifications", "Notifications")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sheetHeader

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    basicInfoSection
                    executionTypeSection
                    if executionType == .http {
                        batchConfigSection
                    }
                    inputParametersSection
                    settingsSection
                }
                .padding(24)
            }

            Divider()

            // Footer
            sheetFooter
        }
        .frame(width: 600, height: 700)
        .onAppear { loadTool() }
        .task {
            // Load existing secret names
            if let storeId = store.selectedStore?.id {
                let names = await store.loadToolSecretNames(storeId: storeId)
                existingSecretNames = Set(names)
            }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Text(tool == nil ? "NEW" : "EDIT")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text("Tool")
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
            Spacer()
            Button("Close") { dismiss() }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Basic Info

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BASIC INFO")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Icon picker - minimal
                    Menu {
                        ForEach(icons, id: \.self) { iconName in
                            Button {
                                icon = iconName
                            } label: {
                                Label(iconName, systemImage: iconName)
                            }
                        }
                    } label: {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color.primary.opacity(0.04))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(.plain)
                            .font(.system(.body, weight: .medium))
                            .padding(8)
                            .background(Color.primary.opacity(0.03))

                        TextField("internal_name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.primary.opacity(0.03))
                            .disableAutocorrection(true)
                    }
                }

                TextField("Description", text: $description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(.caption))
                    .lineLimit(2...3)
                    .padding(8)
                    .background(Color.primary.opacity(0.03))

                HStack {
                    Text("Category")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $category) {
                        ForEach(categories, id: \.0) { id, name in
                            Text(name).tag(id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
    }

    // MARK: - Execution Type

    private var executionTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXECUTION")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(UserTool.ExecutionType.allCases, id: \.self) { type in
                        Button {
                            executionType = type
                        } label: {
                            Text(type.displayName)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(executionType == type ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
                                .foregroundStyle(executionType == type ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                switch executionType {
                case .rpc:
                    rpcConfigSection
                case .http:
                    httpConfigSection
                case .sql:
                    sqlConfigSection
                }
            }
        }
    }

    private var rpcConfigSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("function_name", text: $rpcFunction)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .background(Color.primary.opacity(0.03))
                .autocorrectionDisabled()

            Text("RPC receives (p_store_id UUID, p_args JSONB). store_id auto-injected.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    private var httpConfigSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // URL & Method
            VStack(alignment: .leading, spacing: 8) {
                TextField("https://api.example.com/endpoint", text: $httpUrl)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .background(Color.primary.opacity(0.03))
                    .autocorrectionDisabled()

                HStack(spacing: 4) {
                    ForEach(HTTPConfig.HTTPMethod.allCases, id: \.self) { method in
                        Button {
                            httpMethod = method
                        } label: {
                            Text(method.rawValue)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(httpMethod == method ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
                                .foregroundStyle(httpMethod == method ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Response Mapping
            responseMappingSection

            Text("Server-side execution. Secrets encrypted, injected via {{SECRET_NAME}}.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    private var responseMappingSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("result")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                    TextField("data.url", text: $resultPath)
                        .textFieldStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .padding(6)
                        .background(Color.primary.opacity(0.03))
                }

                HStack(spacing: 8) {
                    Text("error")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                    TextField("error.message", text: $errorPath)
                        .textFieldStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .padding(6)
                        .background(Color.primary.opacity(0.03))
                }
            }
            .padding(.top, 6)
        } label: {
            Text("RESPONSE MAPPING")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Batch Config Section

    private var batchConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("BATCH")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Toggle("", isOn: $batchEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }

            if batchEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("concurrent")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Stepper("\(batchMaxConcurrent)", value: $batchMaxConcurrent, in: 1...20)
                                .frame(width: 90)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("delay ms")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Stepper("\(batchDelayMs)", value: $batchDelayMs, in: 0...5000, step: 50)
                                .frame(width: 90)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("batch size")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Stepper("\(batchSize)", value: $batchSize, in: 1...100)
                                .frame(width: 90)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("input array path")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        TextField("image_urls, prompts, recipients", text: $batchInputPath)
                            .textFieldStyle(.plain)
                            .font(.system(.caption, design: .monospaced))
                            .padding(6)
                            .background(Color.primary.opacity(0.03))
                    }

                    Toggle("continue on failure", isOn: $batchContinueOnError)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Process multiple items in a single call")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var sqlConfigSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Table selector
            VStack(alignment: .leading, spacing: 6) {
                Text("TABLES")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 4) {
                    ForEach(availableTables, id: \.0) { table, desc in
                        Button {
                            if selectedTables.contains(table) {
                                selectedTables.remove(table)
                            } else {
                                selectedTables.insert(table)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedTables.contains(table) ? "✓" : "○")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(selectedTables.contains(table) ? .primary : .tertiary)
                                Text(table)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(selectedTables.contains(table) ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(selectedTables.contains(table) ? Color.primary.opacity(0.06) : Color.primary.opacity(0.02))
                        }
                        .buttonStyle(.plain)
                        .help(desc)
                    }
                }
            }

            // SQL Editor
            VStack(alignment: .leading, spacing: 6) {
                Text("QUERY")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)

                TextEditor(text: $sqlTemplate)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.primary.opacity(0.03))
            }

            Text("SELECT only. store_id auto-injected. Use $param for inputs.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Input Parameters

    private var inputParametersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("INPUT PARAMETERS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    inputParameters.append(InputParameter(name: "", type: "string", description: "", required: true))
                } label: {
                    Text("+ add")
                        .font(.system(size: 10, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if inputParameters.isEmpty {
                Text("No parameters defined")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach($inputParameters) { $param in
                        InputParameterRow(parameter: $param) {
                            inputParameters.removeAll { $0.id == param.id }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SETTINGS")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)

            VStack(spacing: 8) {
                HStack {
                    Text("read only")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $isReadOnly)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                }
                HStack {
                    Text("requires approval")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $requiresApproval)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                }
                HStack {
                    Text("active")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $isActive)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                }

                Divider()

                HStack {
                    Text("timeout")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    MonoOptionSelector(
                        options: [1000, 5000, 15000, 30000, 60000],
                        selection: $maxExecutionTimeMs,
                        labels: [1000: "1s", 5000: "5s", 15000: "15s", 30000: "30s", 60000: "60s"]
                    )
                }
            }
        }
    }

    // MARK: - Footer

    private var sheetFooter: some View {
        HStack {
            if tool != nil {
                Button("Delete") {
                    // Handle delete
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }

            Spacer()

            if isSaving {
                Text("saving...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Button(tool == nil ? "Create" : "Save") {
                Task { await saveTool() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!isValid || isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Validation

    private var isValid: Bool {
        guard !name.isEmpty, !displayName.isEmpty else { return false }

        switch executionType {
        case .rpc:
            return !rpcFunction.isEmpty
        case .http:
            return !httpUrl.isEmpty
        case .sql:
            return !sqlTemplate.isEmpty && !selectedTables.isEmpty
        }
    }

    // MARK: - Load/Save

    private func loadTool() {
        guard let tool = tool else { return }
        name = tool.name
        displayName = tool.displayName
        description = tool.description
        category = tool.category
        icon = tool.icon
        executionType = tool.executionType
        rpcFunction = tool.rpcFunction ?? ""
        if let config = tool.httpConfig {
            httpUrl = config.url
            httpMethod = config.method
            httpHeaders = config.headers ?? [:]

            // Load batch config
            if let batch = config.batchConfig {
                batchEnabled = batch.enabled
                batchMaxConcurrent = batch.maxConcurrent
                batchDelayMs = batch.delayBetweenMs
                batchSize = batch.batchSize
                batchInputPath = batch.inputArrayPath ?? ""
                batchContinueOnError = batch.continueOnError
            }

            // Load response mapping
            if let mapping = config.responseMapping {
                resultPath = mapping.resultPath ?? ""
                errorPath = mapping.errorPath ?? ""
            }

        }
        sqlTemplate = tool.sqlTemplate ?? ""
        selectedTables = Set(tool.allowedTables ?? [])
        isReadOnly = tool.isReadOnly
        requiresApproval = tool.requiresApproval
        isActive = tool.isActive
        maxExecutionTimeMs = tool.maxExecutionTimeMs

        // Load input parameters from schema
        if let schema = tool.inputSchema, let props = schema.properties {
            inputParameters = props.map { key, value in
                InputParameter(
                    name: key,
                    type: value.type,
                    description: value.description ?? "",
                    required: schema.required?.contains(key) ?? false
                )
            }
        }
    }

    private func saveTool() async {
        guard let storeId = store.selectedStore?.id else { return }
        isSaving = true

        // Save secrets first (if any)
        if executionType == .http && !apiSecrets.isEmpty {
            await store.saveToolSecrets(storeId: storeId, toolId: tool?.id, secrets: apiSecrets)
        }

        var newTool = tool ?? UserTool(storeId: storeId)
        newTool.name = name.lowercased().replacingOccurrences(of: " ", with: "_")
        newTool.displayName = displayName
        newTool.description = description
        newTool.category = category
        newTool.icon = icon
        newTool.executionType = executionType
        newTool.isReadOnly = isReadOnly
        newTool.requiresApproval = requiresApproval
        newTool.isActive = isActive
        newTool.maxExecutionTimeMs = maxExecutionTimeMs

        // Build input schema
        if !inputParameters.isEmpty {
            var properties: [String: PropertySchema] = [:]
            var required: [String] = []
            for param in inputParameters {
                properties[param.name] = PropertySchema(type: param.type, description: param.description)
                if param.required {
                    required.append(param.name)
                }
            }
            newTool.inputSchema = InputSchema(type: "object", properties: properties, required: required.isEmpty ? nil : required)
        } else {
            newTool.inputSchema = nil
        }

        switch executionType {
        case .rpc:
            newTool.rpcFunction = rpcFunction
            newTool.httpConfig = nil
            newTool.sqlTemplate = nil
            newTool.allowedTables = nil
        case .http:
            // Build batch config if enabled
            let batchConfig: BatchConfig? = batchEnabled ? BatchConfig(
                enabled: true,
                maxConcurrent: batchMaxConcurrent,
                delayBetweenMs: batchDelayMs,
                batchSize: batchSize,
                inputArrayPath: batchInputPath.isEmpty ? nil : batchInputPath,
                retryOnFailure: true,
                continueOnError: batchContinueOnError
            ) : nil

            // Build response mapping if configured
            let responseMapping: ResponseMapping? = (!resultPath.isEmpty || !errorPath.isEmpty) ? ResponseMapping(
                resultPath: resultPath.isEmpty ? nil : resultPath,
                errorPath: errorPath.isEmpty ? nil : errorPath
            ) : nil

            newTool.httpConfig = HTTPConfig(
                url: httpUrl,
                method: httpMethod,
                headers: httpHeaders.isEmpty ? nil : httpHeaders,
                batchConfig: batchConfig,
                responseMapping: responseMapping
            )
            newTool.rpcFunction = nil
            newTool.sqlTemplate = nil
            newTool.allowedTables = nil
        case .sql:
            newTool.sqlTemplate = sqlTemplate
            newTool.allowedTables = Array(selectedTables)
            newTool.rpcFunction = nil
            newTool.httpConfig = nil
        }

        if tool == nil {
            _ = await store.createUserTool(newTool)
        } else {
            _ = await store.updateUserTool(newTool)
        }

        isSaving = false
        dismiss()
    }
}

// MARK: - Input Parameter Model

private struct InputParameter: Identifiable {
    let id = UUID()
    var name: String
    var type: String
    var description: String
    var required: Bool
}

// MARK: - Input Parameter Row

private struct InputParameterRow: View {
    @Binding var parameter: InputParameter
    let onDelete: () -> Void

    private let types = ["string", "number", "boolean", "array"]

    var body: some View {
        HStack(spacing: 8) {
            TextField("name", text: $parameter.name)
                .textFieldStyle(.plain)
                .font(.system(.caption, design: .monospaced))
                .padding(6)
                .background(Color.primary.opacity(0.03))
                .frame(width: 90)

            Picker("", selection: $parameter.type) {
                ForEach(types, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 75)

            TextField("description", text: $parameter.description)
                .textFieldStyle(.plain)
                .font(.system(.caption, design: .monospaced))
                .padding(6)
                .background(Color.primary.opacity(0.03))

            Text(parameter.required ? "req" : "opt")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(parameter.required ? .primary : .tertiary)
                .onTapGesture { parameter.required.toggle() }

            Button { onDelete() } label: {
                Text("×")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color.primary.opacity(0.02))
    }
}

// MARK: - Trigger Editor Sheet

private struct TriggerEditorSheet: View {
    @Environment(\.editorStore) private var store
    let trigger: UserTrigger?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var selectedToolId: UUID?
    @State private var triggerType: UserTrigger.TriggerType = .event
    @State private var eventTable = ""
    @State private var eventOperation: UserTrigger.EventOperation = .INSERT
    @State private var cronExpression = ""
    @State private var conditionSql = ""
    @State private var maxRetries = 3
    @State private var retryDelaySeconds = 60
    @State private var cooldownSeconds: Int? = nil
    @State private var maxExecutionsPerHour: Int? = nil
    @State private var isActive = true
    @State private var isSaving = false

    private let availableTables = [
        ("orders", "Customer orders"),
        ("order_items", "Line items in orders"),
        ("customers", "Customer profiles"),
        ("customer_loyalty", "Loyalty points & tiers"),
        ("inventory", "Stock levels by location"),
        ("locations", "Store locations"),
        ("carts", "Active shopping carts"),
        ("cart_items", "Items in carts")
    ]

    private var isValid: Bool {
        !name.isEmpty && selectedToolId != nil && (triggerType != .event || !eventTable.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - Anthropic style
            HStack {
                Text(trigger == nil ? "NEW" : "EDIT")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text("Trigger")
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                Spacer()
                Button("Close") { dismiss() }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BASIC INFO")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Trigger name", text: $name)
                                .textFieldStyle(.plain)
                                .font(.system(.body, weight: .medium))
                                .padding(8)
                                .background(Color.primary.opacity(0.03))

                            TextField("Description (optional)", text: $description, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(.caption))
                                .lineLimit(2...4)
                                .padding(8)
                                .background(Color.primary.opacity(0.03))
                        }
                    }

                    Divider()

                    // Tool Selection Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TOOL")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        if store.userTools.isEmpty {
                            Text("Create a tool first")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        } else {
                            Picker("Tool", selection: $selectedToolId) {
                                Text("select...").tag(nil as UUID?)
                                ForEach(store.userTools) { tool in
                                    Text(tool.displayName.isEmpty ? tool.name : tool.displayName)
                                        .tag(tool.id as UUID?)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    Divider()

                    // Trigger Type Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TYPE")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        // Trigger type buttons - minimal
                        HStack(spacing: 6) {
                            ForEach(UserTrigger.TriggerType.allCases, id: \.self) { type in
                                Button {
                                    triggerType = type
                                } label: {
                                    VStack(spacing: 3) {
                                        Image(systemName: type.icon)
                                            .font(.caption)
                                            .foregroundStyle(triggerType == type ? .primary : .secondary)
                                        Text(type.displayName.uppercased())
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(triggerType == type ? .primary : .tertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(triggerType == type ? Color.primary.opacity(0.08) : Color.primary.opacity(0.02))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Trigger-specific configuration
                        if triggerType == .event {
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("table")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.tertiary)

                                    Picker("Table", selection: $eventTable) {
                                        Text("select...").tag("")
                                        ForEach(availableTables, id: \.0) { table in
                                            Text(table.0).tag(table.0)
                                        }
                                    }
                                    .labelsHidden()
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("operation")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.tertiary)

                                    HStack(spacing: 4) {
                                        ForEach(UserTrigger.EventOperation.allCases, id: \.self) { op in
                                            Button {
                                                eventOperation = op
                                            } label: {
                                                Text(op.displayName.uppercased())
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundStyle(eventOperation == op ? .primary : .tertiary)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 6)
                                                    .background(eventOperation == op ? Color.primary.opacity(0.08) : Color.primary.opacity(0.02))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                Text("Fires on row changes. Tool receives row data.")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.top, 6)
                        } else if triggerType == .schedule {
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("cron expression")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.tertiary)

                                    TextField("0 9 * * *", text: $cronExpression)
                                        .textFieldStyle(.plain)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(8)
                                        .background(Color.primary.opacity(0.03))
                                }

                                Text("Example: '0 9 * * *' = daily at 9am")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.top, 6)
                        } else if triggerType == .condition {
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("condition sql")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.tertiary)

                                    TextField("SELECT COUNT(*) > 10 FROM ...", text: $conditionSql, axis: .vertical)
                                        .textFieldStyle(.plain)
                                        .lineLimit(3...6)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(8)
                                        .background(Color.primary.opacity(0.03))
                                }

                                Text("Fires when SQL returns true. Checked periodically.")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.top, 6)
                        }
                    }

                    Divider()

                    // Retry Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RETRY")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("max retries")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                Stepper("\(maxRetries)", value: $maxRetries, in: 0...10)
                                    .frame(width: 90)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("delay (s)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                Stepper("\(retryDelaySeconds)", value: $retryDelaySeconds, in: 10...3600, step: 10)
                                    .frame(width: 90)
                            }
                        }

                        Text("Exponential backoff applied")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    Divider()

                    // Status Section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("STATUS")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Toggle("", isOn: $isActive)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .scaleEffect(0.8)
                        }

                        Text(isActive ? "Active - will fire on events" : "Inactive - configuration preserved")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                if isSaving {
                    Text("saving...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button(trigger == nil ? "Create" : "Save") {
                    Task { await saveTrigger() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!isValid || isSaving)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 600)
        .onAppear { loadTrigger() }
    }

    private func loadTrigger() {
        guard let trigger = trigger else { return }
        name = trigger.name
        description = trigger.description ?? ""
        selectedToolId = trigger.toolId
        triggerType = trigger.triggerType
        eventTable = trigger.eventTable ?? ""
        eventOperation = trigger.eventOperation ?? .INSERT
        cronExpression = trigger.cronExpression ?? ""
        conditionSql = trigger.conditionSql ?? ""
        maxRetries = trigger.maxRetries
        retryDelaySeconds = trigger.retryDelaySeconds
        cooldownSeconds = trigger.cooldownSeconds
        maxExecutionsPerHour = trigger.maxExecutionsPerHour
        isActive = trigger.isActive
    }

    private func saveTrigger() async {
        guard let storeId = store.selectedStore?.id,
              let toolId = selectedToolId else { return }
        isSaving = true

        var newTrigger = trigger ?? UserTrigger(storeId: storeId, toolId: toolId)
        newTrigger.name = name
        newTrigger.description = description.isEmpty ? nil : description
        newTrigger.toolId = toolId
        newTrigger.triggerType = triggerType
        newTrigger.eventTable = triggerType == .event ? eventTable : nil
        newTrigger.eventOperation = triggerType == .event ? eventOperation : nil
        newTrigger.cronExpression = triggerType == .schedule ? cronExpression : nil
        newTrigger.conditionSql = triggerType == .condition ? conditionSql : nil
        newTrigger.maxRetries = maxRetries
        newTrigger.retryDelaySeconds = retryDelaySeconds
        newTrigger.cooldownSeconds = cooldownSeconds
        newTrigger.maxExecutionsPerHour = maxExecutionsPerHour
        newTrigger.isActive = isActive

        if trigger == nil {
            _ = await store.createUserTrigger(newTrigger)
        } else {
            _ = await store.updateUserTrigger(newTrigger)
        }

        isSaving = false
        dismiss()
    }
}
