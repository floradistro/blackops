import SwiftUI

// MARK: - Workflow Trace View
// Waterfall Gantt-chart timeline showing step execution order and duration
// Inspired by Temporal/Dagster run visualization

struct WorkflowTraceView: View {
    let steps: [StepRun]
    let runStatus: String
    @Binding var selectedStepKey: String?

    // MARK: - Computed Timeline Data

    private var sortedSteps: [StepRun] {
        steps.sorted { (a, b) in
            let aStart = parseISO8601(a.startedAt)
            let bStart = parseISO8601(b.startedAt)
            if let aDate = aStart, let bDate = bStart {
                return aDate < bDate
            }
            if aStart != nil { return true }
            if bStart != nil { return false }
            return a.stepKey < b.stepKey
        }
    }

    private var earliestDate: Date? {
        sortedSteps.compactMap { parseISO8601($0.startedAt) }.first
    }

    private var totalDurationMs: Double {
        guard let earliest = earliestDate else {
            return Double(steps.compactMap(\.durationMs).reduce(0, +))
        }
        var maxEnd: Date = earliest
        for step in steps {
            guard let start = parseISO8601(step.startedAt) else { continue }
            if let duration = step.durationMs {
                let end = start.addingTimeInterval(Double(duration) / 1000.0)
                if end > maxEnd { maxEnd = end }
            } else if let completed = parseISO8601(step.completedAt) {
                if completed > maxEnd { maxEnd = completed }
            } else {
                // Running step — use current time as end
                let now = Date()
                if now > maxEnd { maxEnd = now }
            }
        }
        return max(maxEnd.timeIntervalSince(earliest) * 1000, 1)
    }

    private var totalDurationFormatted: String {
        formatDuration(Int(totalDurationMs))
    }

    private var completedCount: Int {
        steps.filter { $0.status == "success" || $0.status == "completed" }.count
    }

    private var failedCount: Int {
        steps.filter { $0.status == "failed" || $0.status == "error" }.count
    }

    // Timeline rendering constants
    private let labelColumnWidth: CGFloat = 120
    private let rowHeight: CGFloat = 32
    private let timelineMinWidth: CGFloat = 400

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().opacity(0.3)

