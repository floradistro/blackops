import SwiftUI

// MARK: - Workflow Metrics Panel
// Right panel: run stats, latency, errors, step performance

struct WorkflowMetricsPanel: View {
    let storeId: UUID?
    let onDismiss: () -> Void

    @Environment(\.workflowService) private var service

    @State private var metrics: WorkflowMetrics?
    @State private var isLoading = true
    @State private var selectedPeriod = 30

    private let periods = [7, 14, 30, 90]

    var body: some View {
        VStack(spacing: 0) {
            // Inline controls
            HStack(spacing: DS.Spacing.sm) {
                Picker("", selection: $selectedPeriod) {
                    ForEach(periods, id: \.self) { p in
                        Text("\(p)d").tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Spacer()

                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DesignSystem.font(9, weight: .medium))
                        .foregroundStyle(DS.Colors.textQuaternary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)

            if isLoading {
                Spacer()
                ProgressView().scaleEffect(0.7)
                Spacer()
            } else if let metrics {
                ScrollView {
                    VStack(spacing: DS.Spacing.md) {
                        // Top stats grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: DS.Spacing.sm) {
                            metricCard("Total Runs", value: "\(metrics.totalRuns ?? 0)", icon: "play.circle.fill", color: DS.Colors.accent)
                            metricCard("Success Rate", value: formatPercent(metrics.successRate), icon: "checkmark.diamond.fill", color: DS.Colors.success)
                            metricCard("Avg Duration", value: formatMs(metrics.avgDurationMs), icon: "gauge.with.dots.needle.33percent", color: DS.Colors.warning)
                            metricCard("DLQ Count", value: "\(metrics.dlqCount ?? 0)", icon: "exclamationmark.warninglight.fill", color: DS.Colors.error)
                        }

                        // Latency percentiles
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text("LATENCY PERCENTILES")
                                .font(DS.Typography.monoHeader)
                                .foregroundStyle(DS.Colors.textTertiary)

                            HStack(spacing: DS.Spacing.md) {
                                percentileBar("p50", value: metrics.p50Ms, max: metrics.p99Ms ?? 1)
                                percentileBar("p95", value: metrics.p95Ms, max: metrics.p99Ms ?? 1)
                                percentileBar("p99", value: metrics.p99Ms, max: metrics.p99Ms ?? 1)
                            }
                        }
                        .padding(DS.Spacing.md)
                        .cardStyle(padding: 0, cornerRadius: DS.Radius.md)

                        // Top errors breakdown
                        topErrorsSection(metrics.topErrors)

                        // Step performance
                        stepPerformanceSection(metrics.stepStats)
                    }
                    .padding(DS.Spacing.md)
                }
            } else {
                Spacer()
                ContentUnavailableView {
                    Label("No Data", systemImage: "chart.bar.xaxis.ascending")
                } description: {
                    Text("Run the workflow to start collecting metrics.")
                }
                Spacer()
            }
        }
        .background(DS.Colors.surfaceTertiary)
        .task {
            await loadMetrics()
        }
        .onChange(of: selectedPeriod) { _, _ in
            Task { await loadMetrics() }
        }
    }

    private func loadMetrics() async {
        isLoading = true
        metrics = await service.getMetrics(days: selectedPeriod, storeId: storeId)
        isLoading = false
    }

    // MARK: - Components

    private func metricCard(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DesignSystem.font(16))
                .foregroundStyle(color)

            Text(value)
                .font(DS.Typography.title3)
                .foregroundStyle(DS.Colors.textPrimary)

