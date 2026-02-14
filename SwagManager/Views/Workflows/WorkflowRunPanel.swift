import SwiftUI

// MARK: - Workflow Run Panel
// Right inspector panel showing live execution progress via polling
// Displays step timeline, streaming agent tokens, approval cards
// Now with full telemetry waterfall (spans, tokens, cost) via WorkflowTelemetryService

struct WorkflowRunPanel: View {
    let runId: String
    let workflowId: String?
    let storeId: UUID?
    let onDismiss: () -> Void
    var telemetry: WorkflowTelemetryService?

    @Environment(\.workflowService) private var service

    @State private var run: WorkflowRun?
    @State private var stepRuns: [StepRun] = []
    @State private var agentTokens: [String: String] = [:]
    @State private var stepProgress: [String: (Double, String?)] = [:]
    @State private var pendingApprovals: [ApprovalRequest] = []
    @State private var waitpoints: [WorkflowWaitpoint] = []
    @State private var checkpoints: [WorkflowCheckpoint] = []
    @State private var isConnected = false
    @State private var streamTask: Task<Void, Never>?
    @State private var selectedStepKey: String?
    @State private var showStepOutput = false

    // Telemetry view state
    @State private var viewMode: ViewMode = .steps
    @State private var expandedStepSpans: Set<String> = []

    enum ViewMode: String, CaseIterable {
        case steps = "Steps"
        case trace = "Trace"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider().opacity(0.3)

            // Stats bar (when telemetry is available)
            if let tel = telemetry, tel.spanCount > 0 {
                telemetryStatsBar(tel)
                Divider().opacity(0.3)
            }

            // Content
            ScrollView {
                LazyVStack(spacing: DS.Spacing.sm) {
                    // Approval cards
                    ForEach(pendingApprovals) { approval in
                        approvalCard(approval)
                    }

                    // Waitpoint cards
                    ForEach(waitpoints.filter { $0.status == "pending" }) { wp in
                        waitpointCard(wp)
                    }

                    // View mode content
                    switch viewMode {
                    case .steps:
                        stepsContent
                    case .trace:
                        traceContent
                    }
                }
                .padding(DS.Spacing.md)
            }

            // Span inspector (when a span is selected)
            if let tel = telemetry, let span = tel.selectedSpan {
                Divider().opacity(0.3)
                spanInspectorPanel(span, telemetry: tel)
            }

