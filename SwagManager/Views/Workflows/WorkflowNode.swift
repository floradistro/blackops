import SwiftUI

// MARK: - Workflow Node
// Individual step node on the DAG canvas
// Glassmorphism design matching DesignSystem tokens

struct WorkflowNode: View {
    let node: GraphNode
    let isSelected: Bool
    let status: NodeStatus?

    private let nodeWidth: CGFloat = 200
    private let nodeMinHeight: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: icon + display name
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: WorkflowStepType.icon(for: node.type))
                    .font(DesignSystem.font(12, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(node.displayName)
                    .font(DS.Typography.monoCaption)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if node.isEntryPoint {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(DesignSystem.font(10))
                        .foregroundStyle(DS.Colors.accent)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.sm)

            // Step type label
            Text(WorkflowStepType.label(for: node.type))
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.xxs)

            // Divider
            Rectangle()
                .fill(DS.Colors.divider)
                .frame(height: 0.5)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)

            // Config detail + status
            HStack(spacing: DS.Spacing.xs) {
                // Show step key as monospaced detail
                Text(node.id)
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textQuaternary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                // Duration badge
                if let ms = status?.durationMs {
                    Text(formatDuration(ms))
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                // Status dot
                statusDot
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.sm)
        }
        .frame(width: nodeWidth)
        .background(.ultraThinMaterial, in: nodeShape)
        .overlay {
            nodeShape
                .strokeBorder(
                    isSelected ? DS.Colors.accent : DS.Colors.border,
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        }
        .shadow(
            color: statusShadowColor.opacity(0.2),
            radius: isSelected ? 8 : 4,
            y: 2
        )
        .animation(DS.Animation.fast, value: isSelected)
        .animation(DS.Animation.fast, value: status?.status)
    }

    // MARK: - Status Dot

    @ViewBuilder
    private var statusDot: some View {
        let color = statusDotColor

        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .overlay {
                if status?.status == "running" {
                    Circle()
                        .strokeBorder(color.opacity(0.5), lineWidth: 1)
                        .frame(width: 12, height: 12)
                        .scaleEffect(pulseScale)
                        .opacity(pulseOpacity)
                        .onAppear { startPulse() }
                }
            }
    }

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: CGFloat = 1.0

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.6
            pulseOpacity = 0.0
        }
    }

    // MARK: - Helpers

    private var nodeShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DS.Radius.lg)
    }

    private var iconColor: Color {
        switch node.type {
        case "condition": return DS.Colors.accent
        case "tool": return DS.Colors.orange
        case "code": return DS.Colors.purple
        case "agent": return DS.Colors.cyan
        case "delay": return DS.Colors.yellow
        case "approval": return DS.Colors.warning
        case "parallel": return DS.Colors.purple
        case "for_each": return DS.Colors.blue
        case "webhook_out": return DS.Colors.green
        case "sub_workflow": return DS.Colors.blue
        case "waitpoint": return DS.Colors.yellow
        case "transform": return DS.Colors.cyan
        default: return DS.Colors.textSecondary
        }
    }

    private var statusDotColor: Color {
        guard let status else { return DS.Colors.textQuaternary }
        switch status.status {
        case "success", "completed": return DS.Colors.success
        case "running": return DS.Colors.warning
        case "failed", "error": return DS.Colors.error
        case "pending": return DS.Colors.textQuaternary
        case "skipped": return DS.Colors.textTertiary
        default: return DS.Colors.textQuaternary
        }
    }

    private var statusShadowColor: Color {
        guard let status else { return .clear }
        switch status.status {
        case "running": return DS.Colors.warning
        case "failed", "error": return DS.Colors.error
        default: return .clear
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

// MARK: - Connection Port Indicators

struct NodePort: View {
    let isOutput: Bool

    var body: some View {
        Circle()
            .fill(DS.Colors.textQuaternary)
            .frame(width: 8, height: 8)
            .overlay {
                Circle()
                    .strokeBorder(DS.Colors.border, lineWidth: 0.5)
            }
    }
}
