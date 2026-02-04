import SwiftUI

// MARK: - Telemetry Colors (Professional OTEL-style palette)

enum TelemetryColors {
    // Status colors - muted but clear
    static let success = Color(red: 0.2, green: 0.7, blue: 0.4)      // Elegant green
    static let error = Color(red: 0.9, green: 0.3, blue: 0.3)        // Clear red
    static let warning = Color(red: 0.95, green: 0.7, blue: 0.2)     // Amber
    static let info = Color(red: 0.4, green: 0.6, blue: 0.9)         // Soft blue

    // Latency colors (p50/p95/p99 thresholds)
    static let latencyFast = Color(red: 0.2, green: 0.7, blue: 0.4)  // < 100ms
    static let latencyMedium = Color(red: 0.95, green: 0.7, blue: 0.2) // 100-500ms
    static let latencySlow = Color(red: 0.9, green: 0.3, blue: 0.3)  // > 500ms

    // Source colors
    static let sourceClaude = Color(red: 0.8, green: 0.5, blue: 0.2)  // Orange/brown
    static let sourceApp = Color(red: 0.4, green: 0.6, blue: 0.9)     // Blue
    static let sourceAPI = Color(red: 0.6, green: 0.4, blue: 0.8)     // Purple
    static let sourceEdge = Color(red: 0.2, green: 0.7, blue: 0.7)    // Teal

    // JSON syntax colors
    static let jsonKey = Color(red: 0.6, green: 0.4, blue: 0.8)       // Purple
    static let jsonString = Color(red: 0.2, green: 0.7, blue: 0.4)    // Green
    static let jsonNumber = Color(red: 0.4, green: 0.6, blue: 0.9)    // Blue
    static let jsonBool = Color(red: 0.9, green: 0.5, blue: 0.2)      // Orange

    static func forLatency(_ ms: Double?) -> Color {
        guard let ms = ms else { return .secondary }
        if ms < 100 { return latencyFast }
        if ms < 500 { return latencyMedium }
        return latencySlow
    }

    static func forSource(_ source: String) -> Color {
        switch source {
        case "claude_code": return sourceClaude
        case "swag_manager": return sourceApp
        case "api": return sourceAPI
        case "edge_function": return sourceEdge
        default: return .secondary
        }
    }

    static func forSeverity(_ severity: String) -> Color {
        switch severity {
        case "error", "critical": return error
        case "warning": return warning
        case "info": return info
        default: return success
        }
    }
}

// MARK: - Telemetry Panel (OTEL-style)
// Production-quality trace viewer inspired by Jaeger/Datadog

struct TelemetryPanel: View {
    @ObservedObject private var telemetry = TelemetryService.shared
    @State private var selectedSpan: TelemetrySpan?
    @State private var selectedTrace: Trace?
    var storeId: UUID?

    /// Live trace data that updates with realtime
    private var liveSelectedTrace: Trace? {
        guard let selected = selectedTrace else { return nil }
        return telemetry.recentTraces.first { $0.id == selected.id } ?? selected
    }

    var body: some View {
        // Observe both traces and update counter to ensure UI refreshes on realtime
        let _ = telemetry.recentTraces.count
        let _ = telemetry.updateCount

        return HSplitView {
            // Left: Trace list
            traceListView
                .frame(minWidth: 300, maxWidth: 400)

            // Right: Live operations for selected trace
            if let trace = liveSelectedTrace {
                operationsView(trace)
            } else {
                emptyState
            }
        }
        .task {
            await telemetry.fetchConfiguredAgents(storeId: storeId)
            await telemetry.fetchRecentTraces(storeId: storeId)
            telemetry.startRealtime(storeId: storeId)
        }
        .onDisappear {
            telemetry.stopRealtime()
        }
    }

    // MARK: - Trace List

    private var traceListView: some View {
        VStack(spacing: 0) {
            // Header with controls
            HStack(spacing: 8) {
                Text("TRACES")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)

                // Live indicator
                if telemetry.isLive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(TelemetryColors.success)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(TelemetryColors.success)
                    }
                }

                Spacer()