            // Agent token stream (if any step has streaming tokens)
            if tel?.selectedSpan == nil, let activeStep = activeAgentStep, let tokens = agentTokens[activeStep] {
                Divider().opacity(0.3)
                agentStreamView(stepKey: activeStep, tokens: tokens)
            }
        }
        .background(DS.Colors.surfaceTertiary)
        .task {
            await startStreaming()
        }
        .onDisappear {
            streamTask?.cancel()
        }
    }

    private var tel: WorkflowTelemetryService? { telemetry }

    // MARK: - Steps Content (original + expandable spans)

    @ViewBuilder
    private var stepsContent: some View {
        ForEach(sortedStepRuns, id: \.id) { step in
            stepTimelineRow(step)
        }

        // Loading state
        if stepRuns.isEmpty && isConnected {
            HStack(spacing: DS.Spacing.sm) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Waiting for steps...")
                    .font(DS.Typography.caption1)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.lg)
        }
    }

    // MARK: - Trace Content (waterfall view)

    @ViewBuilder
    private var traceContent: some View {
        if let tel = telemetry, !tel.allSpans.isEmpty {
            // Group spans by step, then render waterfall
            let stepKeys = orderedStepKeys(tel)

            ForEach(stepKeys, id: \.self) { stepKey in
                let spans = tel.spans(for: stepKey)
                if !spans.isEmpty {
                    stepSpanGroup(stepKey: stepKey, spans: spans, telemetry: tel)
                }
            }

            // Unassigned spans
            let unassigned = tel.spans(for: "_unassigned")
            if !unassigned.isEmpty {
                stepSpanGroup(stepKey: "_unassigned", spans: unassigned, telemetry: tel)
            }
        } else {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "waveform.path.ecg")
                    .font(DesignSystem.font(14))
                    .foregroundStyle(DS.Colors.textQuaternary)
                Text("No telemetry spans yet")
                    .font(DS.Typography.caption1)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.lg)
        }
    }

    // MARK: - Step Span Group (collapsible)

    private func stepSpanGroup(stepKey: String, spans: [TelemetrySpan], telemetry tel: WorkflowTelemetryService) -> some View {
        VStack(spacing: 0) {
            // Step header
            Button {
                withAnimation(DS.Animation.fast) {
                    if expandedStepSpans.contains(stepKey) {
                        expandedStepSpans.remove(stepKey)
                    } else {
                        expandedStepSpans.insert(stepKey)
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: expandedStepSpans.contains(stepKey) ? "chevron.down" : "chevron.right")
                        .font(DesignSystem.font(8, weight: .bold))
                        .foregroundStyle(DS.Colors.textQuaternary)
                        .frame(width: 10)

                    if let step = stepRuns.first(where: { $0.stepKey == stepKey }) {
                        Image(systemName: WorkflowStepType.icon(for: step.stepType))
                            .font(DesignSystem.font(10))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }

                    Text(stepKey == "_unassigned" ? "Other Spans" : stepKey)
                        .font(DS.Typography.monoCaption)
                        .foregroundStyle(DS.Colors.textPrimary)

                    Spacer()

                    // Span count badge
                    Text("\(spans.count)")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textQuaternary)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 1)
                        .background(DS.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.xs))

                    // Token count
                    let tokens = tel.tokenCount(for: stepKey)
                    if tokens > 0 {
                        Text(formatTokens(tokens))
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.cyan)
                    }

                    // Cost
                    let cost = tel.cost(for: stepKey)
                    if cost > 0 {
                        Text(String(format: "$%.4f", cost))
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.success)
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
                .padding(.horizontal, DS.Spacing.sm)
                .background(DS.Colors.surfaceElevated.opacity(0.5), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plain)

            // Expanded spans waterfall
            if expandedStepSpans.contains(stepKey) {
                VStack(spacing: 1) {
                    ForEach(spans) { span in
                        SpanRow(
                            span: span,
                            traceStart: tel.waterfallStart,
                            traceDuration: tel.waterfallDuration,
                            isSelected: tel.selectedSpan?.id == span.id,
                            onSelect: { tel.selectedSpan = span }
                        )
                    }
                }
                .padding(.leading, DS.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Telemetry Stats Bar

    private func telemetryStatsBar(_ tel: WorkflowTelemetryService) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Span count
            statItem(icon: "waveform.path.ecg", value: "\(tel.spanCount)", label: "spans")

            // Total tokens
            if tel.totalTokens > 0 {
                statItem(icon: "text.word.spacing", value: formatTokens(tel.totalTokens), label: "tokens")
            }

            // Total cost
            if tel.totalCost > 0 {
                statItem(icon: "dollarsign.circle", value: String(format: "$%.4f", tel.totalCost), label: "cost")
            }

            // Error count
            if tel.errorCount > 0 {
                statItem(icon: "exclamationmark.triangle", value: "\(tel.errorCount)", label: "errors", color: DS.Colors.error)
            }

            Spacer()

            // Realtime indicator
            Circle()
                .fill(tel.isLive ? DS.Colors.success : DS.Colors.textQuaternary)
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
    }

    private func statItem(icon: String, value: String, label: String, color: Color = DS.Colors.textSecondary) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(DesignSystem.font(9))
                .foregroundStyle(color.opacity(0.7))
            Text(value)
                .font(DS.Typography.monoSmall)
                .foregroundStyle(color)
        }
        .help(label)
    }

    // MARK: - Span Inspector Panel

    private func spanInspectorPanel(_ span: TelemetrySpan, telemetry tel: WorkflowTelemetryService) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Text(span.isError ? "ERR" : "OK")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(span.isError ? DS.Colors.error : DS.Colors.success)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 1)
                    .background((span.isError ? DS.Colors.error : DS.Colors.success).opacity(0.12), in: RoundedRectangle(cornerRadius: 3))

                Text(span.toolName ?? span.action)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .lineLimit(1)

                Spacer()

                Text(span.formattedDuration)
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textTertiary)

                Button { tel.selectedSpan = nil } label: {
                    Image(systemName: "xmark")
                        .font(DesignSystem.font(9, weight: .medium))
                        .foregroundStyle(DS.Colors.textQuaternary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)

            // Comparison bar
            if let comparison = tel.spanComparison {
                SpanComparisonBar(span: span, comparison: comparison)
            }

            Divider().opacity(0.3)

            // Span detail content (reused from TelemetryPanelViews)
            ScrollView {
                SpanDetailContentView(span: span)
                    .padding(DS.Spacing.md)
            }
            .frame(maxHeight: 250)
        }
        .background(DS.Colors.surfaceElevated.opacity(0.3))
        .task(id: span.id) {
            if span.isToolSpan {
                await tel.fetchSpanComparison(spanId: span.id)
            }
        }
    }

    // MARK: - Header (compact inline bar)

    private var header: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                // Status + step count
                if let run {
                    Image(systemName: run.statusIcon)
                        .font(DesignSystem.font(11))
                        .foregroundStyle(runStatusColor)

                    Text(run.status.uppercased())
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(runStatusColor)
                }

                let completed = stepRuns.filter { $0.status == "success" || $0.status == "completed" }.count
                let failed = stepRuns.filter { $0.status == "failed" || $0.status == "error" }.count
                Text("\(completed)/\(stepRuns.count)")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
                if failed > 0 {
                    Text("\(failed) err")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.error)
                }

                Spacer()

                // View mode toggle (only when telemetry available)
                if telemetry != nil {
                    Picker("", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }

                // SSE indicator
                Circle()
                    .fill(isConnected ? DS.Colors.success : DS.Colors.textQuaternary)
                    .frame(width: 5, height: 5)

                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DesignSystem.font(9, weight: .medium))
                        .foregroundStyle(DS.Colors.textQuaternary)
                }
                .buttonStyle(.plain)
            }

            // Run controls (only when active)
            if let run, run.status == "running" || run.status == "paused" {
                HStack(spacing: DS.Spacing.sm) {
                    if run.status == "running" {
                        Button { pauseRun() } label: {
                            Image(systemName: "pause.fill")
                                .font(DesignSystem.font(9))
                                .foregroundStyle(DS.Colors.warning)
                                .frame(width: 24, height: 22)
                                .background(DS.Colors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.xs))
                        }
                        .buttonStyle(.plain)
                    }

                    if run.status == "paused" {
                        Button { resumeRun() } label: {
                            Image(systemName: "play.fill")
                                .font(DesignSystem.font(9))
                                .foregroundStyle(DS.Colors.success)
                                .frame(width: 24, height: 22)
                                .background(DS.Colors.success.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.xs))
                        }
                        .buttonStyle(.plain)
                    }

                    Button { cancelRun() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(DesignSystem.font(9))
                            .foregroundStyle(DS.Colors.error)
                            .frame(width: 24, height: 22)
                            .background(DS.Colors.error.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.xs))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Step Timeline Row

    private func stepTimelineRow(_ step: StepRun) -> some View {
        VStack(spacing: 0) {
        Button {
            withAnimation(DS.Animation.fast) {
                selectedStepKey = selectedStepKey == step.stepKey ? nil : step.stepKey
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                // Status indicator line + dot
                VStack(spacing: 0) {
                    Circle()
                        .fill(stepStatusColor(step.status))
                        .frame(width: 8, height: 8)
                }

                // Step info
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack {
                        Image(systemName: WorkflowStepType.icon(for: step.stepType))
                            .font(DesignSystem.font(10))
                            .foregroundStyle(DS.Colors.textSecondary)

                        Text(step.stepKey)
                            .font(DS.Typography.monoCaption)
                            .foregroundStyle(DS.Colors.textPrimary)

                        Spacer()

                        // Telemetry badges (inline)
                        if let tel = telemetry {
                            let tokens = tel.tokenCount(for: step.stepKey)
                            if tokens > 0 {
                                Text(formatTokens(tokens))
                                    .font(DS.Typography.monoSmall)
                                    .foregroundStyle(DS.Colors.cyan)
                            }
                        }

                        if let ms = step.durationMs {
                            Text(formatDuration(ms))
                                .font(DS.Typography.monoSmall)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }

                    // Status text
                    HStack(spacing: DS.Spacing.xs) {
                        Text(step.status.uppercased())
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(stepStatusColor(step.status))

                        // Active tool name (from telemetry)
                        if let tel = telemetry, let tool = tel.activeTool(for: step.stepKey) {
                            Text(tool)
                                .font(DS.Typography.monoSmall)
                                .foregroundStyle(DS.Colors.accent)
                        }
                    }

                    // Duration bar (proportional to max)
                    if let ms = step.durationMs {
                        let maxMs = stepRuns.compactMap(\.durationMs).max() ?? 1
                        let fraction = CGFloat(ms) / CGFloat(max(maxMs, 1))
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(stepStatusColor(step.status).opacity(0.3))
                                .frame(width: geo.size.width * min(fraction, 1.0))
                        }
                        .frame(height: 4)
                    }

                    // Progress bar (if available)
                    if let (progress, message) = stepProgress[step.stepKey] {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(DS.Colors.surfaceElevated)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(DS.Colors.accent)
                                        .frame(width: geo.size.width * progress)
                                }
                            }
                            .frame(height: 3)

                            if let msg = message {
                                Text(msg)
                                    .font(DS.Typography.monoSmall)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                        }
                    }

                    // Error message
                    if let error = step.error {
                        Text(error)
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.error)
                            .lineLimit(2)
                    }

                    // Retry count
                    if let retries = step.retryCount, retries > 0 {
                        Text("Retry \(retries)")
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.warning)
                    }
                }
            }
            .padding(DS.Spacing.sm)
            .background(
                selectedStepKey == step.stepKey ? DS.Colors.selectionActive : Color.clear,
                in: RoundedRectangle(cornerRadius: DS.Radius.md)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let checkpoint = checkpoints.first(where: { $0.stepKey == step.stepKey }) {
                Button {
                    Task {
                        if let newRun = await service.replayFromCheckpoint(checkpointId: checkpoint.id, storeId: storeId) {
                            run = newRun
                        }
                    }
                } label: {
                    Label("Replay from Checkpoint", systemImage: "arrow.counterclockwise.circle.fill")
                }
            }
        }

        // Expandable content when selected
        if selectedStepKey == step.stepKey {
            VStack(spacing: DS.Spacing.sm) {
                // I/O inspector
                stepInspector(step)

                // Telemetry spans for this step (mini waterfall)
                if let tel = telemetry {
                    let spans = tel.spans(for: step.stepKey)
                    if !spans.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("SPANS (\(spans.count))")
                                .font(DS.Typography.monoHeader)
                                .foregroundStyle(DS.Colors.textTertiary)

                            VStack(spacing: 1) {
                                ForEach(spans) { span in
                                    SpanRow(
                                        span: span,
                                        traceStart: tel.waterfallStart,
                                        traceDuration: tel.waterfallDuration,
                                        isSelected: tel.selectedSpan?.id == span.id,
                                        onSelect: { tel.selectedSpan = span }
                                    )
                                }
                            }
                        }
                        .padding(.leading, DS.Spacing.xl)
                        .padding(.bottom, DS.Spacing.sm)
                    }
                }
            }
        }
        } // end VStack
    }

    // MARK: - Approval Card

    private func approvalCard(_ approval: ApprovalRequest) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(DS.Colors.warning)
                Text(approval.title ?? "Approval Required")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Colors.textPrimary)
            }

            if let desc = approval.description {
                Text(desc)
                    .font(DS.Typography.caption1)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            HStack(spacing: DS.Spacing.sm) {
                Button {
                    Task {
                        _ = await service.respondToApproval(approvalId: approval.id, status: "approved", responseData: nil, storeId: storeId)
                        pendingApprovals.removeAll { $0.id == approval.id }
                    }
                } label: {
                    Text("Approve")
                        .font(DS.Typography.buttonSmall)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Colors.success.opacity(0.2), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .foregroundStyle(DS.Colors.success)
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        _ = await service.respondToApproval(approvalId: approval.id, status: "rejected", responseData: nil, storeId: storeId)
                        pendingApprovals.removeAll { $0.id == approval.id }
                    }
                } label: {
                    Text("Reject")
                        .font(DS.Typography.buttonSmall)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Colors.error.opacity(0.2), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .foregroundStyle(DS.Colors.error)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.warning.opacity(0.05))
        .cardStyle(padding: 0, cornerRadius: DS.Radius.md)
    }

    // MARK: - Waitpoint Card

    private func waitpointCard(_ wp: WorkflowWaitpoint) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "hourglass.circle.fill")
                    .foregroundStyle(DS.Colors.cyan)
                Text(wp.label ?? "Waiting: \(wp.stepKey)")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Colors.textPrimary)

                Spacer()

                if let expires = wp.expiresAt {
                    Text("Expires \(expires.prefix(10))")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textQuaternary)
                }
            }

            Button {
                Task {
                    if await service.completeWaitpoint(waitpointId: wp.id, data: nil, storeId: storeId) {
                        waitpoints.removeAll { $0.id == wp.id }
                    }
                }
            } label: {
                Text("Complete")
                    .font(DS.Typography.buttonSmall)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.cyan.opacity(0.2), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .foregroundStyle(DS.Colors.cyan)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cyan.opacity(0.05))
        .cardStyle(padding: 0, cornerRadius: DS.Radius.md)
    }

    // MARK: - Agent Token Stream

    private func agentStreamView(stepKey: String, tokens: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Image(systemName: "brain")
                    .font(DesignSystem.font(10))
                    .foregroundStyle(DS.Colors.cyan)
                Text("AGENT: \(stepKey)")
                    .font(DS.Typography.monoHeader)
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            ScrollView {
                Text(tokens)
                    .font(DS.Typography.monoCaption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
        }
        .padding(DS.Spacing.md)
    }

    // MARK: - Data Loading (Polling)

    private func startStreaming() async {
        // Initial load
        await refreshRunData()
        isConnected = true

        // Start telemetry tracking if traceId available
        if let traceId = run?.traceId, let tel = telemetry {
            tel.startTracking(traceId: traceId, stepRuns: stepRuns)
            // Auto-expand all step groups in trace view
            for step in stepRuns {
                expandedStepSpans.insert(step.stepKey)
            }
        }

        // Poll every 2s until run completes
        streamTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                await refreshRunData()

                // Update telemetry with latest step runs
                telemetry?.updateStepRuns(stepRuns)

                // Start tracking if we just got a traceId
                if let traceId = run?.traceId, let tel = telemetry, tel.spanCount == 0 {
                    tel.startTracking(traceId: traceId, stepRuns: stepRuns)
                }

                // Stop polling if run is terminal
                if let r = run, ["success", "completed", "failed", "error", "cancelled"].contains(r.status) {
                    break
                }
            }
            await MainActor.run { isConnected = false }
        }
    }

    private func refreshRunData() async {
        // Fetch run info
        let runs = await service.getRuns(workflowId: workflowId, storeId: storeId)
        if let match = runs.first(where: { $0.id == runId }) {
            await MainActor.run { run = match }
        }

        // Fetch step runs
        let steps = await service.getStepRuns(runId: runId, storeId: storeId)
        await MainActor.run { stepRuns = steps }
    }

    private func handleEvent(_ event: WorkflowSSEEvent) {
        switch event {
        case .snapshot(let runData, let steps):
            run = runData
            stepRuns = steps

        case .stepUpdate(let stepKey, let status, let durationMs, let error):
            if let idx = stepRuns.firstIndex(where: { $0.stepKey == stepKey }) {
                let existing = stepRuns[idx]
                stepRuns[idx] = StepRun(
                    id: existing.id,
                    runId: runId,
                    stepKey: stepKey,
                    stepType: existing.stepType,
                    status: status,
                    input: existing.input,
                    output: existing.output,
                    error: error,
                    durationMs: durationMs,
                    startedAt: existing.startedAt,
                    completedAt: nil,
                    retryCount: existing.retryCount
                )
            } else {
                stepRuns.append(StepRun(
                    id: UUID().uuidString,
                    runId: runId,
                    stepKey: stepKey,
                    stepType: "",
                    status: status,
                    input: nil,
                    output: nil,
                    error: error,
                    durationMs: durationMs,
                    startedAt: nil,
                    completedAt: nil,
                    retryCount: nil
                ))
            }

        case .runUpdate(let status, _):
            if run != nil {
                run = WorkflowRun(
                    id: runId,
                    workflowId: run!.workflowId,
                    status: status,
                    triggerType: run?.triggerType,
                    triggerPayload: nil,
                    startedAt: run?.startedAt,
                    completedAt: nil,
                    error: run?.error,
                    traceId: run?.traceId
                )
            }

        case .agentToken(let stepKey, let token):
            agentTokens[stepKey, default: ""] += token

        case .stepProgress(let stepKey, let progress, let message):
            stepProgress[stepKey] = (progress, message)

        case .event(let eventType, _):
            if eventType == "approval_requested" {
                Task {
                    pendingApprovals = await service.listApprovals(status: "pending", storeId: storeId)
                }
            }

        case .heartbeat:
            break
        }
    }

    // MARK: - Step I/O Inspector

    private func stepInspector(_ step: StepRun) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Input section
            if let input = step.input {
                inspectorSection("INPUT", json: input)
            }

            // Output section
            if let output = step.output {
                inspectorSection("OUTPUT", json: output)
            }

            // If no I/O data available
            if step.input == nil && step.output == nil {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "info.circle")
                        .font(DesignSystem.font(10))
                    Text("I/O data not available for this step")
                        .font(DS.Typography.caption2)
                }
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(DS.Spacing.sm)
            }
        }
        .padding(.leading, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.sm)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func inspectorSection(_ title: String, json: [String: AnyCodable]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(title)
                    .font(DS.Typography.monoHeader)
                    .foregroundStyle(DS.Colors.textTertiary)

                Spacer()

                Button {
                    if let data = try? JSONSerialization.data(withJSONObject: json.mapValues(\.value), options: .prettyPrinted),
                       let str = String(data: data, encoding: .utf8) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(str, forType: .string)
                    }
                } label: {
                    Image(systemName: "doc.on.doc.fill")
                        .font(DesignSystem.font(10))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Copy JSON")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(prettyJSON(json))
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 200)
            .padding(DS.Spacing.sm)
            .glassBackground(cornerRadius: DS.Radius.sm)
        }
    }

    private func prettyJSON(_ value: [String: AnyCodable]) -> String {
        let raw = value.mapValues(\.value)
        guard let data = try? JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return String(describing: raw)
        }
        return str
    }

    // MARK: - Run Control Actions

    private func pauseRun() {
        Task { _ = await service.pauseRun(runId: runId, storeId: storeId) }
    }

    private func resumeRun() {
        Task { _ = await service.resumeRun(runId: runId, storeId: storeId) }
    }

    private func cancelRun() {
        Task { _ = await service.cancelRun(runId: runId, storeId: storeId) }
    }

    // MARK: - Helpers

    private var sortedStepRuns: [StepRun] {
        stepRuns.sorted { a, b in
            if a.status == "running" && b.status != "running" { return true }
            if a.status != "running" && b.status == "running" { return false }
            return (a.startedAt ?? "") < (b.startedAt ?? "")
        }
    }

    private var activeAgentStep: String? {
        stepRuns.first { $0.status == "running" && agentTokens[$0.stepKey] != nil }?.stepKey
    }

    private var runStatusColor: Color {
        guard let run else { return DS.Colors.textQuaternary }
        switch run.status {
        case "success", "completed": return DS.Colors.success
        case "running": return DS.Colors.warning
        case "failed", "error": return DS.Colors.error
        default: return DS.Colors.textTertiary
        }
    }

    private func stepStatusColor(_ status: String) -> Color {
        switch status {
        case "success", "completed": return DS.Colors.success
        case "running": return DS.Colors.warning
        case "failed", "error": return DS.Colors.error
        case "pending": return DS.Colors.textQuaternary
        case "skipped": return DS.Colors.textTertiary
        default: return DS.Colors.textQuaternary
        }
    }

    private func formatDuration(_ ms: Int) -> String {
        if ms < 1000 { return "\(ms)ms" }
        let seconds = Double(ms) / 1000.0
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let minutes = Int(seconds / 60)
        let secs = Int(seconds) % 60
        return "\(minutes)m\(secs)s"
    }

    private func formatTokens(_ count: Int) -> String {
        if count < 1000 { return "\(count)" }
        if count < 100_000 { return String(format: "%.1fk", Double(count) / 1000.0) }
        return String(format: "%.0fk", Double(count) / 1000.0)
    }

    /// Get step keys in execution order for waterfall display
    private func orderedStepKeys(_ tel: WorkflowTelemetryService) -> [String] {
        // Use step run order if available
        if !stepRuns.isEmpty {
            let ordered = sortedStepRuns.map(\.stepKey)
            // Add any step keys from telemetry not in step runs
            let extra = tel.spansByStep.keys.filter { !ordered.contains($0) && $0 != "_unassigned" }.sorted()
            return ordered + extra
        }
        // Fall back to alphabetical
        return tel.spansByStep.keys.filter { $0 != "_unassigned" }.sorted()
    }
}
