import SwiftUI

// MARK: - Canvas Toolbar
// Top bar for the workflow canvas with zoom, run, publish, layout controls

struct CanvasToolbar: View {
    let workflow: Workflow
    let storeId: UUID?

    @Binding var zoom: CGFloat
    @Binding var showPalette: Bool

    let onRun: () -> Void
    let onPublish: () -> Void
    let onAutoLayout: () -> Void
    let onFitToView: () -> Void

    @State private var isRunning = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Workflow name
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: workflow.icon ?? workflow.triggerIcon)
                    .font(DesignSystem.font(12))
                    .foregroundStyle(DS.Colors.accent)

                Text(workflow.name)
                    .font(DS.Typography.monoCaption)
                    .foregroundStyle(DS.Colors.textPrimary)

                // Status badge
                Text(workflow.status.uppercased())
                    .font(DS.Typography.monoSmall)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(
                        statusColor.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: DS.Radius.xs)
                    )
                    .foregroundStyle(statusColor)
            }

            Spacer()

            // Layout controls
            HStack(spacing: DS.Spacing.xs) {
                Button { onAutoLayout() } label: {
                    Image(systemName: "rectangle.3.group")
                        .font(DesignSystem.font(11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.textSecondary)
                .help("Auto-layout nodes")

                Button { onFitToView() } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(DesignSystem.font(11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.textSecondary)
                .help("Fit to view")
            }

            // Zoom controls
            HStack(spacing: DS.Spacing.xs) {
                Button {
                    withAnimation(DS.Animation.fast) { zoom = max(0.25, zoom - 0.25) }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(DesignSystem.font(11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.textSecondary)

                Text("\(Int(zoom * 100))%")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .frame(width: 36)

                Button {
                    withAnimation(DS.Animation.fast) { zoom = min(3.0, zoom + 0.25) }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(DesignSystem.font(11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.textSecondary)
            }

            Divider()
                .frame(height: 16)
                .opacity(0.3)

            // Palette toggle
            Button {
                withAnimation(DS.Animation.fast) { showPalette.toggle() }
            } label: {
                Image(systemName: showPalette ? "tray.fill" : "tray")
                    .font(DesignSystem.font(11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(showPalette ? DS.Colors.accent : DS.Colors.textSecondary)
            .help("Toggle step palette")

            Divider()
                .frame(height: 16)
                .opacity(0.3)

            // Publish
            Button { onPublish() } label: {
                HStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "arrow.up.circle")
                        .font(DesignSystem.font(11))
                    Text("Publish")
                        .font(DS.Typography.monoLabel)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.Colors.textSecondary)
            .help("Publish version snapshot")

            // Run
            Button { onRun() } label: {
                HStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "play.fill")
                        .font(DesignSystem.font(10))
                    Text("Run")
                        .font(DS.Typography.monoLabel)
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.success.opacity(0.2), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .foregroundStyle(DS.Colors.success)
            }
            .buttonStyle(.plain)
            .help("Start workflow run")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background {
            DS.Colors.surfaceTertiary
                .overlay(alignment: .bottom) {
                    Divider().opacity(0.3)
                }
        }
    }

    private var statusColor: Color {
        switch workflow.status {
        case "active": return DS.Colors.success
        case "draft": return DS.Colors.warning
        default: return DS.Colors.textTertiary
        }
    }
}