                // Time range picker
                Picker("", selection: $telemetry.timeRange) {
                    ForEach(TelemetryService.TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: telemetry.timeRange) { _, _ in
                    Task {
                        await telemetry.fetchRecentTraces(storeId: storeId)
                        await telemetry.fetchStats(storeId: storeId)
                    }
                }

                Button {
                    Task { await telemetry.fetchRecentTraces(storeId: storeId) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Stats bar
            if let stats = telemetry.stats {
                statsBar(stats)
                Divider()
            }

            // Filters
            filtersBar

            Divider()

            // Trace list
            if telemetry.isLoading && telemetry.recentTraces.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if telemetry.recentTraces.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No traces")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(telemetry.recentTraces, selection: $selectedTrace) { trace in
                    TraceRow(trace: trace, isSelected: selectedTrace?.id == trace.id)
                        .tag(trace)
                }
                .listStyle(.plain)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Stats Bar

    private func statsBar(_ stats: TelemetryStats) -> some View {
        HStack(spacing: 16) {
            statItem(label: "Traces", value: "\(stats.totalTraces)", color: .secondary)
            statItem(label: "Spans", value: "\(stats.totalSpans)", color: .secondary)
            statItem(label: "Errors", value: "\(stats.errors)", color: stats.errors > 0 ? TelemetryColors.error : .secondary)
            Spacer()
            statItem(label: "p50", value: formatMs(stats.p50Ms), color: TelemetryColors.forLatency(stats.p50Ms))
            statItem(label: "p95", value: formatMs(stats.p95Ms), color: TelemetryColors.forLatency(stats.p95Ms))
            statItem(label: "p99", value: formatMs(stats.p99Ms), color: TelemetryColors.forLatency(stats.p99Ms))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }

    private func formatMs(_ ms: Double?) -> String {
        guard let ms = ms else { return "-" }
        if ms < 1000 {
            return String(format: "%.0fms", ms)
        }
        return String(format: "%.2fs", ms / 1000)
    }

    // MARK: - Filters Bar

    private var filtersBar: some View {
        HStack(spacing: 8) {
            // Source filter
            Picker("Source", selection: $telemetry.sourceFilter) {
                Text("All Sources").tag(String?.none)
                Text("Claude Code").tag(String?("claude_code"))
                Text("SwagManager").tag(String?("swag_manager"))
                Text("API").tag(String?("api"))
                Text("Edge Fn").tag(String?("edge_function"))
            }
            .pickerStyle(.menu)
            .frame(width: 130)
            .onChange(of: telemetry.sourceFilter) { _, _ in
                Task { await telemetry.fetchRecentTraces(storeId: storeId) }
            }

            // Agent filter
            Picker("Agent", selection: $telemetry.agentFilter) {
                Text("All Agents").tag(String?.none)
                ForEach(telemetry.availableAgents, id: \.self) { agent in
                    Text(agent).tag(String?(agent))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            .onChange(of: telemetry.agentFilter) { _, _ in
                Task { await telemetry.fetchRecentTraces(storeId: storeId) }
            }

            // Errors only
            Toggle("Errors", isOn: $telemetry.onlyErrors)
                .toggleStyle(.checkbox)
                .onChange(of: telemetry.onlyErrors) { _, _ in
                    Task { await telemetry.fetchRecentTraces(storeId: storeId) }
                }

            Spacer()

            Text("\(telemetry.recentTraces.count) traces")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Operations View (live-updating)

    private func operationsView(_ trace: Trace) -> some View {
        VStack(spacing: 0) {
            // Trace header
            traceHeader(trace)

            Divider()

            // Waterfall timeline - animates when new spans arrive
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    timelineHeader(trace)

                    ForEach(trace.spans) { span in
                        SpanRow(
                            span: span,
                            traceStart: trace.startTime,
                            traceDuration: trace.duration ?? 1,
                            isSelected: selectedSpan?.id == span.id,
                            onSelect: { selectedSpan = span }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .padding()
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: trace.spans.map(\.id))
            }

            // Selected span detail
            if let span = selectedSpan {
                Divider()
                spanDetailView(span)
            }
        }
    }

    private func traceHeader(_ trace: Trace) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Simple status + summary line
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(trace.hasErrors ? "FAILED" : "SUCCESS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(trace.hasErrors ? TelemetryColors.error : TelemetryColors.success)

                Text("·")
                    .foregroundStyle(.quaternary)

                Text(trace.source.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text("·")
                    .foregroundStyle(.quaternary)

                Text(trace.startTime.formatted(date: .abbreviated, time: .standard))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Spacer()

                // Copy ID
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(trace.id, forType: .string)
                } label: {
                    Text("Copy ID")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Metrics row - clean table style
            HStack(spacing: 0) {
                metricCell(label: "Duration", value: trace.formattedDuration, highlight: (trace.duration ?? 0) > 0.5)
                Divider().frame(height: 32)
                metricCell(label: "Tools", value: "\(trace.toolCount)")
                Divider().frame(height: 32)
                metricCell(label: "Spans", value: "\(trace.spans.count)")
                if trace.hasErrors {
                    Divider().frame(height: 32)
                    metricCell(label: "Errors", value: "\(trace.errorCount)", isError: true)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func metricCell(label: String, value: String, highlight: Bool = false, isError: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundStyle(isError ? TelemetryColors.error : highlight ? TelemetryColors.warning : .primary)
        }
        .frame(minWidth: 70, alignment: .leading)
    }

    private func timelineHeader(_ trace: Trace) -> some View {
        HStack {
            Text("Operation")
                .frame(width: 200, alignment: .leading)

            // Time markers
            GeometryReader { geo in
                let duration = trace.duration ?? 1
                let markers = stride(from: 0.0, through: duration, by: max(duration / 4, 0.001))

                ZStack(alignment: .leading) {
                    ForEach(Array(markers.enumerated()), id: \.offset) { _, time in
                        let x = (time / duration) * geo.size.width
                        VStack {
                            Text(formatDuration(time))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .position(x: x, y: 8)
                    }
                }
            }
            .frame(height: 20)
        }
        .padding(.bottom, 4)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 {
            return "0ms"
        }
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        }
        return String(format: "%.2fs", seconds)
    }

    // MARK: - Span Detail View

    private func spanDetailView(_ span: TelemetrySpan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - minimal
            HStack {
                Text(span.isError ? "ERROR" : "OK")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(span.isError ? TelemetryColors.error : TelemetryColors.success)

                Text(span.toolName ?? span.action)
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))

                Spacer()

                Text(span.formattedDuration)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                    selectedSpan = nil
                } label: {
                    Text("Close")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Metadata - simple key: value pairs
                    VStack(alignment: .leading, spacing: 6) {
                        spanDetailRow("span_id", span.id.uuidString)
                        if let parentId = span.parentId {
                            spanDetailRow("parent_id", parentId.uuidString)
                        }
                        spanDetailRow("source", span.source)
                        spanDetailRow("severity", span.severity)
                        spanDetailRow("duration_ms", "\(span.durationMs ?? 0)")
                        spanDetailRow("timestamp", span.createdAt.formatted(date: .abbreviated, time: .standard))
                    }

                    // Error - if present
                    if let error = span.errorMessage {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ERROR")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(TelemetryColors.error)
                            Text(error)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(TelemetryColors.error)
                                .textSelection(.enabled)
                        }
                    }

                    // Attributes - if present
                    if let details = span.details, !details.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ATTRIBUTES")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            ExpandableJSON(details: details)
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 220)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func spanDetailRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("Select a trace")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("View the waterfall timeline and span details")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Live Span Row (streaming feed style)
// MARK: - Trace Row (Anthropic-style minimal)

private struct TraceRow: View {
    let trace: Trace
    let isSelected: Bool

    /// Generate a human-readable summary
    private var actionSummary: String {
        let tools = trace.spans.compactMap { $0.toolName }
        if tools.isEmpty { return "execution" }
        var counts: [String: Int] = [:]
        for tool in tools {
            let baseName = tool.components(separatedBy: ".").first ?? tool
            counts[baseName, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.prefix(2).map { item in
            item.key.replacingOccurrences(of: "_", with: " ")
        }.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 0) {
            // Status: simple 2-char indicator
            Text(trace.hasErrors ? "ERR" : "OK")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(trace.hasErrors ? TelemetryColors.error : TelemetryColors.success)
                .frame(width: 28, alignment: .leading)

            // Main content
            VStack(alignment: .leading, spacing: 2) {
                // Action summary
                Text(actionSummary)
                    .font(.system(.caption, weight: .medium))
                    .lineLimit(1)

                // Metadata line
                HStack(spacing: 6) {
                    Text(trace.source.replacingOccurrences(of: "_", with: " "))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text("\(trace.toolCount) calls")
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 10))
            }

            Spacer()

            // Right: duration and time (show most recent activity for live feel)
            VStack(alignment: .trailing, spacing: 2) {
                Text(trace.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(trace.duration.map { $0 * 1000 }.map { ms in
                        ms > 500 ? TelemetryColors.error : ms > 100 ? TelemetryColors.warning : Color.secondary
                    } ?? .secondary)

                // Show relative time for recent entries, absolute for older ones
                Text(trace.endTime ?? trace.startTime, style: .relative)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.primary.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Span Row (Anthropic-style minimal waterfall)

private struct SpanRow: View {
    let span: TelemetrySpan
    let traceStart: Date
    let traceDuration: TimeInterval
    let isSelected: Bool
    let onSelect: () -> Void

    private var spanStart: TimeInterval {
        span.createdAt.timeIntervalSince(traceStart)
    }

    private var spanDuration: TimeInterval {
        Double(span.durationMs ?? 0) / 1000.0
    }

    private var startPercent: CGFloat {
        guard traceDuration > 0 else { return 0 }
        return CGFloat(spanStart / traceDuration)
    }

    private var widthPercent: CGFloat {
        guard traceDuration > 0 else { return 0.01 }
        return max(0.01, CGFloat(spanDuration / traceDuration))
    }

    private var toolName: String {
        span.toolName ?? span.action
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                // Status indicator - minimal
                Text(span.isError ? "×" : "✓")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(span.isError ? TelemetryColors.error : TelemetryColors.success)
                    .frame(width: 20)

                // Tool name - monospace, no decoration
                Text(toolName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(span.isError ? TelemetryColors.error : .primary)
                    .lineLimit(1)
                    .frame(width: 160, alignment: .leading)

                // Waterfall bar - simple, no gradients
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        Rectangle()
                            .fill(Color.primary.opacity(0.04))

                        // Bar - solid color
                        Rectangle()
                            .fill(span.isError ? TelemetryColors.error : Color.primary.opacity(0.25))
                            .frame(width: max(2, geo.size.width * widthPercent))
                            .offset(x: geo.size.width * startPercent)
                    }
                }
                .frame(height: 16)

                // Duration - right aligned
                Text(span.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.primary.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expandable JSON (Anthropic-style minimal)

private struct ExpandableJSON: View {
    let details: [String: AnyCodable]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(details.keys.sorted()), id: \.self) { key in
                JSONRow(key: key, value: details[key]?.value, depth: 0)
            }
        }
        .font(.system(.caption, design: .monospaced))
    }
}

private struct JSONRow: View {
    let key: String
    let value: Any?
    let depth: Int
    @State private var isExpanded = false  // Collapsed by default

    private var isExpandable: Bool {
        value is [String: Any] || value is [Any]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // Indent
                Text(String(repeating: "  ", count: depth))

                // Key
                Text(key)
                    .foregroundStyle(.tertiary)
                Text(": ")
                    .foregroundStyle(.quaternary)

                // Value
                if isExpandable {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        if let dict = value as? [String: Any] {
                            Text(isExpanded ? "{...}" : "{ \(dict.count) }")
                                .foregroundStyle(.secondary)
                        } else if let arr = value as? [Any] {
                            Text(isExpanded ? "[...]" : "[ \(arr.count) ]")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    valueText(value)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, 1)

            // Expanded children
            if isExpanded {
                if let dict = value as? [String: Any] {
                    ForEach(Array(dict.keys.sorted()), id: \.self) { childKey in
                        JSONRow(key: childKey, value: dict[childKey], depth: depth + 1)
                    }
                } else if let arr = value as? [Any] {
                    ForEach(Array(arr.enumerated()), id: \.offset) { index, item in
                        JSONRow(key: "\(index)", value: item, depth: depth + 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func valueText(_ value: Any?) -> some View {
        if let str = value as? String {
            Text("\"\(str)\"")
                .foregroundStyle(TelemetryColors.jsonString)
        } else if let num = value as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                Text(num.boolValue ? "true" : "false")
                    .foregroundStyle(TelemetryColors.jsonBool)
            } else {
                Text("\(num)")
                    .foregroundStyle(TelemetryColors.jsonNumber)
            }
        } else if let bool = value as? Bool {
            Text(bool ? "true" : "false")
                .foregroundStyle(TelemetryColors.jsonBool)
        } else if let int = value as? Int {
            Text("\(int)")
                .foregroundStyle(TelemetryColors.jsonNumber)
        } else if let double = value as? Double {
            Text(String(format: "%.2f", double))
                .foregroundStyle(TelemetryColors.jsonNumber)
        } else if value == nil {
            Text("null")
                .foregroundStyle(.quaternary)
        } else {
            Text("\(String(describing: value))")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    TelemetryPanel()
        .frame(width: 900, height: 600)
}
