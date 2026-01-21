import SwiftUI
import Charts

// MARK: - Modern macOS-style MCP Monitoring Dashboard
// Following Apple HIG - minimal, polished, informative

struct MCPMonitoringView_v2: View {
    let serverName: String?
    @StateObject private var monitor: MCPMonitor
    @State private var timeRange: TimeRange = .last24Hours
    @State private var selectedMetric: MetricType = .executions

    init(serverName: String? = nil) {
        self.serverName = serverName
        _monitor = StateObject(wrappedValue: MCPMonitor(serverName: serverName))
    }

    enum TimeRange: String, CaseIterable {
        case lastHour = "1H"
        case last24Hours = "24H"
        case last7Days = "7D"
        case last30Days = "30D"

        var title: String {
            switch self {
            case .lastHour: return "Last Hour"
            case .last24Hours: return "Last 24 Hours"
            case .last7Days: return "Last 7 Days"
            case .last30Days: return "Last 30 Days"
            }
        }
    }

    enum MetricType: String, CaseIterable {
        case executions = "Executions"
        case performance = "Performance"
        case reliability = "Reliability"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with time picker
                headerSection

                // Hero metrics (big numbers that matter)
                heroMetrics

                // Status overview
                if monitor.stats.totalExecutions > 0 {
                    statusOverview

                    // Recent activity
                    recentActivity

                    // Errors (if any)
                    if !monitor.errors.isEmpty {
                        errorSection
                    }
                } else {
                    emptyState
                }
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await monitor.loadStats(timeRange: convertTimeRange(timeRange))
        }
        .onChange(of: timeRange) { _, newValue in
            Task { await monitor.loadStats(timeRange: convertTimeRange(newValue)) }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let serverName = serverName {
                    Text(serverName)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                } else {
                    Text("All Tools")
                        .font(.system(size: 22, weight: .semibold))
                }

                Text("Monitoring Dashboard")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Time range picker (macOS style segmented control)
            Picker("", selection: $timeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Button(action: { Task { await monitor.refresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
    }

    // MARK: - Hero Metrics

    @ViewBuilder
    private var heroMetrics: some View {
        HStack(spacing: 16) {
            // Total executions
            HeroMetricCard(
                value: formatNumber(monitor.stats.totalExecutions),
                label: "Executions",
                icon: "play.circle.fill",
                color: .blue,
                trend: nil
            )

            // Success rate
            HeroMetricCard(
                value: String(format: "%.1f%%", monitor.stats.successRate),
                label: "Success Rate",
                icon: healthIcon(for: monitor.stats.successRate),
                color: healthColor(for: monitor.stats.successRate),
                trend: nil
            )

            // Avg response time
            HeroMetricCard(
                value: formatDuration(monitor.stats.avgResponseTime),
                label: "Avg Response",
                icon: "clock.fill",
                color: responseTimeColor(monitor.stats.avgResponseTime),
                trend: nil
            )
        }
    }

    // MARK: - Status Overview

    @ViewBuilder
    private var statusOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status Overview")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }

            HStack(spacing: 12) {
                // Health indicator
                StatusCard(
                    title: "Health",
                    value: healthStatus,
                    icon: healthStatusIcon,
                    color: healthStatusColor
                )

                // Performance indicator
                StatusCard(
                    title: "Performance",
                    value: performanceStatus,
                    icon: performanceStatusIcon,
                    color: performanceStatusColor
                )

                // Last execution
                if let lastExecution = monitor.recentExecutions.first {
                    StatusCard(
                        title: "Last Run",
                        value: timeAgo(lastExecution.timestamp),
                        icon: "clock.arrow.circlepath",
                        color: .secondary
                    )
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Recent Activity

    @ViewBuilder
    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(monitor.recentExecutions.count) executions")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 1) {
                ForEach(monitor.recentExecutions.prefix(10)) { execution in
                    ModernExecutionRow(execution: execution)
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recent Errors", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.red)
                Spacer()
                Text("\(monitor.errors.count) errors")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(monitor.errors.prefix(5)) { error in
                    ModernErrorRow(error: error)
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text("No Execution Data")
                    .font(.system(size: 17, weight: .semibold))

                Text("This tool hasn't been used yet")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            if serverName != nil {
                Button("Test Now") {
                    // TODO: Trigger test
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(60)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func convertTimeRange(_ range: TimeRange) -> MCPMonitoringView.TimeRange {
        switch range {
        case .lastHour: return .lastHour
        case .last24Hours: return .last24Hours
        case .last7Days: return .last7Days
        case .last30Days: return .last30Days
        }
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            return String(format: "%.1fK", Double(num) / 1000.0)
        }
        return "\(num)"
    }

    private func formatDuration(_ ms: Double) -> String {
        if ms < 1000 {
            return "\(Int(ms))ms"
        } else {
            return String(format: "%.1fs", ms / 1000.0)
        }
    }

    private func healthIcon(for successRate: Double) -> String {
        if successRate >= 95 { return "checkmark.circle.fill" }
        if successRate >= 80 { return "exclamationmark.circle.fill" }
        return "xmark.circle.fill"
    }

    private func healthColor(for successRate: Double) -> Color {
        if successRate >= 95 { return .green }
        if successRate >= 80 { return .orange }
        return .red
    }

    private func responseTimeColor(_ ms: Double) -> Color {
        if ms < 100 { return .green }
        if ms < 1000 { return .blue }
        if ms < 3000 { return .orange }
        return .red
    }

    private var healthStatus: String {
        let rate = monitor.stats.successRate
        if rate >= 95 { return "Excellent" }
        if rate >= 80 { return "Good" }
        if rate >= 60 { return "Fair" }
        return "Poor"
    }

    private var healthStatusIcon: String {
        let rate = monitor.stats.successRate
        if rate >= 95 { return "checkmark.seal.fill" }
        if rate >= 80 { return "checkmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }

    private var healthStatusColor: Color {
        let rate = monitor.stats.successRate
        if rate >= 95 { return .green }
        if rate >= 80 { return .blue }
        return .orange
    }

    private var performanceStatus: String {
        let ms = monitor.stats.avgResponseTime
        if ms < 100 { return "Excellent" }
        if ms < 1000 { return "Good" }
        if ms < 3000 { return "Fair" }
        return "Slow"
    }

    private var performanceStatusIcon: String {
        let ms = monitor.stats.avgResponseTime
        if ms < 100 { return "bolt.fill" }
        if ms < 1000 { return "hare.fill" }
        return "tortoise.fill"
    }

    private var performanceStatusColor: Color {
        let ms = monitor.stats.avgResponseTime
        if ms < 100 { return .green }
        if ms < 1000 { return .blue }
        if ms < 3000 { return .orange }
        return .red
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86400))d ago"
    }
}

// MARK: - Hero Metric Card

struct HeroMetricCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    let trend: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                Spacer()
                if let trend = trend {
                    Text(trend)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(value)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Modern Execution Row

struct ModernExecutionRow: View {
    let execution: ExecutionLog

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(execution.success ? Color.green : Color.red)
                .frame(width: 6, height: 6)

            // Timestamp
            Text(timeAgo(execution.timestamp))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            // Duration
            if let duration = execution.duration {
                Text(formatDuration(duration * 1000))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(durationColor(duration * 1000))
                    .frame(width: 60, alignment: .trailing)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(6)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86400))d"
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

// MARK: - Modern Error Row

struct ModernErrorRow: View {
    let error: ErrorLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(error.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(timeAgo(error.timestamp))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86400))d ago"
    }
}
