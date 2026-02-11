import SwiftUI

private typealias TC = DesignSystem.Colors.Telemetry

// MARK: - Telemetry Panel (OTEL-style)
// Production-quality trace viewer inspired by Jaeger/Datadog

struct TelemetryPanel: View {
    @Environment(\.telemetryService) private var telemetry
    @Environment(\.toolbarState) private var toolbarState
    @State private var selectedSessionId: String?  // Track by ID, not value
    @State private var expandedTraceIds: Set<String> = []  // Which traces are expanded
    @State private var expandAll: Bool = false  // Expand all traces toggle
    @State private var previousTraceCount: Int = 0  // Track to detect new turns
    @State private var previousSessionCount: Int = 0  // Track to detect new sessions
    @State private var autoFollow: Bool = true  // Auto-follow latest turn when live
    @State private var autoFollowSessions: Bool = true  // Auto-scroll to new sessions in list
    @State private var newSessionIds: Set<String> = []  // Sessions that just appeared (for entrance animation)
    @State private var pinnedSpan: TelemetrySpan?  // Pinned span in inspector panel
    @State private var expandedChildAgentIds: Set<String> = []    // Which child agents show traces in center panel
    @State private var expandedChildTraceIds: Set<String> = []    // Which child agent traces show spans
    @State private var autoExpandedTeamSections: Set<String> = [] // One-shot guard for auto-expand
    var storeId: UUID?

    /// Binding that maps selectedSessionId to/from TelemetrySession for List selection
    private var selectedSession: Binding<TelemetrySession?> {
        Binding(
            get: {
                guard let id = selectedSessionId else { return nil }
                return findSession(id: id)
            },
            set: { newSession in
                selectedSessionId = newSession?.id
            }
        )
    }

    /// Live session data that updates with realtime - always reads from latest array
    /// Searches both parent sessions and child sessions (teammates)
    private var liveSelectedSession: TelemetrySession? {
        guard let id = selectedSessionId else { return nil }
        return findSession(id: id)
    }

    /// Find a session by ID, searching 3 levels deep (root → coordinator → teammate)
    private func findSession(id: String) -> TelemetrySession? {
        // Level 1: top-level sessions (roots / swarm groups)
        if let session = telemetry.recentSessions.first(where: { $0.id == id }) {
            return session
        }
        // Level 2: child sessions (coordinators / teammates)
        for parent in telemetry.recentSessions {
            if let child = parent.childSessions.first(where: { $0.id == id }) {
                return child
            }
            // Level 3: grandchild sessions (teammates under coordinators)
            for child in parent.childSessions {
                if let grandchild = child.childSessions.first(where: { $0.id == id }) {
                    return grandchild
                }
            }
        }
        return nil
    }

    var body: some View {
        HSplitView {
            // Left: Session list (compact, scales down for narrow windows)
            traceListView
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 400)

            // Center: Live operations (main content, gets most space)
            Group {
                if let session = liveSelectedSession {
                    sessionDetailView(session)
                        .id(session.id)
                        .transition(.opacity)
                } else {
                    emptyState
                        .transition(.opacity)
                }
            }
            .frame(minWidth: 320, idealWidth: 600)
            .animation(.easeInOut(duration: 0.25), value: selectedSessionId)

            // Right: Pinned span panel (optional inspector, moderate priority)
            if let span = pinnedSpan {
                PinnedSpanPanel(
                    span: span,
                    pinnedSpan: $pinnedSpan,
                    comparison: telemetry.selectedSpanComparison
                )
                .frame(minWidth: 280, idealWidth: 380, maxWidth: 600)
                .transition(.opacity)
            }
        }
        .focusable()
        .onKeyPress(.escape) {
            if pinnedSpan != nil {
                withAnimation(.easeOut(duration: 0.2)) { pinnedSpan = nil }
                return .handled
            }
            return .ignored
        }
        .task(id: storeId) {
            FreezeDebugger.printRunloopContext("TelemetryPanel.task START")

            // Configure service (idempotent, survives view lifecycle cancellation)
            telemetry.configure(storeId: storeId)

            // Wire toolbar state
            toolbarState.telemetryStoreId = storeId
            toolbarState.telemetryTimeRange = telemetry.timeRange
            toolbarState.telemetryRefreshAction = {
                telemetry.timeRange = toolbarState.telemetryTimeRange
                await telemetry.fetchRecentTraces(storeId: storeId)
                await telemetry.fetchStats(storeId: storeId)
            }

            FreezeDebugger.printRunloopContext("TelemetryPanel.task END")
        }
        .onDisappear {
            // Don't stop realtime — service manages its own lifecycle
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
                Divider()
            }

