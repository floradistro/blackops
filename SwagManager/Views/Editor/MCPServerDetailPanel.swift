import SwiftUI

// MARK: - MCP Server Detail Panel
// Following Apple engineering standards

struct MCPServerDetailPanel: View {
    let server: MCPServer
    @ObservedObject var store: EditorStore
    @State private var showEditSheet = false
    @State private var showLogsSheet = false

    var body: some View {
        ScrollView {
            content
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header with status and actions
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: server.typeIcon)
                                .font(.system(size: 24))
                                .foregroundStyle(server.typeColor)

                            Text(server.displayName)
                                .font(DesignSystem.Typography.title2)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }

                        if let description = server.description {
                            Text(description)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }

                        Text(server.serverType.displayName)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    Spacer()

                    // Status indicator
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Circle()
                                .fill(server.statusColor)
                                .frame(width: 8, height: 8)
                            Text(server.status.displayName)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundStyle(server.statusColor)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(server.statusColor.opacity(0.15))
                        .clipShape(Capsule())

                        // Enabled toggle
                        Toggle(isOn: .constant(server.enabled)) {
                            Text("Enabled")
                                .font(DesignSystem.Typography.caption2)
                        }
                        .toggleStyle(.switch)
                        .disabled(true)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))

                // Action buttons
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if server.canStart {
                        ActionButton(
                            title: "Start",
                            icon: "play.circle.fill",
                            color: .green
                        ) {
                            Task { await store.startMCPServer(server) }
                        }
                    }

                    if server.canStop {
                        ActionButton(
                            title: "Stop",
                            icon: "stop.circle.fill",
                            color: .red
                        ) {
                            Task { await store.stopMCPServer(server) }
                        }
                    }

                    if server.status == .running {
                        ActionButton(
                            title: "Restart",
                            icon: "arrow.clockwise.circle.fill",
                            color: .orange
                        ) {
                            Task { await store.restartMCPServer(server) }
                        }
                    }

                    Spacer()

                    ActionButton(
                        title: "Logs",
                        icon: "text.alignleft",
                        color: .blue
                    ) {
                        showLogsSheet = true
                    }

                    ActionButton(
                        title: "Edit",
                        icon: "pencil.circle.fill",
                        color: .purple
                    ) {
                        showEditSheet = true
                    }
                }

                // Configuration details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("CONFIGURATION")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .tracking(0.5)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        ConfigRow(label: "Command", value: server.command)

                        if !server.args.isEmpty {
                            ConfigRow(label: "Arguments", value: server.args.joined(separator: " "))
                        }

                        if let env = server.env, !env.isEmpty {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Environment Variables:")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(Array(env.keys.sorted()), id: \.self) { key in
                                        HStack {
                                            Text(key)
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                            Text("=")
                                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                            Text(env[key]?.starts(with: "***") == true ? "***" : env[key] ?? "")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                        }
                                    }
                                }
                                .padding(DesignSystem.Spacing.sm)
                                .background(DesignSystem.Colors.surfaceSecondary.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                            }
                        }

                        ConfigRow(label: "Auto-start", value: server.autoStart ? "Yes" : "No")
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))

                // Status & Health
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("STATUS & HEALTH")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .tracking(0.5)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        if let lastHealthCheck = server.lastHealthCheck {
                            StatusRow(
                                icon: "checkmark.circle",
                                label: "Last Health Check",
                                value: formatDate(lastHealthCheck),
                                color: .green
                            )
                        }

                        if let lastError = server.lastError {
                            StatusRow(
                                icon: "exclamationmark.triangle",
                                label: "Last Error",
                                value: lastError,
                                color: .red
                            )
                        }

                        StatusRow(
                            icon: "calendar",
                            label: "Created",
                            value: formatDate(server.createdAt),
                            color: .gray
                        )

                        StatusRow(
                            icon: "clock",
                            label: "Updated",
                            value: formatDate(server.updatedAt),
                            color: .gray
                        )
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))

                // Danger zone
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("DANGER ZONE")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.red)
                        .tracking(0.5)

                    Button(action: {
                        Task {
                            await store.deleteMCPServer(server)
                            store.closeMCPServerTab(server)
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                            Text("Delete Server")
                                .font(DesignSystem.Typography.caption1Medium)
                            Spacer()
                        }
                        .foregroundStyle(.red)
                        .padding(DesignSystem.Spacing.md)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    }
                    .buttonStyle(.plain)
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.surface)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Config Row

struct ConfigRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .textSelection(.enabled)
                .padding(DesignSystem.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.surfaceSecondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
        }
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                Text(value)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Contact Row (reused from LocationDetailPanel pattern)

struct MCPContactRow: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .frame(width: 20)

            Text(value)
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Spacer()
        }
    }
}
