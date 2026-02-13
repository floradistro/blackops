import SwiftUI

// MARK: - Telemetry Section (Minimal)

struct TelemetrySection: View {
    let storeId: UUID?
    @Environment(\.telemetryService) private var telemetry
    @State private var isExpanded = true
    @State private var showFullPanel = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header - compact
            HStack(spacing: DesignSystem.Spacing.sm - 2) {
                Text("TELEMETRY")
                    .font(DesignSystem.monoFont(9, weight: .semibold))
                    .foregroundStyle(.tertiary)

                if telemetry.isLive {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 5, height: 5)
                }

                Spacer()

                if let stats = telemetry.stats {
                    HStack(spacing: DesignSystem.Spacing.sm - 2) {
                        Text("\(stats.totalTraces)tr")
                            .font(DesignSystem.monoFont(9))
                            .foregroundStyle(.tertiary)
                        if stats.errors > 0 {
                            Text("\(stats.errors)err")
                                .font(DesignSystem.monoFont(9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    showFullPanel = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(DesignSystem.font(9))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(DesignSystem.font(9, weight: .semibold))
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
                    .font(DesignSystem.monoFont(10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if telemetry.recentTraces.isEmpty {
                Text("No traces")
                    .font(DesignSystem.monoFont(11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    HStack(spacing: DesignSystem.Spacing.xxs) {
                        ForEach(TelemetryService.TimeRange.allCases, id: \.self) { range in
                            Button {
                                telemetry.timeRange = range
                                Task { await telemetry.fetchRecentTraces(storeId: storeId) }
                            } label: {
                                Text(range.rawValue)
                                    .font(DesignSystem.monoFont(9, weight: .medium))
                                    .padding(.horizontal, DesignSystem.Spacing.xs + 1)
                                    .padding(.vertical, DesignSystem.Spacing.xxs + 1)
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
                                .font(DesignSystem.font(9))
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
        HStack(spacing: DesignSystem.Spacing.xs) {
            // Status + ID
            HStack(spacing: 3) {
                Text(trace.hasErrors ? "\u{00D7}" : "\u{2713}")
                    .font(DesignSystem.monoFont(9, weight: .medium))
                    .foregroundStyle(trace.hasErrors ? .secondary : .tertiary)

                Text(trace.id.prefix(6))
                    .font(DesignSystem.monoFont(9))
                    .foregroundStyle(.secondary)
            }

            // Tool count
            Text("\(trace.toolCount)t")
                .font(DesignSystem.monoFont(8))
                .foregroundStyle(.tertiary)

            Spacer()

            // Duration + time
            Text(trace.formattedDuration)
                .font(DesignSystem.monoFont(9))
                .foregroundStyle(.tertiary)

            Text(trace.startTime, style: .time)
                .font(DesignSystem.font(8))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm - 2)
        .padding(.vertical, DesignSystem.Spacing.xxs + 1)
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Server tools header
            HStack {
                Text("SERVER TOOLS")
                    .font(DesignSystem.Typography.monoHeader)
                    .foregroundStyle(.tertiary)
                Text("\(registryTools.count) available")
                    .font(DesignSystem.monoFont(10))
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
                .font(DesignSystem.font(10))
                Button("None") {
                    enabledTools = []
                    hasChanges = true
                }
                .buttonStyle(.link)
                .font(DesignSystem.font(10))
            }

            if let loadError {
                HStack(spacing: DesignSystem.Spacing.sm - 2) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Text(loadError)
                        .font(DesignSystem.monoFont(11))
                        .foregroundStyle(.secondary)
                }
                .padding(DesignSystem.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.surfaceTertiary)
            } else if isLoading {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ProgressView().controlSize(.small)
                    Text("Loading tools from registry...")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if registryTools.isEmpty {
                Text("No tools in registry")
                    .font(DesignSystem.monoFont(11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ForEach(toolsByCategoryCache, id: \.category) { categoryGroup in
                    DisclosureGroup {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: DesignSystem.Spacing.sm) {
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
                        .padding(DesignSystem.Spacing.sm)
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: categoryIcon(categoryGroup.category))
                                .foregroundStyle(.tertiary)
                                .frame(width: DesignSystem.Spacing.xl)
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
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.surfaceTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                }
            }

            // Local code tools -- only for global agents (Whale Code)
            if isGlobalAgent && !codeTools.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("LOCAL TOOLS")
                            .font(DesignSystem.Typography.monoHeader)
                            .foregroundStyle(.tertiary)
                        Text("\(codeTools.count) auto-loaded")
                            .font(DesignSystem.monoFont(10))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("managed by CLI")
                            .font(DesignSystem.monoFont(9))
                            .foregroundStyle(.quaternary)
                    }

                    DisclosureGroup {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: DesignSystem.Spacing.sm) {
                            ForEach(codeTools) { tool in
                                HStack(spacing: DesignSystem.Spacing.sm - 2) {
                                    Image(systemName: "terminal")
                                        .font(DesignSystem.font(9))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 14)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(tool.name)
                                            .font(DesignSystem.monoFont(11, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        Text(tool.description)
                                            .font(DesignSystem.monoFont(9))
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, DesignSystem.Spacing.sm - 2)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                            }
                        }
                        .padding(DesignSystem.Spacing.sm)
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "terminal")
                                .foregroundStyle(.tertiary)
                                .frame(width: DesignSystem.Spacing.xl)
                            Text("Code")
                                .font(.subheadline.weight(.medium))
                            Text("\(codeTools.count)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text("always on")
                                .font(DesignSystem.monoFont(9))
                                .foregroundStyle(.quaternary)
                        }
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.surfaceTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("CUSTOM TOOLS")
                    .font(DesignSystem.Typography.monoHeader)
                    .foregroundStyle(.tertiary)
                Text("\(tools.count)")
                    .font(DesignSystem.monoFont(10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Text("+ new")
                        .font(DesignSystem.monoFont(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if isLoading {
                Text("loading...")
                    .font(DesignSystem.monoFont(11))
                    .foregroundStyle(.tertiary)
            } else if tools.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("No tools defined")
                        .font(DesignSystem.monoFont(11))
                        .foregroundStyle(.secondary)
                    Text("Create tools for RPC, HTTP APIs, or SQL queries")
                        .font(DesignSystem.monoFont(10))
                        .foregroundStyle(.tertiary)
                    Button {
                        showCreateSheet = true
                    } label: {
                        Text("create first tool")
                            .font(DesignSystem.monoFont(10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.top, DesignSystem.Spacing.xs)
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.surfaceTertiary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: DesignSystem.Spacing.sm) {
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header row
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: tool.icon)
                    .font(.caption)
                    .foregroundStyle(tool.isActive ? .primary : .tertiary)
                    .frame(width: DesignSystem.Spacing.xl)

                VStack(alignment: .leading, spacing: 1) {
                    Text(tool.displayName)
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    Text(tool.name)
                        .font(DesignSystem.monoFont(10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Status indicators - minimal
                HStack(spacing: DesignSystem.Spacing.sm - 2) {
                    if tool.isTested {
                        Text("\u{2713}")
                            .font(DesignSystem.monoFont(10))
                            .foregroundStyle(.primary)
                    }
                    if tool.requiresApproval {
                        Text("!")
                            .font(DesignSystem.monoFont(10))
                            .foregroundStyle(.secondary)
                    }
                    Text(tool.executionType.rawValue.uppercased())
                        .font(DesignSystem.monoFont(9))
                        .foregroundStyle(.tertiary)
                }
            }

            // Description
            Text(tool.description)
                .font(DesignSystem.monoFont(11))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Divider()

            // Actions - minimal
            HStack(spacing: DesignSystem.Spacing.md) {
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
                        .font(DesignSystem.monoFont(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onEdit()
                } label: {
                    Text("edit")
                        .font(DesignSystem.monoFont(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    onDelete()
                } label: {
                    Text("delete")
                        .font(DesignSystem.monoFont(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
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
                    .font(DesignSystem.font(11))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.md + 2)

            Divider()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Input
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm - 2) {
                    Text("INPUT")
                        .font(DesignSystem.Typography.monoHeader)
                        .foregroundStyle(.tertiary)

                    TextEditor(text: $testInput)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .padding(DesignSystem.Spacing.sm + 2)
                        .background(DesignSystem.Colors.surfaceTertiary)
                }

                // Result
                if let result = testResult {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm - 2) {
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
                        .padding(DesignSystem.Spacing.sm + 2)
                        .background(DesignSystem.Colors.surfaceTertiary)
                    }
                }
            }
            .padding(DesignSystem.Spacing.xl)

            Divider()

            // Footer
            HStack {
                if isTesting {
                    Text("Running...")
                        .font(DesignSystem.monoFont(11))
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
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.md)
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("TRIGGERS")
                    .font(DesignSystem.Typography.monoHeader)
                    .foregroundStyle(.tertiary)
                Text("\(triggers.count)")
                    .font(DesignSystem.monoFont(10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Text("+ new")
                        .font(DesignSystem.monoFont(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(tools.isEmpty)
            }

            if isLoading {
                Text("loading...")
                    .font(DesignSystem.monoFont(11))
                    .foregroundStyle(.tertiary)
            } else if tools.isEmpty {
                Text("Create a tool first to add triggers")
                    .font(DesignSystem.monoFont(11))
                    .foregroundStyle(.tertiary)
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.Colors.surfaceTertiary)
            } else if triggers.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("No triggers defined")
                        .font(DesignSystem.monoFont(11))
                        .foregroundStyle(.secondary)
                    Text("Triggers run tools on events, schedules, or conditions")
                        .font(DesignSystem.monoFont(10))
                        .foregroundStyle(.tertiary)
                    Button {
                        showCreateSheet = true
                    } label: {
                        Text("create first trigger")
                            .font(DesignSystem.monoFont(10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.top, DesignSystem.Spacing.xs)
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.surfaceTertiary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: DesignSystem.Spacing.sm) {
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header row
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: trigger.triggerType.icon)
                    .font(.caption)
                    .foregroundStyle(trigger.isActive ? .primary : .tertiary)
                    .frame(width: DesignSystem.Spacing.xl)

                VStack(alignment: .leading, spacing: 1) {
                    Text(trigger.name)
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    if let tool = tool {
                        Text("\u{2192} \(tool.displayName)")
                            .font(DesignSystem.monoFont(10))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Text(trigger.triggerType.displayName.uppercased())
                    .font(DesignSystem.monoFont(9))
                    .foregroundStyle(.tertiary)
            }

            // Description
            if let description = trigger.description {
                Text(description)
                    .font(DesignSystem.monoFont(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Event details - minimal
            if trigger.triggerType == .event {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if let table = trigger.eventTable {
                        Text(table)
                            .font(DesignSystem.monoFont(10))
                            .foregroundStyle(.secondary)
                    }
                    if let op = trigger.eventOperation {
                        Text(op.displayName.uppercased())
                            .font(DesignSystem.monoFont(9))
                            .foregroundStyle(.tertiary)
                    }
                }
            } else if trigger.triggerType == .schedule, let cron = trigger.cronExpression {
                Text(cron)
                    .font(DesignSystem.monoFont(10))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Actions - minimal
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    onFire()
                } label: {
                    Text("fire")
                        .font(DesignSystem.monoFont(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onEdit()
                } label: {
                    Text("edit")
                        .font(DesignSystem.monoFont(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    onDelete()
                } label: {
                    Text("delete")
                        .font(DesignSystem.monoFont(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceTertiary)
    }
}