            Text(label)
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .cardStyle(padding: 0, cornerRadius: DS.Radius.md)
    }

    private func percentileBar(_ label: String, value: Double?, max: Double) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(formatMs(value))
                .font(DS.Typography.monoCaption)
                .foregroundStyle(DS.Colors.textPrimary)

            GeometryReader { geo in
                let ratio = max > 0 ? (value ?? 0) / max : 0
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.Colors.surfaceElevated)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.Colors.accent.opacity(0.6))
                        .frame(height: geo.size.height * ratio)
                }
            }
            .frame(height: 60)

            Text(label)
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top Errors

    @ViewBuilder
    private func topErrorsSection(_ errors: [[String: AnyCodable]]?) -> some View {
        if let errors, !errors.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("TOP ERRORS")
                    .font(DS.Typography.monoHeader)
                    .foregroundStyle(DS.Colors.textTertiary)

                ForEach(Array(errors.prefix(5).enumerated()), id: \.offset) { _, entry in
                    let message = entry["error"]?.stringValue ?? entry["message"]?.stringValue ?? "Unknown error"
                    let count = entry["count"]?.intValue ?? (entry["count"]?.value as? Double).map { Int($0) } ?? 0

                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(DesignSystem.font(10, weight: .medium))
                            .foregroundStyle(DS.Colors.error)
                            .padding(.top, 2)

                        Text(message)
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .lineLimit(2)

                        Spacer()

                        Text("\(count)")
                            .font(DS.Typography.monoCaption)
                            .foregroundStyle(DS.Colors.error)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(DS.Colors.error.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.xs))
                    }

                    if entry["error"]?.stringValue != errors.last?["error"]?.stringValue {
                        Divider().opacity(0.2)
                    }
                }
            }
            .padding(DS.Spacing.md)
            .cardStyle(padding: 0, cornerRadius: DS.Radius.md)
        }
    }

    // MARK: - Step Performance

    @ViewBuilder
    private func stepPerformanceSection(_ stats: [[String: AnyCodable]]?) -> some View {
        if let stats, !stats.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("STEP PERFORMANCE")
                    .font(DS.Typography.monoHeader)
                    .foregroundStyle(DS.Colors.textTertiary)

                let sorted = stats.sorted { a, b in
                    extractDouble(a["avg_duration_ms"]) > extractDouble(b["avg_duration_ms"])
                }
                let maxDuration = sorted.compactMap({ extractDouble($0["avg_duration_ms"]) }).max() ?? 1

                ForEach(Array(sorted.prefix(8).enumerated()), id: \.offset) { _, entry in
                    let stepKey = entry["step_key"]?.stringValue ?? "unknown"
                    let avgMs = extractDouble(entry["avg_duration_ms"])
                    let runs = entry["run_count"]?.intValue ?? (entry["run_count"]?.value as? Double).map { Int($0) } ?? 0
                    let ratio = maxDuration > 0 ? avgMs / maxDuration : 0

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack {
                            Text(stepKey.replacingOccurrences(of: "_", with: " "))
                                .font(DS.Typography.monoSmall)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text(formatMs(avgMs))
                                .font(DS.Typography.monoCaption)
                                .foregroundStyle(DS.Colors.textSecondary)

                            if runs > 0 {
                                Text("\(runs) runs")
                                    .font(DS.Typography.monoSmall)
                                    .foregroundStyle(DS.Colors.textQuaternary)
                            }
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(DS.Colors.surfaceElevated)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(barColor(ratio: ratio).opacity(0.6))
                                    .frame(width: max(2, geo.size.width * ratio))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            .padding(DS.Spacing.md)
            .cardStyle(padding: 0, cornerRadius: DS.Radius.md)
        }
    }

    /// Extract a Double from an AnyCodable that might be Int or Double
    private func extractDouble(_ codable: AnyCodable?) -> Double {
        guard let codable else { return 0 }
        if let d = codable.value as? Double { return d }
        if let i = codable.intValue { return Double(i) }
        if let n = codable.value as? NSNumber { return n.doubleValue }
        return 0
    }

    /// Color for performance bars -- green for fast, yellow for mid, red for slow
    private func barColor(ratio: Double) -> Color {
        if ratio < 0.4 { return DS.Colors.success }
        if ratio < 0.75 { return DS.Colors.warning }
        return DS.Colors.error
    }

    // MARK: - Formatting

    private func formatPercent(_ value: Double?) -> String {
        guard let v = value else { return "-" }
        return String(format: "%.1f%%", v * 100)
    }

    private func formatMs(_ value: Double?) -> String {
        guard let v = value else { return "-" }
        if v < 1000 { return String(format: "%.0fms", v) }
        let seconds = v / 1000
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        return String(format: "%.0fm", seconds / 60)
    }
}