            // Live cost tracker
            liveCostBar
            Divider()

            // Filters
            filtersBar

            Divider()

            // Session list
            if telemetry.isLoading && telemetry.recentSessions.isEmpty {
                Spacer()
                ProgressView()
                    .transition(.opacity)
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
                .transition(.opacity)
                Spacer()
            } else {
                ScrollViewReader { sessionProxy in
                    List(selection: selectedSession) {
                        ForEach(telemetry.recentSessions) { session in
                            // All sessions use the same SessionRow (no special swarm style)
                            SessionRow(
                                session: session,
                                isSelected: selectedSessionId == session.id,
                                isLive: isSessionLive(session),
                                isNew: newSessionIds.contains(session.id)
                            )
                            .tag(session)
                            .id(session.id)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .onChange(of: telemetry.recentSessions.count) { oldCount, newCount in
                        guard autoFollowSessions, newCount > oldCount, newCount > 0 else { return }

                        // New session(s) arrived
                        if let firstSession = telemetry.recentSessions.first {
                            // Mark as new for entrance animation
                            let newIds = telemetry.recentSessions.prefix(newCount - oldCount).map { $0.id }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                newSessionIds.formUnion(newIds)
                            }

                            // Scroll to the newest session (first in list)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    sessionProxy.scrollTo(firstSession.id, anchor: .top)
                                }
                            }

                            // Clear "new" status after animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                newSessionIds.subtract(newIds)
                            }
                        }

                        previousSessionCount = newCount
                    }
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
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
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
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
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

