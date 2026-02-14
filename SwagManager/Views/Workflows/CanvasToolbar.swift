import SwiftUI

// MARK: - Canvas Floating Overlays
// Totally minimal — floats on top of the canvas, no chrome
// Title pill top-left, fit button top-right, play dock bottom-center

struct CanvasOverlay: View {
    let workflow: Workflow

    let onRun: () -> Void
    let onFitToView: () -> Void

    @State private var runHovered = false

    var body: some View {
        ZStack {
            // Top: title pill left, fit button right
            VStack {
                HStack {
                    titlePill
                    Spacer()
                    fitButton
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.sm)
                Spacer()
            }

            // Bottom-center: floating play dock (Apple Music style)
            VStack {
                Spacer()
                playDock
                    .padding(.bottom, DS.Spacing.lg)
            }
        }
        .allowsHitTesting(true)
    }

    // MARK: - Title Pill (top-left)

    private var titlePill: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: workflow.icon ?? workflow.triggerIcon)
                .font(DesignSystem.font(11))
                .foregroundStyle(DS.Colors.accent)

            Text(workflow.name)
                .font(DS.Typography.monoCaption)
                .foregroundStyle(DS.Colors.textPrimary)

            Text(workflow.status.uppercased())
                .font(DS.Typography.monoSmall)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    statusColor.opacity(0.2),
                    in: RoundedRectangle(cornerRadius: DS.Radius.xs)
                )
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    // MARK: - Fit Button (top-right)

    private var fitButton: some View {
        Button { onFitToView() } label: {
            Image(systemName: "viewfinder")
                .font(DesignSystem.font(11))
        }
        .buttonStyle(.plain)
        .foregroundStyle(DS.Colors.textSecondary)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .help("Fit to view")
    }

    // MARK: - Play Dock (bottom-center, Apple Music style)

    private var playDock: some View {
        Button { onRun() } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(DS.Colors.success.gradient)
                        .shadow(color: DS.Colors.success.opacity(runHovered ? 0.5 : 0.3), radius: runHovered ? 20 : 10, y: 4)
                )
                .scaleEffect(runHovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { runHovered = $0 }
        .animation(DS.Animation.fast, value: runHovered)
        .help("Run workflow")
    }

    private var statusColor: Color {
        switch workflow.status {
        case "active": return DS.Colors.success
        case "draft": return DS.Colors.warning
        default: return DS.Colors.textTertiary
        }
    }
}
