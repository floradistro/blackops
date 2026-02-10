import SwiftUI

// MARK: - Telemetry Section (Minimal)

struct TelemetrySection: View {
    let storeId: UUID?
    @Environment(\.telemetryService) private var telemetry
    @State private var isExpanded = true
    @State private var showFullPanel = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header - compact
            HStack(spacing: 6) {
                Text("TELEMETRY")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)

                if telemetry.isLive {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 5, height: 5)
                }

                Spacer()

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
                recentTracesPanel
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

    private var recentTracesPanel: some View {
        Group {
            if telemetry.isLoading && telemetry.recentTraces.isEmpty {
                Text("loading...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if telemetry.recentTraces.isEmpty {
                Text("No traces")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60)
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
                    .background(DesignSystem.Colors.surfaceTertiary)
                }
            }
        }
    }
}

// MARK: - Compact Trace Row

struct CompactTraceRow: View {
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

// MARK: - Agent Tools Section
// Loads tools from ai_tool_registry in Supabase

struct AgentToolsSection: View {
    @Binding var enabledTools: Set<String>
    @Binding var hasChanges: Bool
    var isGlobalAgent: Bool = false

    @State private var registryTools: [ToolMetadata] = []
    @State private var codeTools: [ToolMetadata] = []
    @State private var isLoading = true
    @State private var toolsByCategoryCache: [(category: String, tools: [ToolMetadata])] = []
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Server tools header
            HStack {
                Text("SERVER TOOLS")
                    .font(DesignSystem.Typography.monoHeader)
                    .foregroundStyle(.tertiary)
                Text("\(registryTools.count) available")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(enabledTools.count) enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("All") {
                    enabledTools = Set(registryTools.map { $0.id })
                    hasChanges = true
                }
                .buttonStyle(.link)
                .font(.system(size: 10))
                Button("None") {
                    enabledTools = []
                    hasChanges = true
                }
                .buttonStyle(.link)
                .font(.system(size: 10))
            }

            if let loadError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Text(loadError)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.surfaceTertiary)
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading tools from registry...")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if registryTools.isEmpty {
                Text("No tools in registry")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60)
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
                            Text(categoryGroup.category.capitalized)
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
                    .background(DesignSystem.Colors.surfaceTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // Local code tools — only for global agents (Whale Code)
            if isGlobalAgent && !codeTools.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("LOCAL TOOLS")
                            .font(DesignSystem.Typography.monoHeader)
                            .foregroundStyle(.tertiary)
                        Text("\(codeTools.count) auto-loaded")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("managed by CLI")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }

                    DisclosureGroup {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 8) {
                            ForEach(codeTools) { tool in
                                HStack(spacing: 6) {
                                    Image(systemName: "terminal")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 14)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(tool.name)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Text(tool.description)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(8)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .foregroundStyle(.tertiary)
                                .frame(width: 20)
                            Text("Code")
                                .font(.subheadline.weight(.medium))
                            Text("\(codeTools.count)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text("always on")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.quaternary)
                        }
                    }
                    .padding(8)
                    .background(DesignSystem.Colors.surfaceTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .task { await loadToolsFromRegistry() }
    }

    private func loadToolsFromRegistry() async {
        isLoading = true
        do {
            struct RegistryTool: Decodable {
                let name: String
                let description: String?
                let category: String?
                let toolMode: String?

                enum CodingKeys: String, CodingKey {
                    case name, description, category
                    case toolMode = "tool_mode"
                }
            }
            let allTools: [RegistryTool] = try await SupabaseService.shared.client
                .from("ai_tool_registry")
                .select("name, description, category, tool_mode")
                .eq("is_active", value: true)
                .execute()
                .value

            // Split into server tools and code tools
            var serverList: [ToolMetadata] = []
            var codeList: [ToolMetadata] = []
            for t in allTools {
                let meta = ToolMetadata(id: t.name, name: t.name, description: t.description ?? t.name, category: t.category ?? "general")
                if t.toolMode == "code" {
                    codeList.append(meta)
                } else {
                    serverList.append(meta)
                }
            }

            registryTools = serverList
            codeTools = codeList.sorted { $0.name < $1.name }
            let grouped = Dictionary(grouping: registryTools) { $0.category }
            toolsByCategoryCache = grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        } catch {
            loadError = "Failed to load tools: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "inventory": return "shippingbox"
        case "orders": return "cart"
        case "customers": return "person.2"
        case "products": return "tag"
        case "analytics": return "chart.bar"
        case "email": return "envelope"
        case "collections": return "folder"
        case "locations": return "mappin"
        case "operations": return "gearshape.2"
        case "supply_chain": return "arrow.triangle.swap"
        case "suppliers": return "building.2"
        case "crm": return "person.crop.rectangle"
        case "catalog": return "list.bullet.rectangle"
        case "code": return "terminal"
        case "data": return "cylinder"
        case "external": return "arrow.up.right.square"
        default: return "wrench"
        }
    }
}

// MARK: - Custom Tools Section (User-Created Tools)

struct CustomToolsSection: View {
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
                    .font(DesignSystem.Typography.monoHeader)
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
                .background(DesignSystem.Colors.surfaceTertiary)
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

struct UserToolCard: View {
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
        .background(DesignSystem.Colors.surfaceTertiary)
        .sheet(isPresented: $showTestSheet) {
            testToolSheet
        }
    }

    private var testToolSheet: some View {
        VStack(spacing: 0) {
            // Header - Anthropic style
            HStack {
                Text("TEST")
                    .font(DesignSystem.Typography.monoHeader)
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
                        .font(DesignSystem.Typography.monoHeader)
                        .foregroundStyle(.tertiary)

                    TextEditor(text: $testInput)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(DesignSystem.Colors.surfaceTertiary)
                }

                // Result
                if let result = testResult {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OUTPUT")
                            .font(DesignSystem.Typography.monoHeader)
                            .foregroundStyle(.tertiary)

                        ScrollView {
                            Text(result)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 180)
                        .padding(10)
                        .background(DesignSystem.Colors.surfaceTertiary)
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

struct TriggersSection: View {
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
                    .font(DesignSystem.Typography.monoHeader)
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
                    .background(DesignSystem.Colors.surfaceTertiary)
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
                .background(DesignSystem.Colors.surfaceTertiary)
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

struct TriggerCard: View {
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
        .background(DesignSystem.Colors.surfaceTertiary)
    }
}
