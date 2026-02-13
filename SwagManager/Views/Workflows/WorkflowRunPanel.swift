import SwiftUI

// MARK: - Workflow Run Panel
// Right inspector panel showing live execution progress via SSE
// Displays step timeline, streaming agent tokens, approval cards

struct WorkflowRunPanel: View {
    let runId: String
    let workflowId: String?
    let storeId: UUID?
    let onDismiss: () -> Void

    @Environment(\.workflowService) private var service

    @State private var run: WorkflowRun?
    @State private var stepRuns: [StepRun] = []
    @State private var agentTokens: [String: String] = [:]
    @State private var stepProgress: [String: (Double, String?)] = [:]
    @State private var pendingApprovals: [ApprovalRequest] = []
    @State private var isConnected = false
    @State private var streamTask: Task<Void, Never>?
    @State private var selectedStepKey: String?
    @State private var showStepOutput = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider().opacity(0.3)

            // Content
            ScrollView {
                LazyVStack(spacing: DS.Spacing.sm) {
                    // Approval cards
                    ForEach(pendingApprovals) { approval in
                        approvalCard(approval)
                    }

                    // Step timeline
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
                .padding(DS.Spacing.md)
            }

            // Agent token stream (if any step has streaming tokens)
            if let activeStep = activeAgentStep, let tokens = agentTokens[activeStep] {
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack {
                // Status icon
                if let run {
                    Image(systemName: run.statusIcon)
                        .font(DesignSystem.font(14))
                        .foregroundStyle(runStatusColor)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("RUN")
                        .font(DS.Typography.monoHeader)
                        .foregroundStyle(DS.Colors.textTertiary)
                    if let run {
                        Text(run.status.uppercased())
                            .font(DS.Typography.monoLabel)
                            .foregroundStyle(runStatusColor)
                    }
                }

                Spacer()

                // SSE indicator
                HStack(spacing: DS.Spacing.xxs) {
                    Circle()
                        .fill(isConnected ? DS.Colors.success : DS.Colors.textQuaternary)
                        .frame(width: 6, height: 6)
                    Text(isConnected ? "LIVE" : "OFFLINE")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(isConnected ? DS.Colors.success : DS.Colors.textQuaternary)
                }

                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DesignSystem.font(10, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Duration + step count
            if let run {
                HStack(spacing: DS.Spacing.md) {
                    if let started = run.startedAt {
                        Label(started.prefix(19).description, systemImage: "clock")
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }

                    Text("\(stepRuns.count) steps")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textTertiary)

                    let completed = stepRuns.filter { $0.status == "success" || $0.status == "completed" }.count
                    let failed = stepRuns.filter { $0.status == "failed" || $0.status == "error" }.count
                    if completed > 0 {
                        Text("\(completed) done")
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.success)
                    }
                    if failed > 0 {
                        Text("\(failed) failed")
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.error)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
    }

    // MARK: - Step Timeline Row

    private func stepTimelineRow(_ step: StepRun) -> some View {
        Button {
            withAnimation(DS.Animation.fast) {
                selectedStepKey = step.stepKey
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

                        if let ms = step.durationMs {
                            Text(formatDuration(ms))
                                .font(DS.Typography.monoSmall)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }

                    // Status text
                    Text(step.status.uppercased())
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(stepStatusColor(step.status))

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
    }

    // MARK: - Approval Card

    private func approvalCard(_ approval: ApprovalRequest) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "hand.raised.fill")
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

    // MARK: - Agent Token Stream

    private func agentStreamView(stepKey: String, tokens: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Image(systemName: "cpu")
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

    // MARK: - Streaming

    private func startStreaming() async {
        // Load initial step runs
        stepRuns = await service.getStepRuns(runId: runId, storeId: storeId)

        // Connect SSE
        isConnected = true
        streamTask = Task {
            for await event in service.streamRun(runId: runId) {
                await MainActor.run {
                    handleEvent(event)
                }
            }
            await MainActor.run {
                isConnected = false
            }
        }
    }

    private func handleEvent(_ event: WorkflowSSEEvent) {
        switch event {
        case .snapshot(let runData, let steps):
            run = runData
            stepRuns = steps

        case .stepUpdate(let stepKey, let status, let durationMs, let error):
            if let idx = stepRuns.firstIndex(where: { $0.stepKey == stepKey }) {
                // Update existing
                stepRuns[idx] = StepRun(
                    id: stepRuns[idx].id,
                    runId: runId,
                    stepKey: stepKey,
                    stepType: stepRuns[idx].stepType,
                    status: status,
                    input: nil,
                    output: nil,
                    error: error,
                    durationMs: durationMs,
                    startedAt: stepRuns[idx].startedAt,
                    completedAt: nil,
                    retryCount: stepRuns[idx].retryCount
                )
            } else {
                // New step
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
                // Refresh approvals
                Task {
                    pendingApprovals = await service.listApprovals(status: "pending", storeId: storeId)
                }
            }

        case .heartbeat:
            break
        }
    }

    // MARK: - Helpers

    private var sortedStepRuns: [StepRun] {
        stepRuns.sorted { a, b in
            // Running first, then by start time
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
}
