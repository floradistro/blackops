import SwiftUI

// MARK: - Step Run Record

struct StepRunRecord: Identifiable {
    let id: String
    let runId: String
    let status: String
    let durationMs: Int?
    let startedAt: Date?
    let completedAt: Date?
    let error: String?
    let outputPreview: String?
}

// MARK: - Step Execution History

struct StepExecutionHistory: View {
    let stepKey: String
    let workflowId: String
    let storeId: UUID?
    var onDismiss: (() -> Void)? = nil

    @State private var runs: [StepRunRecord] = []
    @State private var isLoading = true
    @Environment(\.workflowService) private var service
    @Environment(\.dismiss) private var dismiss

    private func close() {
        if let onDismiss { onDismiss() } else { dismiss() }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            header

            Divider().opacity(0.3)

            // Content
            if isLoading {
                loadingState
            } else if runs.isEmpty {
                emptyState
            } else {
                runList
            }
        }
        .frame(minWidth: 280, idealWidth: 360, maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Colors.border, lineWidth: 0.5)
        }
        .task {
            await loadHistory()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("Run History")
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textPrimary)

            Text(stepKey)
                .font(DS.Typography.monoLabel)
                .foregroundStyle(DS.Colors.accent)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs)
                .background(DS.Colors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.xs))

            Spacer()

            Button { close() } label: {
                Image(systemName: "xmark")
                    .font(DesignSystem.font(10, weight: .medium))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.md)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: DS.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Loading history...")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(DS.Spacing.lg)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "clock.badge.questionmark")
                .font(DesignSystem.font(24, weight: .light))
                .foregroundStyle(DS.Colors.textQuaternary)
            Text("No runs found")
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textTertiary)
            Text("This step hasn't been executed yet.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textQuaternary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(DS.Spacing.lg)
    }

    // MARK: - Run List

    private var runList: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.sm) {
                ForEach(runs) { record in
                    runRow(record)
                }
            }
            .padding(DS.Spacing.md)
        }
    }

    // MARK: - Run Row

    private func runRow(_ record: StepRunRecord) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                // Status icon
                Image(systemName: statusIcon(record.status))
                    .font(DesignSystem.font(12))
                    .foregroundStyle(statusColor(record.status))

                // Run ID (truncated, monospaced)
                Text(String(record.runId.prefix(8)))
                    .font(DS.Typography.monoCaption)
                    .foregroundStyle(DS.Colors.textSecondary)

                Spacer()

                // Duration
                Text(formatDuration(record.durationMs))
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textTertiary)

                // Relative timestamp
                Text(relativeTime(record.startedAt))
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textQuaternary)
            }

            // Error text
            if let error = record.error {
                Text(error)
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.error)
                    .lineLimit(2)
            }

            // Output preview
            if let output = record.outputPreview {
                Text(output)
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.surfaceTertiary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.borderSubtle, lineWidth: 0.5)
        }
    }

    // MARK: - Data Loading

    private func loadHistory() async {
        isLoading = true
        defer { isLoading = false }

        // Fetch recent runs for this workflow, then get step-level data
        let recentRuns = await service.getRuns(workflowId: workflowId, limit: 20, storeId: storeId)

        var records: [StepRunRecord] = []
        for wfRun in recentRuns.prefix(15) {
            let stepRuns = await service.getStepRuns(runId: wfRun.id, storeId: storeId)
            for sr in stepRuns where sr.stepKey == stepKey {
                records.append(StepRunRecord(
                    id: sr.id,
                    runId: sr.runId,
                    status: sr.status,
                    durationMs: sr.durationMs,
                    startedAt: parseDate(sr.startedAt),
                    completedAt: parseDate(sr.completedAt),
                    error: sr.error,
                    outputPreview: sr.output.flatMap { prettyPreview($0) }
                ))
            }
        }

        runs = records.sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }

    private func parseDate(_ str: String?) -> Date? {
        guard let str else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.date(from: str) ?? ISO8601DateFormatter().date(from: str)
    }

    private func prettyPreview(_ output: [String: AnyCodable]) -> String? {
        let raw = output.mapValues(\.value)
        guard let data = try? JSONSerialization.data(withJSONObject: raw, options: []),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return String(str.prefix(120))
    }

    // MARK: - Helpers

    private func formatDuration(_ ms: Int?) -> String {
        guard let ms else { return "\u{2014}" }
        if ms < 1000 { return "\(ms)ms" }
        let seconds = Double(ms) / 1000.0
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes)m \(secs)s"
    }

    private func relativeTime(_ date: Date?) -> String {
        guard let date else { return "\u{2014}" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "success", "completed": return DS.Colors.success
        case "failed", "error": return DS.Colors.error
        case "running": return DS.Colors.accent
        case "cancelled": return DS.Colors.warning
        default: return DS.Colors.textTertiary
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status {
        case "success", "completed": return "checkmark.diamond.fill"
        case "failed", "error": return "exclamationmark.octagon.fill"
        case "running": return "rays"
        case "cancelled": return "xmark.seal.fill"
        default: return "questionmark.diamond"
        }
    }
}
