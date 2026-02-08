import SwiftUI

private typealias TC = DesignSystem.Colors.Telemetry

// MARK: - Telemetry Panel (OTEL-style)
// Production-quality trace viewer inspired by Jaeger/Datadog

struct TelemetryPanel: View {
    @ObservedObject private var telemetry = TelemetryService.shared
    @Environment(\.toolbarState) private var toolbarState
    @State private var selectedSpan: TelemetrySpan?
    @State private var selectedSessionId: String?  // Track by ID, not value
    @State private var expandedTraceId: String?  // Which trace within a session is expanded
    @State private var previousTraceCount: Int = 0  // Track to detect new turns
    @State private var previousSpanCount: Int = 0  // Track to detect new spans within a turn
    @State private var autoFollow: Bool = true  // Auto-follow latest turn when live
    @State private var newSpanIds: Set<UUID> = []  // Spans that just appeared (for entrance animation)
    @State private var spanDetailHeight: CGFloat = 280  // Resizable bottom detail
    @State private var pinnedSpan: TelemetrySpan?  // Pinned span in side panel
    var storeId: UUID?

    /// Binding that maps selectedSessionId to/from TelemetrySession for List selection
    private var selectedSession: Binding<TelemetrySession?> {
        Binding(
            get: {
                guard let id = selectedSessionId else { return nil }
                return telemetry.recentSessions.first { $0.id == id }
            },
            set: { newSession in
                selectedSessionId = newSession?.id
            }
        )
    }

    /// Live session data that updates with realtime - always reads from latest array
    private var liveSelectedSession: TelemetrySession? {
        guard let id = selectedSessionId else { return nil }
        return telemetry.recentSessions.first { $0.id == id }
    }

    var body: some View {
        // Force body re-evaluation on any realtime update
        let _ = telemetry.updateCount
        let _ = telemetry.recentSessions

        return HSplitView {
            // Left: Session list
            traceListView
                .frame(minWidth: 240, idealWidth: 320, maxWidth: 420)

            // Center: Live operations for selected session
            if let session = liveSelectedSession {
                sessionDetailView(session)
                    .frame(minWidth: 300)
            } else {
                emptyState
                    .frame(minWidth: 300)
            }

            // Right: Pinned span panel (optional 3rd column)
            if let span = pinnedSpan {
                pinnedSpanPanel(span)
                    .frame(minWidth: 260, idealWidth: 360, maxWidth: 480)
            }
        }
        .task(id: storeId) {
            FreezeDebugger.printRunloopContext("TelemetryPanel.task START")

            // Stop previous realtime before switching stores
            telemetry.stopRealtime()

            // Wire toolbar state
            toolbarState.telemetryStoreId = storeId
            toolbarState.telemetryTimeRange = telemetry.timeRange
            toolbarState.telemetryRefreshAction = {
                telemetry.timeRange = toolbarState.telemetryTimeRange
                await telemetry.fetchRecentTraces(storeId: storeId)
                await telemetry.fetchStats(storeId: storeId)
            }

            FreezeDebugger.telemetryEvent("fetchConfiguredAgents")
            await telemetry.fetchConfiguredAgents(storeId: storeId)

            FreezeDebugger.telemetryEvent("fetchRecentTraces")
            await telemetry.fetchRecentTraces(storeId: storeId)

            FreezeDebugger.telemetryEvent("startRealtime")
            telemetry.startRealtime(storeId: storeId)

            FreezeDebugger.printRunloopContext("TelemetryPanel.task END")
        }
        .onDisappear {
            FreezeDebugger.telemetryEvent("stopRealtime (onDisappear)")
            telemetry.stopRealtime()
            toolbarState.reset()
        }
        .onChange(of: telemetry.isLive) { _, newValue in
            toolbarState.telemetryIsLive = newValue
        }
        .freezeDebugLifecycle("TelemetryPanel")
    }

    // MARK: - Trace List

