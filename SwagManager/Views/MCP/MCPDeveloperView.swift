import SwiftUI

// MARK: - MCP Developer Dashboard
// Single comprehensive view with all developer tools
// Inspired by: Anthropic Console, Postman, VS Code

struct MCPDeveloperView: View {
    let server: MCPServer
    @ObservedObject var store: EditorStore

    @StateObject private var monitor: MCPMonitor
    @StateObject private var testRunner = MCPTestRunner()

    @State private var testParameters: [String: String] = [:]
    @State private var selectedExecution: ExecutionDetail?
    @State private var showExportSheet = false
    @State private var showCodeSnippets = false
    @State private var timeRange: TimeRange = .last24Hours

    enum TimeRange: String, CaseIterable {
        case lastHour = "1H"
        case last24Hours = "24H"
        case last7Days = "7D"

        var mcpRange: MCPMonitoringView.TimeRange {
            switch self {
            case .lastHour: return .lastHour
            case .last24Hours: return .last24Hours
            case .last7Days: return .last7Days
            }
        }
    }

    init(server: MCPServer, store: EditorStore) {
        self.server = server
        self.store = store
        _monitor = StateObject(wrappedValue: MCPMonitor(serverName: server.name))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Modern header with actions
            modernHeader

            Divider()

            // Main content
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Quick stats bar
                    quickStatsBar

                    // Test executor
                    testExecutorSection

                    // Recent executions with copy options
                    recentExecutionsSection

                    // Error log with debugging
                    if !monitor.errors.isEmpty {
                        errorDebugSection
                    }
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.surfacePrimary)
        }
        .task {
            await monitor.loadStats(timeRange: timeRange.mcpRange)
        }
        .onChange(of: timeRange) { _, newValue in
            Task { await monitor.loadStats(timeRange: newValue.mcpRange) }
        }
        .sheet(item: $selectedExecution) { execution in
            ExecutionInspectorSheet(execution: execution)
        }
        .sheet(isPresented: $showCodeSnippets) {
            CodeSnippetsSheet(server: server)
        }
    }

    // MARK: - Modern Header

    @ViewBuilder
    private var modernHeader: some View {
        HStack(spacing: 16) {
            // Icon + Name
            HStack(spacing: 12) {
                ZStack {
                    Color.blue.opacity(0.1)
                    Image(systemName: "server.rack")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))

                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))

                    HStack(spacing: 6) {
                        Text(server.category)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        if monitor.stats.totalExecutions > 0 {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            healthBadge
                        }
                    }
                }
            }

            Spacer()

            // Time range picker
            Picker("", selection: $timeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            // Actions
            Menu {
                Button(action: { showCodeSnippets = true }) {
                    Label("Code Snippets", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Button(action: { copyAsCurl() }) {
                    Label("Copy as cURL", systemImage: "doc.on.doc")
                }

                Button(action: { exportExecutions() }) {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }

                Divider()

                Button(action: { Task { await monitor.refresh() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 32, height: 32)

            // Edit button
            Button(action: { /* Edit server */ }) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .padding(DesignSystem.Spacing.xs)
            .background(DesignSystem.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceSecondary)
        .background(DesignSystem.Materials.thin)
    }

    @ViewBuilder
    private var healthBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(healthColor)
                .frame(width: 6, height: 6)
            Text(healthStatus)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(healthColor)
        }
    }

    private var healthColor: Color {
        let rate = monitor.stats.successRate
        if rate >= 95 { return .green }
        if rate >= 80 { return .orange }
        return .red
    }

    private var healthStatus: String {
        let rate = monitor.stats.successRate
        if rate >= 95 { return "Healthy" }
        if rate >= 80 { return "Degraded" }
        return "Failing"
    }

    // MARK: - Quick Stats Bar

    @ViewBuilder
    private var quickStatsBar: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            GlassStatCard(
                title: "Executions",
                value: "\(monitor.stats.totalExecutions)",
                icon: "play.circle.fill",
                color: DesignSystem.Colors.blue
            )

            GlassStatCard(
                title: "Success",
                value: String(format: "%.0f%%", monitor.stats.successRate),
                icon: "checkmark.circle.fill",
                color: DesignSystem.Colors.green
            )

            GlassStatCard(
                title: "Avg Time",
                value: formatDuration(monitor.stats.avgResponseTime),
                icon: "clock.fill",
                color: DesignSystem.Colors.orange
            )

            GlassStatCard(
                title: "Errors",
                value: "\(monitor.errors.count)",
                icon: "exclamationmark.triangle.fill",
                color: DesignSystem.Colors.error
            )
        }
    }

    // MARK: - Test Executor

    @ViewBuilder
    private var testExecutorSection: some View {
        GlassSection(
            title: "Test Execution",
            icon: "play.circle"
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Spacer()

                    Button("Run Test") {
                        Task {
                            await testRunner.execute(server: server, parameters: testParameters)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(testRunner.isRunning)
                }

                if let result = testRunner.lastResult {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text(result.success ? "Success" : "Failed")
                                .font(DesignSystem.Typography.caption1)
                                .fontWeight(.semibold)
                                .foregroundStyle(result.success ? DesignSystem.Colors.success : DesignSystem.Colors.error)

                            if let duration = result.duration {
                                Text("• \(formatDuration(duration * 1000))")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }

                            Spacer()

                            Button(action: { copyToClipboard(result.output) }) {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(DesignSystem.Typography.caption2)
                            }
                            .buttonStyle(.plain)
                        }

                        ScrollView {
                            Text(result.output)
                                .font(DesignSystem.Typography.monoCaption)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(DesignSystem.Spacing.md)
                        }
                        .frame(height: 200)
                        .background(DesignSystem.Colors.surfaceTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    }
                }
            }
        }
    }

    // MARK: - Recent Executions

    @ViewBuilder
    private var recentExecutionsSection: some View {
        GlassSection(
            title: "Recent Executions",
            subtitle: "\(monitor.recentExecutions.count)",
            icon: "clock.arrow.circlepath"
        ) {
            if monitor.recentExecutions.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 1) {
                    ForEach(monitor.recentExecutions.prefix(10)) { execution in
                        DeveloperExecutionRow(execution: execution) {
                            // Load full details
                            loadExecutionDetails(execution)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Error Debug Section

    @ViewBuilder
    private var errorDebugSection: some View {
        GlassSection(
            title: "Recent Errors",
            icon: "ladybug.fill"
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Spacer()

                    Button("Copy All") {
                        let allErrors = monitor.errors.map { "[\($0.timestamp)] \($0.message)" }.joined(separator: "\n\n")
                        copyToClipboard(allErrors)
                    }
                    .buttonStyle(.plain)
                    .font(DesignSystem.Typography.caption2)
                }

                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(monitor.errors.prefix(5)) { error in
                        DeveloperErrorRow(error: error)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)

            Text("No executions yet")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - Helpers

    private func formatDuration(_ ms: Double) -> String {
        if ms < 1000 { return "\(Int(ms))ms" }
        return String(format: "%.1fs", ms / 1000.0)
    }

    private func copyAsCurl() {
        let curl = """
        curl -X POST 'https://uaednwpxursknmwdeejn.supabase.co/functions/v1/tools-gateway' \\
          -H 'Content-Type: application/json' \\
          -H 'apikey: YOUR_API_KEY' \\
          -d '{
            "operation": "\(server.name)",
            "parameters": {},
            "store_id": "YOUR_STORE_ID"
          }'
        """
        copyToClipboard(curl)
    }

    private func exportExecutions() {
        // TODO: Export to JSON/CSV
        showExportSheet = true
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func loadExecutionDetails(_ execution: ExecutionLog) {
        // TODO: Load full execution details
    }
}

// MARK: - Legacy QuickStat (DEPRECATED - Use GlassStatCard)
// Removed - now using GlassStatCard from UnifiedGlassComponents.swift

// MARK: - Developer Execution Row

struct DeveloperExecutionRow: View {
    let execution: ExecutionLog
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(execution.success ? Color.green : Color.red)
                    .frame(width: 6, height: 6)

                Text(timeAgo(execution.timestamp))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)

                if let duration = execution.duration {
                    Text(formatDuration(duration * 1000))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(durationColor(duration * 1000))
                        .frame(width: 60, alignment: .trailing)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86400))d ago"
    }

    private func formatDuration(_ ms: Double) -> String {
        if ms < 1000 { return "\(Int(ms))ms" }
        return String(format: "%.1fs", ms / 1000.0)
    }

    private func durationColor(_ ms: Double) -> Color {
        if ms < 100 { return .green }
        if ms < 1000 { return .blue }
        if ms < 3000 { return .orange }
        return .red
    }
}

// MARK: - Developer Error Row

struct DeveloperErrorRow: View {
    let error: ErrorLog

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(error.message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(timeAgo(error.timestamp))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { copyToClipboard(error.message) }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(6)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        return "\(Int(seconds / 3600))h ago"
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Execution Inspector Sheet

struct ExecutionInspectorSheet: View {
    let execution: ExecutionDetail
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Execution Inspector")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding(16)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Request
                    MCPInspectorSection(title: "Request", content: execution.prettyRequest)

                    // Response
                    MCPInspectorSection(title: "Response", content: execution.prettyResponse)
                }
                .padding(16)
            }
        }
        .frame(width: 600, height: 500)
    }
}

