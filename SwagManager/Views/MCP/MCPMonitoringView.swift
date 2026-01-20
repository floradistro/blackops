import SwiftUI

// MARK: - MCP Monitoring Dashboard
// Real-time monitoring and analytics for MCP servers

struct MCPMonitoringView: View {
    @StateObject private var monitor = MCPMonitor()
    @State private var selectedCategory: String?
    @State private var timeRange: TimeRange = .last24Hours
    @State private var selectedTab: MonitorTab = .overview

    enum MonitorTab: String, CaseIterable {
        case overview = "Overview"
        case history = "History"
    }

    enum TimeRange: String, CaseIterable {
        case lastHour = "Last Hour"
        case last24Hours = "Last 24 Hours"
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            tabBar

            Divider()

            // Content based on selected tab
            if selectedTab == .overview {
                overviewContent
            } else {
                ExecutionHistoryView()
            }
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
        .task {
            await monitor.loadStats(timeRange: timeRange)
        }
    }

    // MARK: - Tab Bar

    @ViewBuilder
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MonitorTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            selectedTab == tab ? VisualEffectBackground(material: .sidebar) : nil
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 4)
    }

    // MARK: - Overview Content

    @ViewBuilder
    private var overviewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header with controls
                headerSection

                Divider()

                // Stats Overview
                statsOverview

                Divider()

                // Category Breakdown
                categoryBreakdown

                Divider()

                // Recent Executions
                recentExecutions

                Divider()

                // Error Log
                errorLog
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("MCP Server Monitoring")
                    .font(.system(size: 20, weight: .semibold))

                Text("Real-time execution statistics and health monitoring")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Time Range", selection: $timeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: timeRange) { _, _ in
                Task { await monitor.loadStats(timeRange: timeRange) }
            }

            Button(action: { Task { await monitor.refresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
            }
        }
    }

    // MARK: - Stats Overview

    @ViewBuilder
    private var statsOverview: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DesignSystem.Spacing.md) {
            MCPStatCard(
                title: "Total Executions",
                value: "\(monitor.stats.totalExecutions)",
                icon: "play.circle.fill",
                color: .blue
            )

            MCPStatCard(
                title: "Success Rate",
                value: "\(String(format: "%.1f", monitor.stats.successRate))%",
                icon: "checkmark.circle.fill",
                color: .green
            )

            MCPStatCard(
                title: "Avg Response Time",
                value: "\(String(format: "%.0f", monitor.stats.avgResponseTime))ms",
                icon: "clock.fill",
                color: .orange
            )

            MCPStatCard(
                title: "Active Servers",
                value: "\(monitor.stats.activeServers)",
                icon: "server.rack",
                color: .purple
            )
        }
    }

    // MARK: - Category Breakdown

    @ViewBuilder
    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Usage by Category")
                .font(.system(size: 16, weight: .semibold))

            ForEach(monitor.stats.categoryStats, id: \.category) { stat in
                CategoryStatsRow(stat: stat)
            }
        }
    }

    // MARK: - Recent Executions

    @ViewBuilder
    private var recentExecutions: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Recent Executions")
                .font(.system(size: 16, weight: .semibold))

            ForEach(monitor.recentExecutions.prefix(10)) { execution in
                RecentExecutionRow(execution: execution)
            }
        }
    }

    // MARK: - Error Log

    @ViewBuilder
    private var errorLog: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Error Log")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Text("\(monitor.errors.count) errors")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            ForEach(monitor.errors.prefix(5)) { error in
                ErrorRow(error: error)
            }
        }
    }
}

// MARK: - MCP Stat Card

struct MCPStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(6)
    }
}

// MARK: - Category Stats Row

struct CategoryStatsRow: View {
    let stat: CategoryStat

    var body: some View {
        HStack {
            Text(stat.category)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 100, alignment: .leading)

            ZStack(alignment: .leading) {
                VisualEffectBackground(material: .sidebar)
                    .frame(height: 20)
                    .cornerRadius(4)

                Rectangle()
                    .fill(Color.blue)
                    .frame(width: stat.percentage * 300, height: 20)
                    .cornerRadius(4)
            }

            Text("\(stat.count)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            Text("\(String(format: "%.1f", stat.percentage * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

// MARK: - Recent Execution Row

struct RecentExecutionRow: View {
    let execution: ExecutionLog

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: execution.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(execution.success ? .green : .red)
                .font(.system(size: 12))

            Text(execution.serverName)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(width: 200, alignment: .leading)

            Text(execution.timestamp, style: .time)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            if let duration = execution.duration {
                Text("\(String(format: "%.0f", duration * 1000))ms")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(4)
    }
}

// MARK: - Error Row

struct ErrorRow: View {
    let error: ErrorLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 12))

                Text(error.serverName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))

                Spacer()

                Text(error.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Text(error.message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(VisualEffectBackground(material: .sidebar))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(4)
    }
}