    private var traceListView: some View {
        VStack(spacing: 0) {
            // Time range + live + refresh
            timeRangeBar
            Divider()

            // Stats bar
            if let stats = telemetry.stats {
                statsBar(stats)
                Divider()
            }

            // Filters
            filtersBar

            Divider()

            // Session list
            if telemetry.isLoading && telemetry.recentSessions.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if telemetry.recentSessions.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No sessions")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List(telemetry.recentSessions, selection: selectedSession) { session in
                        SessionRow(session: session, isSelected: selectedSessionId == session.id, isLive: isSessionLive(session))
                            .tag(session)
                            // Composite id forces re-render when data changes
                            .id("\(session.id)-\(session.traces.count)-\(session.allSpans.count)")
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .background(VibrancyBackground())
    }

    // MARK: - Time Range Bar (inline)

    private var timeRangeBar: some View {
        HStack(spacing: 6) {
            // Time range pills
            HStack(spacing: 1) {
                ForEach(TelemetryService.TimeRange.allCases, id: \.self) { range in
                    Button {
                        toolbarState.telemetryTimeRange = range
                        Task {
                            await toolbarState.telemetryRefreshAction?()
                        }
                    } label: {
                        Text(range.rawValue)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                toolbarState.telemetryTimeRange == range
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.primary.opacity(0.04)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Live indicator
            if toolbarState.telemetryIsLive {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                    Text("LIVE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            // Refresh
            Button {
                Task { await toolbarState.telemetryRefreshAction?() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh telemetry")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func statsBar(_ stats: TelemetryStats) -> some View {
        HStack(spacing: 10) {
            // Left: counts - inline
            HStack(spacing: 8) {
                statItem(label: "tr", value: "\(stats.totalTraces)")
                statItem(label: "sp", value: "\(stats.totalSpans)")
                if stats.errors > 0 {
                    statItem(label: "err", value: "\(stats.errors)", color: TC.error)
                }
            }

            Spacer()

            // Right: latency percentiles - inline
            HStack(spacing: 8) {
                statItem(label: "p50", value: formatMs(stats.p50Ms), color: TC.forLatency(stats.p50Ms))
                statItem(label: "p95", value: formatMs(stats.p95Ms), color: TC.forLatency(stats.p95Ms))
                statItem(label: "p99", value: formatMs(stats.p99Ms), color: TC.forLatency(stats.p99Ms))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private func statItem(label: String, value: String, color: Color = .secondary) -> some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.quaternary)
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
        HStack(spacing: 6) {
            // Compact source picker
            Menu {
                Button("All") { telemetry.sourceFilter = nil }
                Divider()
                Button("Claude") { telemetry.sourceFilter = "claude_code" }
                Button("App") { telemetry.sourceFilter = "swag_manager" }
                Button("API") { telemetry.sourceFilter = "api" }
                Button("Edge") { telemetry.sourceFilter = "edge_function" }
            } label: {
                HStack(spacing: 3) {
                    Text(telemetry.sourceFilter?.components(separatedBy: "_").first?.prefix(4).uppercased() ?? "SRC")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(telemetry.sourceFilter != nil ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
            }
            .buttonStyle(.plain)
            .onChange(of: telemetry.sourceFilter) { _, _ in
                Task { await telemetry.fetchRecentTraces(storeId: storeId) }
            }

            // Compact agent picker
            if !telemetry.availableAgents.isEmpty {
                Menu {
                    Button("All") { telemetry.agentFilter = nil }
                    Divider()
                    ForEach(telemetry.availableAgents, id: \.self) { agent in
                        Button(agent) { telemetry.agentFilter = agent }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(telemetry.agentFilter?.prefix(6).uppercased() ?? "AGENT")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(telemetry.agentFilter != nil ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                }
                .buttonStyle(.plain)
                .onChange(of: telemetry.agentFilter) { _, _ in
                    Task { await telemetry.fetchRecentTraces(storeId: storeId) }
                }
            }

            // Compact errors toggle
            Button {
                telemetry.onlyErrors.toggle()
                Task { await telemetry.fetchRecentTraces(storeId: storeId) }
            } label: {
                Text("ERR")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(telemetry.onlyErrors ? Color.red.opacity(0.15) : Color.primary.opacity(0.04))
                    .foregroundStyle(telemetry.onlyErrors ? TC.error : .secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(telemetry.recentSessions.count)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    // MARK: - Session Detail View (shows all traces in a session)

    /// Whether the selected session is currently receiving live data
    private var isSelectedSessionLive: Bool {
        guard let session = liveSelectedSession else { return false }
        return isSessionLive(session)
    }

    /// Check if a trace just arrived (latest trace in a live session)
    private func isTraceLive(_ trace: Trace, in session: TelemetrySession) -> Bool {
        guard isSessionLive(session) else { return false }
        guard let endTime = trace.endTime else { return true }
        return Date().timeIntervalSince(endTime) < 10
    }

    /// Check if a span is freshly arrived (for entrance animation)
    private func isSpanNew(_ span: TelemetrySpan) -> Bool {
        newSpanIds.contains(span.id)
    }

    private func sessionDetailView(_ session: TelemetrySession) -> some View {
        VStack(spacing: 0) {
            sessionHeader(session)

            Divider()

            // Auto-follow bar (shown when session is live)
            if isSelectedSessionLive {
                HStack(spacing: 6) {
                    Circle()
                        .fill(TC.success)
                        .frame(width: 6, height: 6)
                        .modifier(PulseModifier())

                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(TC.success)

                    Text("·")
                        .foregroundStyle(.quaternary)

                    Text("Auto-following latest turn")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        autoFollow.toggle()
                    } label: {
                        Text(autoFollow ? "FOLLOWING" : "PAUSED")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(autoFollow ? TC.success.opacity(0.15) : Color.primary.opacity(0.05))
                            .foregroundStyle(autoFollow ? TC.success : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(TC.success.opacity(0.04))

                Divider()
            }

            // Trace waterfall + resizable span detail
            GeometryReader { geometry in
                let totalHeight = geometry.size.height
                let hasSpanDetail = selectedSpan != nil
                let clampedDetailHeight = hasSpanDetail ? min(max(spanDetailHeight, 150), min(500, totalHeight * 0.7)) : 0
                let scrollHeight = hasSpanDetail ? totalHeight - clampedDetailHeight : totalHeight

                VStack(spacing: 0) {
                    // All traces in this session, each with expandable spans
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(session.traces.enumerated()), id: \.element.id) { index, trace in
                                    let isLastTrace = index == session.traces.count - 1
                                    let isLive = isTraceLive(trace, in: session)

                                    VStack(alignment: .leading, spacing: 0) {
                                        // Trace header row (clickable to expand/collapse)
                                        Button {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                if expandedTraceId == trace.id {
                                                    expandedTraceId = nil
                                                } else {
                                                    expandedTraceId = trace.id
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: expandedTraceId == trace.id ? "chevron.down" : "chevron.right")
                                                    .font(.system(size: 9, weight: .semibold))
                                                    .foregroundStyle(.tertiary)
                                                    .frame(width: 12)
                                                    .rotationEffect(expandedTraceId == trace.id ? .zero : .degrees(-0))

                                                // Live dot for active trace
                                                if isLive {
                                                    Circle()
                                                        .fill(TC.success)
                                                        .frame(width: 5, height: 5)
                                                        .modifier(PulseModifier())
                                                }

                                                Text("Turn \(index + 1)")
                                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))

                                                if !isLive {
                                                    Text(trace.hasErrors ? "ERR" : "OK")
                                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                                        .foregroundStyle(trace.hasErrors ? TC.error : TC.success)
                                                }

                                                Text("·")
                                                    .foregroundStyle(.quaternary)

                                                // Tool summary
                                                let tools = trace.spans.compactMap { $0.toolName }
                                                let uniqueTools = Set(tools)
                                                Text("\(tools.count) calls (\(uniqueTools.prefix(3).joined(separator: ", ")))")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)

                                                Spacer()

                                                // AI telemetry inline
                                                if let cost = trace.formattedCost {
                                                    Text(cost)
                                                        .font(.system(size: 10, design: .monospaced))
                                                        .foregroundStyle(TC.warning)
                                                }

                                                Text(trace.formattedDuration)
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundStyle(.secondary)

                                                if !isLive {
                                                    Text(trace.startTime, style: .relative)
                                                        .font(.system(size: 10, design: .monospaced))
                                                        .foregroundStyle(.tertiary)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                expandedTraceId == trace.id
                                                    ? (isLive ? TC.success.opacity(0.04) : Color.primary.opacity(0.04))
                                                    : Color.clear
                                            )
                                        }
                                        .buttonStyle(.plain)

                                        // Expanded: show span waterfall
                                        if expandedTraceId == trace.id {
                                            VStack(alignment: .leading, spacing: 0) {
                                                timelineHeader(trace)
                                                    .padding(.horizontal, 16)

                                                ForEach(trace.spans) { span in
                                                    SpanRow(
                                                        span: span,
                                                        traceStart: trace.startTime,
                                                        traceDuration: trace.duration ?? 1,
                                                        isSelected: selectedSpan?.id == span.id,
                                                        isNew: isSpanNew(span),
                                                        onSelect: { selectedSpan = span }
                                                    )
                                                }
                                            }
                                            .padding(.bottom, 8)
                                            .background(isLive ? TC.success.opacity(0.02) : Color.primary.opacity(0.02))
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                        }

                                        if !isLastTrace {
                                            Divider().padding(.leading, 36)
                                        }
                                    }
                                    .id("trace-\(trace.id)")
                                }

                                // Scroll anchor at the bottom
                                Color.clear
                                    .frame(height: 1)
                                    .id("scroll-bottom")
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: expandedTraceId)
                            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: session.traces.count)
                        }
                        .frame(height: scrollHeight)
                        .onChange(of: session.traces.count) { oldCount, newCount in
                            guard autoFollow, newCount > oldCount else { return }
                            // New turn arrived — auto-expand it
                            if let lastTrace = session.traces.last {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    expandedTraceId = lastTrace.id
                                }
                                // Scroll to the new trace
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        scrollProxy.scrollTo("trace-\(lastTrace.id)", anchor: .top)
                                    }
                                }
                            }
                            previousTraceCount = newCount
                        }
                        .onChange(of: telemetry.updateCount) { _, _ in
                            // New span arrived in the current expanded trace — track it for animation
                            guard autoFollow, let session = liveSelectedSession else { return }
                            let currentSpanCount = session.allSpans.count
                            if currentSpanCount > previousSpanCount {
                                // Find new span IDs
                                let allIds = Set(session.allSpans.map { $0.id })
                                let newIds = allIds.subtracting(newSpanIds.isEmpty ? [] : newSpanIds)
                                if !newIds.isEmpty {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        newSpanIds.formUnion(newIds)
                                    }
                                    // Clear "new" status after entrance animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        newSpanIds.subtract(newIds)
                                    }
                                }
                                // Auto-scroll to bottom of expanded trace
                                if expandedTraceId != nil {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            scrollProxy.scrollTo("scroll-bottom", anchor: .bottom)
                                        }
                                    }
                                }
                            }
                            previousSpanCount = currentSpanCount
                        }
                    }

                    // Selected span detail with drag divider
                    if let span = selectedSpan {
                        DragDivider(offset: $spanDetailHeight, range: 150...min(500, totalHeight * 0.7))
                        spanDetailView(span)
                            .frame(height: clampedDetailHeight)
                    }
                }
            }
        }
        .background(VibrancyBackground())
        .onAppear {
            // Initialize counts for change detection
            if let session = liveSelectedSession {
                previousTraceCount = session.traces.count
                previousSpanCount = session.allSpans.count
            }
        }
    }

    private func sessionHeader(_ session: TelemetrySession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status + summary line
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(session.hasErrors ? "FAILED" : "SUCCESS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(session.hasErrors ? TC.error : TC.success)

                Text("·")
                    .foregroundStyle(.quaternary)

                Text(session.source.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if let agent = session.agentName {
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(agent)
                        .font(.system(size: 11))
                        .foregroundStyle(TC.sourceClaude)
                }

                Text("·")
                    .foregroundStyle(.quaternary)

                Text(session.startTime.formatted(date: .abbreviated, time: .standard))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Spacer()

                // Copy session ID
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(session.id, forType: .string)
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

            // Metrics row
            HStack(spacing: 0) {
                metricCell(label: "Duration", value: session.formattedDuration, highlight: (session.duration ?? 0) > 5)
                Divider().frame(height: 32)
                metricCell(label: "Turns", value: "\(session.turnCount)")
                Divider().frame(height: 32)
                metricCell(label: "Tools", value: "\(session.toolCount)")
                if session.hasErrors {
                    Divider().frame(height: 32)
                    metricCell(label: "Errors", value: "\(session.errorCount)", isError: true)
                }

                // AI Telemetry metrics
                if session.hasAITelemetry {
                    Divider().frame(height: 32)
                    if session.totalInputTokens > 0 {
                        metricCell(label: "Tokens", value: "\(session.totalInputTokens) → \(session.totalOutputTokens)", color: TC.info)
                    }
                    Divider().frame(height: 32)
                    if let cost = session.formattedCost {
                        metricCell(label: "Cost", value: cost, color: TC.warning)
                    }
                    if let model = session.shortModelName {
                        Divider().frame(height: 32)
                        metricCell(label: "Model", value: model, color: TC.sourceClaude)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func metricCell(label: String, value: String, highlight: Bool = false, isError: Bool = false, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(color ?? (isError ? TC.error : highlight ? TC.warning : .primary))
        }
        .padding(.trailing, 12)
        .frame(minWidth: 60, alignment: .leading)
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
            // Header with status + badges
            HStack(spacing: 8) {
                // Status
                Text(span.isError ? "ERROR" : "OK")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(span.isError ? TC.error : TC.success)

                // Error type badge
                if let errorType = span.errorType {
                    Text(errorType.uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(errorTypeBadgeColor(errorType))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(errorTypeBadgeColor(errorType).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                // Timeout badge
                if span.timedOut {
                    Text("TIMEOUT")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(TC.warning)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(TC.warning.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                // Retryable badge
                if span.retryable {
                    Text("RETRYABLE")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(TC.info)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(TC.info.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                Text(span.toolName ?? span.action)
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))

                Spacer()

                Text(span.formattedDuration)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                    pinnedSpan = span
                    selectedSpan = nil
                    telemetry.selectedSpanComparison = nil
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Open in side panel")

                Button {
                    selectedSpan = nil
                    telemetry.selectedSpanComparison = nil
                } label: {
                    Text("Close")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Performance comparison bar (tool spans only)
            if let comparison = telemetry.selectedSpanComparison {
                spanComparisonBar(span, comparison: comparison)
            }

            Divider()

            ScrollView {
                spanDetailContent(span)
                    .padding(16)
            }
        }
        .background(VibrancyBackground())
        .task(id: span.id) {
            if span.isToolSpan {
                await telemetry.fetchSpanComparison(spanId: span.id)
            }
        }
    }

    // MARK: - Span Detail Content (shared between inline and pinned)

    @ViewBuilder
    private func spanDetailContent(_ span: TelemetrySpan) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Core metadata ──
            VStack(alignment: .leading, spacing: 6) {
                spanDetailRow("span_id", span.id.uuidString)
                if let parentId = span.parentId {
                    spanDetailRow("parent_id", parentId.uuidString)
                }
                spanDetailRow("source", span.source)
                spanDetailRow("severity", span.severity)
                spanDetailRow("duration_ms", "\(span.durationMs ?? 0)")
                spanDetailRow("timestamp", span.createdAt.formatted(date: .abbreviated, time: .standard))

                // OTEL context
                if let traceId = span.otelTraceId {
                    spanDetailRow("trace_id", traceId)
                }
                if let spanId = span.otelSpanId {
                    spanDetailRow("w3c_span_id", spanId)
                }
                if let kind = span.otelSpanKind {
                    spanDetailRow("span_kind", kind)
                }
                if let service = span.otelServiceName {
                    spanDetailRow("service", service)
                }
            }

            // ── AI Telemetry (API request spans) ──
            if span.isApiRequest {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("AI TELEMETRY")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    if let model = span.model {
                        spanDetailRow("model", model)
                    }
                    if let tokens = span.formattedTokens {
                        spanDetailRow("tokens", tokens)
                    }
                    if let input = span.inputTokens {
                        spanDetailRow("input_tokens", "\(input)")
                    }
                    if let output = span.outputTokens {
                        spanDetailRow("output_tokens", "\(output)")
                    }
                    if let cacheRead = span.cacheReadTokens, cacheRead > 0 {
                        spanDetailRow("cache_read", "\(cacheRead)")
                    }
                    if let cacheCreate = span.cacheCreationTokens, cacheCreate > 0 {
                        spanDetailRow("cache_create", "\(cacheCreate)")
                    }
                    if let cost = span.formattedCost {
                        spanDetailRow("cost", cost)
                    }
                    if let turn = span.turnNumber {
                        spanDetailRow("turn", "\(turn)")
                    }
                    if let stop = span.stopReason {
                        spanDetailRow("stop_reason", stop)
                    }
                }
            }

            // ── Tool Input (tool spans only) ──
            if span.isToolSpan, let input = span.toolInput, !input.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("TOOL INPUT")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        if let bytes = span.inputBytes {
                            Text("\(bytes)B")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.quaternary)
                        }
                        Button {
                            let json = (try? JSONSerialization.data(withJSONObject: input, options: .prettyPrinted))
                                .flatMap { String(data: $0, encoding: .utf8) } ?? "\(input)"
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(json, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(Array(input.keys.sorted()), id: \.self) { key in
                        HStack(alignment: .top, spacing: 8) {
                            Text(key)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(TC.jsonKey)
                                .frame(width: 80, alignment: .trailing)
                            formattedValue(input[key])
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            // ── Tool Output (tool spans only) ──
            if span.isToolSpan {
                if let error = span.toolError {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOOL OUTPUT")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text(error)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(TC.error)
                            .textSelection(.enabled)
                    }
                } else if let result = span.toolResult {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("TOOL OUTPUT")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            if let bytes = span.outputBytes {
                                Text("\(bytes)B")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.quaternary)
                            }
                            Button {
                                let str: String
                                if let dict = result as? [String: Any] {
                                    str = (try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted))
                                        .flatMap { String(data: $0, encoding: .utf8) } ?? "\(dict)"
                                } else { str = "\(result)" }
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(str, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        if let dict = result as? [String: Any] {
                            ForEach(Array(dict.keys.sorted().prefix(20)), id: \.self) { key in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(key)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(TC.jsonKey)
                                        .frame(width: 80, alignment: .trailing)
                                    formattedValue(dict[key])
                                        .textSelection(.enabled)
                                }
                            }
                        } else if let str = result as? String {
                            Text(str.prefix(500))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }

                // Marginal cost for tool spans
                if let cost = span.formattedMarginalCost {
                    spanDetailRow("turn_cost", cost)
                }
                if let payload = span.formattedPayloadSize {
                    spanDetailRow("payload", payload)
                }
            }

            // ── Error detail ──
            if let error = span.errorMessage {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("ERROR")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(TC.error)
                    Text(error)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(TC.error)
                        .textSelection(.enabled)
                }
            }

            // ── Raw attributes ──
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
    }

    // MARK: - Span Comparison Bar

    private func spanComparisonBar(_ span: TelemetrySpan, comparison: SpanComparison) -> some View {
        HStack(spacing: 12) {
            // Percentile rank
            HStack(spacing: 4) {
                Image(systemName: comparison.isSlow ? "exclamationmark.triangle.fill" : "gauge.with.dots.needle.33percent")
                    .font(.system(size: 10))
                    .foregroundStyle(comparison.isSlow ? TC.error : TC.success)
                Text("P\(Int(comparison.percentileRank))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(comparison.isSlow ? TC.error : .primary)
            }

            Divider().frame(height: 14)

            // Avg comparison
            HStack(spacing: 4) {
                Text("avg")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(formatMs(comparison.avgMs))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // P95 comparison
            HStack(spacing: 4) {
                Text("p95")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(formatMs(comparison.p95Ms))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 14)

            // Error rate
            HStack(spacing: 4) {
                Text("err")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(String(format: "%.1f%%", comparison.errorRate))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(comparison.errorRate > 5 ? TC.error : .secondary)
            }

            // 24h volume
            HStack(spacing: 4) {
                Text("24h")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text("\(comparison.totalCalls24h)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if comparison.isSlow {
                Text("SLOW")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(TC.error)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(TC.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(comparison.isSlow ? TC.error.opacity(0.04) : Color.primary.opacity(0.02))
    }

    // MARK: - Span Detail Helpers

    private func spanDetailRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func formattedValue(_ value: Any?) -> some View {
        if let str = value as? String {
            Text(str)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(TC.jsonString)
        } else if let num = value as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                Text(num.boolValue ? "true" : "false")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TC.jsonBool)
            } else {
                Text("\(num)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TC.jsonNumber)
            }
        } else if let bool = value as? Bool {
            Text(bool ? "true" : "false")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(TC.jsonBool)
        } else if let int = value as? Int {
            Text("\(int)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(TC.jsonNumber)
        } else if let double = value as? Double {
            Text(String(format: "%.2f", double))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(TC.jsonNumber)
        } else if let dict = value as? [String: Any] {
            Text("{\(dict.count) keys}")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        } else if let arr = value as? [Any] {
            Text("[\(arr.count) items]")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        } else if value == nil {
            Text("null")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.quaternary)
        } else {
            Text("\(String(describing: value))")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func errorTypeBadgeColor(_ type: String) -> Color {
        switch type {
        case "rate_limit": return TC.warning
        case "auth": return Color(red: 0.8, green: 0.3, blue: 0.3)
        case "validation": return TC.info
        case "not_found": return .secondary
        case "recoverable": return TC.warning
        case "permanent": return TC.error
        default: return .secondary
        }
    }

    // MARK: - Helpers

    /// Check if a session received data in the last 30 seconds (still active)
    private func isSessionLive(_ session: TelemetrySession) -> Bool {
        guard let endTime = session.endTime else { return false }
        return Date().timeIntervalSince(endTime) < 30
    }

    // MARK: - Pinned Span Panel (full-height 3rd column)

    private func pinnedSpanPanel(_ span: TelemetrySpan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (top padding for title bar clearance)
            HStack(spacing: 8) {
                Text(span.isError ? "ERROR" : "OK")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(span.isError ? TC.error : TC.success)

                Text(span.toolName ?? span.action)
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))

                Spacer()

                Text(span.formattedDuration)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                    pinnedSpan = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Comparison bar
            if let comparison = telemetry.selectedSpanComparison {
                spanComparisonBar(span, comparison: comparison)
            }

            Divider()

            // Full scrollable detail (reuses spanDetailContent)
            ScrollView {
                spanDetailContent(span)
                    .padding(16)
            }
        }
        .background(VibrancyBackground())
        .task(id: span.id) {
            if span.isToolSpan {
                await telemetry.fetchSpanComparison(spanId: span.id)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView("Select a Session", systemImage: "point.3.connected.trianglepath.dotted", description: Text("View traces and spans"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VibrancyBackground())
    }
}

// MARK: - Drag Divider

private struct DragDivider: View {
    @Binding var offset: CGFloat
    let range: ClosedRange<CGFloat>
    @State private var isHovering = false

    var body: some View {
        ZStack {
            // Visible line
            Rectangle()
                .fill(Color.primary.opacity(isHovering ? 0.15 : 0.08))
                .frame(height: 1)

            // Grip indicator
            Capsule()
                .fill(Color.primary.opacity(isHovering ? 0.3 : 0.15))
                .frame(width: 36, height: 4)
        }
        .frame(height: 6)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Dragging up = larger bottom panel (inverted)
                    let newHeight = offset - value.translation.height
                    offset = min(max(newHeight, range.lowerBound), range.upperBound)
                }
        )
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    TelemetryPanel()
        .frame(width: 900, height: 600)
}