struct MCPInspectorSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { copyToClipboard(content) }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                Text(content)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(height: 150)
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Code Snippets Sheet

struct CodeSnippetsSheet: View {
    let server: MCPServer
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage: Language = .curl

    enum Language: String, CaseIterable {
        case curl = "cURL"
        case python = "Python"
        case typescript = "TypeScript"
        case swift = "Swift"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Code Snippets")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()

                Picker("", selection: $selectedLanguage) {
                    ForEach(Language.allCases, id: \.self) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                Button("Close") { dismiss() }
            }
            .padding(16)

            Divider()

            // Code
            ScrollView {
                Text(codeSnippet)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Color.black.opacity(0.05))

            // Copy button
            HStack {
                Spacer()
                Button(action: { copyToClipboard(codeSnippet) }) {
                    Label("Copy Code", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 600, height: 500)
    }

    private var codeSnippet: String {
        switch selectedLanguage {
        case .curl:
            return """
            curl -X POST 'https://uaednwpxursknmwdeejn.supabase.co/functions/v1/tools-gateway' \\
              -H 'Content-Type: application/json' \\
              -H 'apikey: YOUR_API_KEY' \\
              -d '{
                "operation": "\(server.name)",
                "parameters": {},
                "store_id": "YOUR_STORE_ID"
              }'
            """
        case .python:
            return """
            import requests

            response = requests.post(
                'https://uaednwpxursknmwdeejn.supabase.co/functions/v1/tools-gateway',
                headers={
                    'Content-Type': 'application/json',
                    'apikey': 'YOUR_API_KEY'
                },
                json={
                    'operation': '\(server.name)',
                    'parameters': {},
                    'store_id': 'YOUR_STORE_ID'
                }
            )

            print(response.json())
            """
        case .typescript:
            return """
            const response = await fetch(
              'https://uaednwpxursknmwdeejn.supabase.co/functions/v1/tools-gateway',
              {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  'apikey': 'YOUR_API_KEY'
                },
                body: JSON.stringify({
                  operation: '\(server.name)',
                  parameters: {},
                  store_id: 'YOUR_STORE_ID'
                })
              }
            );

            const data = await response.json();
            console.log(data);
            """
        case .swift:
            return """
            let url = URL(string: "https://uaednwpxursknmwdeejn.supabase.co/functions/v1/tools-gateway")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("YOUR_API_KEY", forHTTPHeaderField: "apikey")

            let body: [String: Any] = [
                "operation": "\(server.name)",
                "parameters": [:],
                "store_id": "YOUR_STORE_ID"
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: request)
            let result = try JSONDecoder().decode(Result.self, from: data)
            """
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
