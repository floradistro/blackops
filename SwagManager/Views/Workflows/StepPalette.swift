import SwiftUI

// MARK: - Step Palette
// Horizontal strip of draggable step type chips at bottom of canvas
// Grouped by category: Execution, Flow, Integration, Human, Data

struct StepPalette: View {
    let onAddStep: (String) -> Void

    @State private var expandedCategory: String?

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            // Category tabs
            HStack(spacing: DS.Spacing.sm) {
                ForEach(WorkflowStepType.categories, id: \.self) { category in
                    Button {
                        withAnimation(DS.Animation.fast) {
                            expandedCategory = expandedCategory == category ? nil : category
                        }
                    } label: {
                        Text(category.uppercased())
                            .font(DS.Typography.monoSmall)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(
                                expandedCategory == category ? DS.Colors.accent.opacity(0.2) : DS.Colors.surfaceElevated,
                                in: RoundedRectangle(cornerRadius: DS.Radius.pill)
                            )
                            .foregroundStyle(expandedCategory == category ? DS.Colors.accent : DS.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            // Step chips for selected category (or all if none selected)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    let types = expandedCategory != nil
                        ? WorkflowStepType.types(in: expandedCategory!)
                        : WorkflowStepType.allTypes

                    ForEach(types, id: \.key) { stepType in
                        stepChip(stepType)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .glassSurface(material: .regular, tint: DS.Colors.surfaceTertiary, cornerRadius: DS.Radius.lg)
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        }
    }

    private func stepChip(_ stepType: (key: String, label: String, icon: String, category: String)) -> some View {
        Button {
            onAddStep(stepType.key)
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: stepType.icon)
                    .font(DesignSystem.font(11, weight: .medium))
                    .foregroundStyle(chipColor(stepType.category))

                Text(stepType.label)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                DS.Colors.surfaceElevated,
                in: RoundedRectangle(cornerRadius: DS.Radius.md)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Colors.border, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .help("Add \(stepType.label) step")
    }

    private func chipColor(_ category: String) -> Color {
        switch category {
        case "Execution": return DS.Colors.orange
        case "Flow": return DS.Colors.accent
        case "Integration": return DS.Colors.green
        case "Human": return DS.Colors.warning
        case "Data": return DS.Colors.cyan
        default: return DS.Colors.textSecondary
        }
    }
}