    private var liveCostBar: some View {
        let sessions = telemetry.recentSessions
        let totalCost = sessions.reduce(0.0) { $0 + $1.totalCost + $1.childrenTotalCost }
        let totalTokens = sessions.reduce(0) { $0 + $1.totalInputTokens + $1.totalOutputTokens + $1.childrenTotalTokens }
        let sessionCount = sessions.count

        return HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(totalCost > 0 ? TC.warning : Color.primary.opacity(0.2))

            if totalCost > 0 {
                Text(totalCost < 0.01
                     ? String(format: "$%.5f", totalCost)
                     : String(format: "$%.4f", totalCost))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(TC.warning)
            } else {
                Text("$0")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }

            Spacer()

            if totalTokens > 0 {
                Text(totalTokens > 1_000_000
                     ? String(format: "%.1fM tok", Double(totalTokens) / 1_000_000)
                     : totalTokens > 1_000
                     ? String(format: "%.1fK tok", Double(totalTokens) / 1_000)
                     : "\(totalTokens) tok")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Text("\(sessionCount)s")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.quaternary)
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
                .font(.system(size: 12, design: .monospaced))
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
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
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
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
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
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(telemetry.onlyErrors ? Color.red.opacity(0.15) : Color.primary.opacity(0.04))
                    .foregroundStyle(telemetry.onlyErrors ? TC.error : .secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(telemetry.recentSessions.count)")
                .font(.system(size: 13, design: .monospaced))
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

    private func sessionDetailView(_ session: TelemetrySession) -> some View {
        VStack(spacing: 0) {
            sessionHeader(session)
            Divider()

            // Team coordinator banner
            if session.isTeamCoordinator || session.isSyntheticSwarmGroup {
                teamCoordinatorBanner(session)
                Divider()
            }

            // Back to coordinator breadcrumb for child sessions
            if let parentId = session.parentConversationId {
                coordinatorBreadcrumb(parentId: parentId)
                Divider()
            }

            if isSelectedSessionLive {
                autoFollowBar(session: session)
                Divider()
            }
            traceWaterfall(session: session)
        }
        .background(VibrancyBackground())
        .onAppear {
            if let session = liveSelectedSession {
                previousTraceCount = session.traces.count
                if !expandAll && expandedTraceIds.isEmpty {
                    autoExpandRecentTraces(session: session)
                }
            }
        }
    }

    @ViewBuilder
    private func autoFollowBar(session: TelemetrySession) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(TC.success)
                .frame(width: 6, height: 6)
                .modifier(PulseModifier())

            Text("LIVE")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(TC.success)

            Text("\u{00B7}")
                .foregroundStyle(.quaternary)

            Text("Auto-following latest turn")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                expandAll.toggle()
                if expandAll {
                    expandedTraceIds = Set(session.traces.map { $0.id })
                } else {
                    autoExpandRecentTraces(session: session)
                }
            } label: {
                Text(expandAll ? "COLLAPSE ALL" : "EXPAND ALL")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(expandAll ? Color.primary.opacity(0.12) : Color.primary.opacity(0.05))
                    .foregroundStyle(expandAll ? .primary : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)

            Button {
                autoFollow.toggle()
            } label: {
                Text(autoFollow ? "FOLLOWING" : "PAUSED")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
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
    }

    @ViewBuilder
    private func traceWaterfall(session: TelemetrySession) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Synthetic swarm group with no traces — team section IS the content
                    if session.isSyntheticSwarmGroup && session.traces.isEmpty && session.isTeamCoordinator {
                        TeamMembersSection(
                            session: session,
                            selectedSessionId: $selectedSessionId,
                            expandedChildAgentIds: $expandedChildAgentIds,
                            expandedChildTraceIds: $expandedChildTraceIds,
                            pinnedSpan: $pinnedSpan,
                            autoExpandedTeamSections: $autoExpandedTeamSections,
                            isSessionLive: isSessionLive
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }

                    ForEach(Array(session.traces.enumerated()), id: \.element.id) { index, trace in
                        traceRow(trace: trace, index: index, session: session)
                    }

                    // Fallback: children exist but no team.create trace found
                    if session.isTeamCoordinator
                        && !session.traces.contains(where: { $0.hasTeamCreate }) {
                        TeamMembersSection(
                            session: session,
                            selectedSessionId: $selectedSessionId,
                            expandedChildAgentIds: $expandedChildAgentIds,
                            expandedChildTraceIds: $expandedChildTraceIds,
                            pinnedSpan: $pinnedSpan,
                            autoExpandedTeamSections: $autoExpandedTeamSections,
                            isSessionLive: isSessionLive
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .onChange(of: session.traces.count) { oldCount, newCount in
                guard autoFollow, newCount > oldCount else { return }
                if !expandAll {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                        autoExpandRecentTraces(session: session)
                    }
                }
                if let lastTrace = session.traces.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo("trace-\(lastTrace.id)", anchor: .top)
                        }
                    }
                }
                previousTraceCount = newCount
            }
        }
    }

    private func sessionHeader(_ session: TelemetrySession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: Identity — status + agent + model + copy
            HStack(spacing: 6) {
                Text(session.hasErrors ? "ERR" : "OK")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(session.hasErrors ? TC.error : TC.success)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((session.hasErrors ? TC.error : TC.success).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                if let agent = session.agentName {
                    Text(agent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(TC.sourceClaude)
                        .lineLimit(1)
                }

                if let model = session.shortModelName {
                    Text(model)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                if session.isTeamCoordinator {
                    HStack(spacing: 3) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 9))
                        Text("\(session.childSessions.count)")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(TC.success)
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(session.id, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Copy session ID")
            }

            // Row 2: Metrics — wraps gracefully
            HStack(spacing: 8) {
                if let duration = session.duration, duration > 0.001 {
                    Text(session.formattedDuration)
                }

                Text("\(session.turnCount)t · \(session.toolCount)fn")

                if session.hasErrors {
                    Text("\(session.errorCount)err")
                        .foregroundStyle(TC.error)
                }

                if session.totalInputTokens > 0 {
                    Text("\(session.totalInputTokens)→\(session.totalOutputTokens)")
                        .foregroundStyle(TC.info)
                }

                if let cost = session.formattedCost {
                    Text(cost)
                        .foregroundStyle(TC.warning)
                }
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func teamCoordinatorBanner(_ session: TelemetrySession) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 12))
                .foregroundStyle(TC.success)

            Text("TEAM")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(TC.success)

            Text("\(session.childSessions.count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            if session.childrenTotalCost > 0 {
                Text(String(format: "$%.4f", session.childrenTotalCost))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(TC.warning)
            }

            if session.childrenTotalTokens > 0 {
                let tokens = session.childrenTotalTokens
                Text(tokens > 1_000_000
                     ? String(format: "%.1fM", Double(tokens) / 1_000_000)
                     : tokens > 1_000
                     ? String(format: "%.1fK", Double(tokens) / 1_000)
                     : "\(tokens) tok")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(TC.info)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(TC.success.opacity(0.04))
    }

    @ViewBuilder
    private func coordinatorBreadcrumb(parentId: String) -> some View {
        let parentSession = findSession(id: parentId)
        let coordinatorName = parentSession?.agentName ?? parentSession?.teamName ?? "Coordinator"

        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedSessionId = parentId
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                Text("Team: \(coordinatorName)")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(TC.success)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TC.success.opacity(0.04))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func timelineHeader(_ trace: Trace) -> some View {
        HStack {
            Text("Operation")
                .frame(width: 200, alignment: .leading)

            GeometryReader { geo in
                let duration = trace.duration ?? 1

                ZStack(alignment: .leading) {
                    // 3 evenly-spaced markers at 25%, 50%, 75%
                    ForEach([0.25, 0.5, 0.75], id: \.self) { pct in
                        Text(formatDuration(duration * pct))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.quaternary)
                            .fixedSize()
                            .position(x: geo.size.width * pct, y: 8)
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

    // MARK: - Trace Row (extracted for type-checker)

    @ViewBuilder
    private func traceRow(trace: Trace, index: Int, session: TelemetrySession) -> some View {
        let isLastTrace = index == session.traces.count - 1
        let isLive = isTraceLive(trace, in: session)

        VStack(alignment: .leading, spacing: 0) {
            // Trace header row (clickable to expand/collapse)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    if expandedTraceIds.contains(trace.id) {
                        expandedTraceIds.remove(trace.id)
                    } else {
                        expandedTraceIds.insert(trace.id)
                    }
                }
            } label: {
                traceHeaderLabel(trace: trace, index: index, isLive: isLive)
            }
            .buttonStyle(.plain)

            // Expanded: show span waterfall
            if expandedTraceIds.contains(trace.id) {
                VStack(alignment: .leading, spacing: 0) {
                    timelineHeader(trace)
                        .padding(.horizontal, 16)

                    ForEach(trace.waterfallSpans) { span in
                        SpanRow(
                            span: span,
                            traceStart: trace.startTime,
                            traceDuration: trace.duration ?? 1,
                            isSelected: pinnedSpan?.id == span.id,
                            onSelect: { pinnedSpan = span }
                        )
                    }

                    // Team members inline — anchored to the trace that spawned the team
                    if trace.hasTeamCreate && !session.childSessions.isEmpty {
                        TeamMembersSection(
                            session: session,
                            selectedSessionId: $selectedSessionId,
                            expandedChildAgentIds: $expandedChildAgentIds,
                            expandedChildTraceIds: $expandedChildTraceIds,
                            pinnedSpan: $pinnedSpan,
                            autoExpandedTeamSections: $autoExpandedTeamSections,
                            isSessionLive: isSessionLive
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
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

    @ViewBuilder
    private func traceHeaderLabel(trace: Trace, index: Int, isLive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: expandedTraceIds.contains(trace.id) ? "chevron.down" : "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            if isLive {
                Circle()
                    .fill(TC.success)
                    .frame(width: 5, height: 5)
                    .modifier(PulseModifier())
            }

            Text("Turn \(index + 1)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .fixedSize()

            if !isLive {
                Text(trace.hasErrors ? "ERR" : "OK")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(trace.hasErrors ? TC.error : TC.success)
                    .fixedSize()
            }

            // Tool summary — truncates gracefully
            let tools = trace.waterfallSpans.compactMap { $0.toolName }
            let uniqueTools = Set(tools)
            if !tools.isEmpty {
                Text("\(tools.count)fn")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Text(uniqueTools.prefix(2).joined(separator: ", "))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            // Right-aligned metrics — fixed size so they don't compress
            HStack(spacing: 6) {
                if let cost = trace.formattedCost {
                    Text(cost)
                        .foregroundStyle(TC.warning)
                }

                if !isLive, let duration = trace.duration, duration > 0.001 {
                    Text(trace.formattedDuration)
                        .foregroundStyle(.secondary)
                }

                if !isLive {
                    Text(trace.startTime, style: .relative)
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.system(size: 10, design: .monospaced))
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(
            expandedTraceIds.contains(trace.id)
                ? (isLive ? TC.success.opacity(0.04) : Color.primary.opacity(0.04))
                : Color.clear
        )
    }

    /// Auto-expand the most recent 2-3 traces (keeps older ones collapsed)
    private func autoExpandRecentTraces(session: TelemetrySession) {
        let recentCount = min(3, session.traces.count)
        expandedTraceIds = Set(session.traces.suffix(recentCount).map { $0.id })
    }

    // MARK: - Helpers

    /// Check if a session received data in the last 30 seconds (still active)
    /// For team/swarm sessions, checks children and grandchildren
    private func isSessionLive(_ session: TelemetrySession) -> Bool {
        if let endTime = session.endTime, Date().timeIntervalSince(endTime) < 30 {
            return true
        }
        if session.isTeamCoordinator || session.isSyntheticSwarmGroup {
            for child in session.childSessions {
                if let endTime = child.endTime, Date().timeIntervalSince(endTime) < 30 {
                    return true
                }
                for grandchild in child.childSessions {
                    if let endTime = grandchild.endTime, Date().timeIntervalSince(endTime) < 30 {
                        return true
                    }
                }
            }
        }
        return false
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