            if steps.isEmpty {
                emptyState
            } else {
                waterfall
            }
        }
        .glassBackground(cornerRadius: DS.Radius.lg)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            // Status badge
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(runStatusColor)
                    .frame(width: 8, height: 8)

                Text(runStatus.uppercased())
                    .font(DS.Typography.monoLabel)
                    .foregroundStyle(runStatusColor)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(runStatusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            // Total duration
            Label(totalDurationFormatted, systemImage: "clock")
                .font(DS.Typography.monoCaption)
                .foregroundStyle(DS.Colors.textSecondary)

            Spacer()

            // Step counts
            HStack(spacing: DS.Spacing.sm) {
                Text("\(steps.count) steps")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textTertiary)

                if completedCount > 0 {
                    Text("\(completedCount) done")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.success)
                }
                if failedCount > 0 {
                    Text("\(failedCount) failed")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.error)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Waterfall Chart

    private var waterfall: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                // Time axis
                timeAxis

                Divider().opacity(0.2)

                // Step rows
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(sortedSteps, id: \.id) { step in
                            stepRow(step)
                        }
                    }
                }
            }
            .frame(minWidth: labelColumnWidth + timelineMinWidth)
        }
    }

    // MARK: - Time Axis

    private var timeAxis: some View {
        HStack(spacing: 0) {
            // Label column spacer
            Color.clear
                .frame(width: labelColumnWidth)

            // Time markers
            GeometryReader { geo in
                let markers = timeMarkers(totalMs: totalDurationMs, width: geo.size.width)
                ForEach(markers, id: \.ms) { marker in
                    let xOffset = geo.size.width * marker.fraction
                    VStack(spacing: 0) {
                        Text(marker.label)
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.textQuaternary)
                    }
                    .position(x: xOffset, y: DS.Spacing.sm)
                }
            }
            .frame(minWidth: timelineMinWidth)
            .frame(height: DS.Spacing.xl)
        }
    }

    // MARK: - Step Row

    private func stepRow(_ step: StepRun) -> some View {
        let isSelected = selectedStepKey == step.stepKey

        return VStack(spacing: 0) {
            Button {
                withAnimation(DS.Animation.fast) {
                    selectedStepKey = selectedStepKey == step.stepKey ? nil : step.stepKey
                }
            } label: {
                HStack(spacing: 0) {
                    // Left label column
                    stepLabel(step)
                        .frame(width: labelColumnWidth, alignment: .leading)

                    // Right timeline area
                    GeometryReader { geo in
                        let barLayout = computeBarLayout(step: step, totalWidth: geo.size.width)

                        ZStack(alignment: .leading) {
                            // Grid line
                            Rectangle()
                                .fill(DS.Colors.divider)
                                .frame(height: 0.5)
                                .frame(maxWidth: .infinity)
                                .offset(y: rowHeight / 2)

                            // Duration bar
                            RoundedRectangle(cornerRadius: DS.Radius.xs)
                                .fill(stepStatusColor(step.status).opacity(0.7))
                                .frame(width: max(barLayout.width, DS.Spacing.xs), height: DS.Spacing.lg)
                                .offset(x: barLayout.offset)
                                .overlay(alignment: .leading) {
                                    // Duration label on bar if wide enough
                                    if barLayout.width > 44, let ms = step.durationMs {
                                        Text(formatDuration(ms))
                                            .font(DS.Typography.monoSmall)
                                            .foregroundStyle(DS.Colors.textPrimary)
                                            .padding(.leading, DS.Spacing.xs)
                                            .offset(x: barLayout.offset)
                                    }
                                }
                                .modifier(TracePulseModifier(isActive: step.status == "running"))
                        }
                        .frame(height: rowHeight)
                    }
                    .frame(minWidth: timelineMinWidth)
                    .frame(height: rowHeight)
                }
                .background(isSelected ? DS.Colors.selectionActive : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Detail popover (inline expansion)
            if isSelected {
                stepDetail(step)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Step Label (Left Column)

    private func stepLabel(_ step: StepRun) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            // Status dot
            Circle()
                .fill(stepStatusColor(step.status))
                .frame(width: 6, height: 6)

            // Step type icon
            Image(systemName: WorkflowStepType.icon(for: step.stepType))
                .font(DesignSystem.font(9))
                .foregroundStyle(DS.Colors.textTertiary)
                .frame(width: DS.Spacing.md)

            // Step key
            Text(step.stepKey)
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .frame(height: rowHeight)
    }

    // MARK: - Step Detail (Expanded Popover)

    private func stepDetail(_ step: StepRun) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Metadata row
            HStack(spacing: DS.Spacing.md) {
                detailTag("KEY", value: step.stepKey)
                detailTag("TYPE", value: WorkflowStepType.label(for: step.stepType))
                detailTag("STATUS", value: step.status.uppercased(), color: stepStatusColor(step.status))

                if let ms = step.durationMs {
                    detailTag("DURATION", value: formatDuration(ms))
                }

                if let startedAt = step.startedAt {
                    detailTag("STARTED", value: formatTimestamp(startedAt))
                }

                Spacer()
            }

            // Input preview
            if let input = step.input {
                jsonPreview("INPUT", json: input)
            }

            // Output preview
            if let output = step.output {
                jsonPreview("OUTPUT", json: output)
            }

            // Error
            if let error = step.error {
                HStack(alignment: .top, spacing: DS.Spacing.xs) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(DesignSystem.font(9))
                        .foregroundStyle(DS.Colors.error)
                    Text(error)
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.error)
                        .lineLimit(3)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .padding(.leading, labelColumnWidth)
        .background(DS.Colors.surfaceElevated)
    }

    private func detailTag(_ label: String, value: String, color: Color = DS.Colors.textSecondary) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(label)
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textQuaternary)
            Text(value)
                .font(DS.Typography.monoLabel)
                .foregroundStyle(color)
        }
    }

    private func jsonPreview(_ title: String, json: [String: AnyCodable]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textQuaternary)

            Text(truncatedJSON(json, maxLines: 3))
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textTertiary)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(DesignSystem.font(28))
                .foregroundStyle(DS.Colors.textQuaternary)

            Text("No Steps Executed")
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textTertiary)

            Text("Step execution data will appear here as the run progresses.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textQuaternary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.xxl)
    }

    // MARK: - Bar Layout Computation

    private struct BarLayout {
        let offset: CGFloat
        let width: CGFloat
    }

    private func computeBarLayout(step: StepRun, totalWidth: CGFloat) -> BarLayout {
        guard let earliest = earliestDate, totalDurationMs > 0 else {
            // Fallback: use durationMs proportionally
            let maxMs = Double(steps.compactMap(\.durationMs).max() ?? 1)
            let ms = Double(step.durationMs ?? 0)
            let width = totalWidth * CGFloat(ms / max(maxMs, 1))
            return BarLayout(offset: 0, width: max(width, DS.Spacing.xs))
        }

        let stepStart = parseISO8601(step.startedAt) ?? earliest
        let offsetMs = stepStart.timeIntervalSince(earliest) * 1000
        let offsetFraction = CGFloat(offsetMs / totalDurationMs)

        let durationMs: Double
        if let ms = step.durationMs {
            durationMs = Double(ms)
        } else if let completed = parseISO8601(step.completedAt) {
            durationMs = completed.timeIntervalSince(stepStart) * 1000
        } else if step.status == "running" {
            durationMs = Date().timeIntervalSince(stepStart) * 1000
        } else {
            durationMs = 0
        }

        let widthFraction = CGFloat(durationMs / totalDurationMs)

        return BarLayout(
            offset: totalWidth * offsetFraction,
            width: max(totalWidth * widthFraction, DS.Spacing.xs)
        )
    }

    // MARK: - Time Markers

    private struct TimeMarker: Hashable {
        let ms: Double
        let fraction: Double
        let label: String
    }

    private func timeMarkers(totalMs: Double, width: CGFloat) -> [TimeMarker] {
        guard totalMs > 0 else { return [] }

        // Choose interval based on total duration
        let interval: Double
        if totalMs <= 5_000 {
            interval = 1_000            // 1s markers
        } else if totalMs <= 30_000 {
            interval = 5_000            // 5s markers
        } else if totalMs <= 120_000 {
            interval = 15_000           // 15s markers
        } else if totalMs <= 600_000 {
            interval = 60_000           // 1m markers
        } else {
            interval = 300_000          // 5m markers
        }

        var markers: [TimeMarker] = []
        var ms: Double = 0
        while ms <= totalMs {
            let fraction = ms / totalMs
            markers.append(TimeMarker(
                ms: ms,
                fraction: fraction,
                label: formatAxisLabel(ms)
            ))
            ms += interval
        }
        return markers
    }

    private func formatAxisLabel(_ ms: Double) -> String {
        if ms == 0 { return "0s" }
        let seconds = ms / 1000
        if seconds < 60 {
            return seconds.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(seconds))s"
                : String(format: "%.1fs", seconds)
        }
        let minutes = Int(seconds / 60)
        let secs = Int(seconds) % 60
        if secs == 0 { return "\(minutes)m" }
        return "\(minutes)m\(secs)s"
    }

    // MARK: - Helpers

    private var runStatusColor: Color {
        switch runStatus {
        case "success", "completed": return DS.Colors.success
        case "running": return DS.Colors.accent
        case "failed", "error": return DS.Colors.error
        case "pending": return DS.Colors.textQuaternary
        case "paused": return DS.Colors.warning
        case "cancelled": return DS.Colors.textTertiary
        default: return DS.Colors.textQuaternary
        }
    }

    private func stepStatusColor(_ status: String) -> Color {
        switch status {
        case "success", "completed": return DS.Colors.success
        case "failed", "error": return DS.Colors.error
        case "running": return DS.Colors.accent
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

    private func formatTimestamp(_ iso: String) -> String {
        guard let date = parseISO8601(iso) else { return iso.prefix(19).description }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    private func parseISO8601(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        // Retry without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func truncatedJSON(_ json: [String: AnyCodable], maxLines: Int) -> String {
        let raw = json.mapValues(\.value)
        guard let data = try? JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return String(describing: raw)
        }
        let lines = str.components(separatedBy: "\n")
        if lines.count <= maxLines {
            return str
        }
        return lines.prefix(maxLines).joined(separator: "\n") + "\n..."
    }
}

// MARK: - Pulse Animation Modifier

private struct TracePulseModifier: ViewModifier {
    let isActive: Bool

    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? (isPulsing ? 0.5 : 1.0) : 1.0)
            .onAppear {
                guard isActive else { return }
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                    ) {
                        isPulsing = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPulsing = false
                    }
                }
            }
    }
}
