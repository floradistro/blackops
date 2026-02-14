import SwiftUI

// MARK: - Step Palette
// Compact strip of step type buttons below canvas, grouped by category

struct StepPalette: View {
    let onAddStep: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Execution
                paletteGroup {
                    paletteButton("tool", icon: "hammer.fill", color: DS.Colors.orange, label: "Tool")
                    paletteButton("code", icon: "terminal.fill", color: DS.Colors.purple, label: "Code")
                    paletteButton("agent", icon: "brain.fill", color: DS.Colors.cyan, label: "Agent")
                    paletteButton("sub_workflow", icon: "arrow.triangle.branch", color: DS.Colors.accent, label: "Sub-Flow")
                }

                paletteDivider

                // Flow
                paletteGroup {
                    paletteButton("condition", icon: "diamond.fill", color: DS.Colors.accent, label: "Condition")
                    paletteButton("parallel", icon: "square.stack.3d.up.fill", color: DS.Colors.purple, label: "Parallel")
                    paletteButton("for_each", icon: "arrow.2.squarepath", color: DS.Colors.accent, label: "For Each")
                    paletteButton("delay", icon: "clock.fill", color: DS.Colors.warning, label: "Delay")
                }

                paletteDivider

                // Integration
                paletteGroup {
                    paletteButton("webhook_out", icon: "antenna.radiowaves.left.and.right", color: DS.Colors.green, label: "Webhook")
                    paletteButton("transform", icon: "arrow.left.arrow.right", color: DS.Colors.cyan, label: "Transform")
                }

                paletteDivider

                // Human
                paletteGroup {
                    paletteButton("approval", icon: "checkmark.seal.fill", color: DS.Colors.warning, label: "Approval")
                    paletteButton("waitpoint", icon: "pause.circle.fill", color: DS.Colors.warning, label: "Wait")
                }
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.surfaceTertiary)
        .overlay(alignment: .top) {
            Divider().opacity(0.3)
        }
    }

    private func paletteGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            content()
        }
    }

    private var paletteDivider: some View {
        Divider()
            .frame(height: 16)
            .opacity(0.2)
            .padding(.horizontal, DS.Spacing.xs)
    }

    private func paletteButton(_ stepType: String, icon: String, color: Color, label: String) -> some View {
        Button {
            onAddStep(stepType)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(DesignSystem.font(11, weight: .medium))
                    .foregroundStyle(color)

                Text(label)
                    .font(DesignSystem.font(9))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .frame(width: 52, height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Add \(label)")
    }
}
