import SwiftUI

// MARK: - Step Suggestion Model

struct StepSuggestion: Identifiable {
    let id = UUID()
    let stepType: String
    let label: String
    let icon: String
    let reason: String
}

// MARK: - Step Suggestions Engine

enum StepSuggestionsEngine {

    /// Returns context-aware suggestions for the next step based on node type and graph structure.
    static func suggestions(for node: GraphNode, in graph: WorkflowGraph) -> [StepSuggestion] {
        var results: [StepSuggestion] = []

        let hasSuccessEdge = graph.edges.contains { $0.from == node.id && $0.type == "success" }
        let hasFailureEdge = graph.edges.contains { $0.from == node.id && $0.type == "failure" }

        // If node has no success edge, prioritize adding a next step
        if !hasSuccessEdge {
            results.append(StepSuggestion(
                stepType: "tool",
                label: "Add Next Step",
                icon: "plus.rectangle.fill",
                reason: "This node has no success path"
            ))
        }

        // If node has no failure edge, suggest adding an error handler
        if !hasFailureEdge {
            results.append(StepSuggestion(
                stepType: "noop",
                label: "Add Error Handler",
                icon: "exclamationmark.warninglight.fill",
                reason: "No failure path defined"
            ))
        }

        // Context-aware suggestions based on node type
        let contextual = contextualSuggestions(for: node.type)
        for suggestion in contextual {
            // Avoid duplicating a step type already added above
            if !results.contains(where: { $0.stepType == suggestion.stepType && $0.label == suggestion.label }) {
                results.append(suggestion)
            }
        }

        // Cap at 4 suggestions total
        return Array(results.prefix(4))
    }

    // MARK: - Private

    private static func contextualSuggestions(for nodeType: String) -> [StepSuggestion] {
        switch nodeType {
        case "tool":
            return [
                StepSuggestion(stepType: "condition", label: "Add Condition Check", icon: "point.3.filled.connected.trianglepath.dotted", reason: "Check tool result before continuing"),
                StepSuggestion(stepType: "transform", label: "Transform Output", icon: "wand.and.rays", reason: "Reshape data for next step"),
                StepSuggestion(stepType: "tool", label: "Chain Another Tool", icon: "hammer.fill", reason: "Execute a follow-up action"),
            ]
        case "condition":
            return [
                StepSuggestion(stepType: "tool", label: "Execute on True", icon: "hammer.fill", reason: "Run tool when condition passes"),
                StepSuggestion(stepType: "delay", label: "Add Delay", icon: "hourglass", reason: "Wait before next action"),
                StepSuggestion(stepType: "agent", label: "AI Decision", icon: "brain.fill", reason: "Let agent decide next step"),
            ]
        case "agent":
            return [
                StepSuggestion(stepType: "condition", label: "Check Agent Output", icon: "point.3.filled.connected.trianglepath.dotted", reason: "Validate agent response"),
                StepSuggestion(stepType: "tool", label: "Execute Action", icon: "hammer.fill", reason: "Act on agent decision"),
                StepSuggestion(stepType: "approval", label: "Human Review", icon: "checkmark.seal.fill", reason: "Require approval before proceeding"),
            ]
        case "delay":
            return [
                StepSuggestion(stepType: "tool", label: "Proceed with Tool", icon: "hammer.fill", reason: "Execute after wait completes"),
                StepSuggestion(stepType: "webhook_out", label: "Send Notification", icon: "paperplane.fill", reason: "Notify external service"),
            ]
        case "approval":
            return [
                StepSuggestion(stepType: "tool", label: "Execute Approved Action", icon: "hammer.fill", reason: "Run tool after approval"),
                StepSuggestion(stepType: "condition", label: "Check Approval Result", icon: "point.3.filled.connected.trianglepath.dotted", reason: "Branch on approval outcome"),
            ]
        case "webhook_out":
            return [
                StepSuggestion(stepType: "condition", label: "Check Response", icon: "point.3.filled.connected.trianglepath.dotted", reason: "Validate webhook response"),
                StepSuggestion(stepType: "delay", label: "Wait for Callback", icon: "hourglass", reason: "Pause for external response"),
            ]
        case "transform":
            return [
                StepSuggestion(stepType: "tool", label: "Use Transformed Data", icon: "hammer.fill", reason: "Pass reshaped data to tool"),
                StepSuggestion(stepType: "condition", label: "Validate Output", icon: "point.3.filled.connected.trianglepath.dotted", reason: "Check transformed data"),
            ]
        case "parallel", "for_each":
            return [
                StepSuggestion(stepType: "transform", label: "Aggregate Results", icon: "wand.and.rays", reason: "Combine parallel outputs"),
                StepSuggestion(stepType: "condition", label: "Check All Succeeded", icon: "point.3.filled.connected.trianglepath.dotted", reason: "Verify all branches passed"),
            ]
        default:
            return [
                StepSuggestion(stepType: "tool", label: "Add Tool Step", icon: "hammer.fill", reason: "Execute an action"),
                StepSuggestion(stepType: "condition", label: "Add Condition", icon: "point.3.filled.connected.trianglepath.dotted", reason: "Branch the workflow"),
                StepSuggestion(stepType: "delay", label: "Add Delay", icon: "hourglass", reason: "Pause execution"),
            ]
        }
    }
}

// MARK: - Step Suggestions Panel

struct StepSuggestionsPanel: View {
    let node: GraphNode
    let graph: WorkflowGraph
    let onAdd: (String) -> Void
    let onDismiss: () -> Void

    @State private var isHovering: String?

    private var suggestions: [StepSuggestion] {
        StepSuggestionsEngine.suggestions(for: node, in: graph)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            header
            Divider().opacity(0.3)
            suggestionList
        }
        .padding(DS.Spacing.md)
        .frame(width: 220)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Colors.border, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .font(DesignSystem.font(11, weight: .medium))
                .foregroundStyle(DS.Colors.warning)

            Text("Suggested Next Steps")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.textSecondary)

            Spacer()

            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(DesignSystem.font(9, weight: .medium))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Suggestion List

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ForEach(suggestions) { suggestion in
                suggestionRow(suggestion)
            }
        }
    }

    private func suggestionRow(_ suggestion: StepSuggestion) -> some View {
        Button {
            onAdd(suggestion.stepType)
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: suggestion.icon)
                    .font(DesignSystem.font(11, weight: .medium))
                    .foregroundStyle(iconColor(for: suggestion.stepType))
                    .frame(width: 16, alignment: .center)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(suggestion.label)
                        .font(DS.Typography.caption1)
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text(suggestion.reason)
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isHovering == suggestion.id.uuidString
                    ? DS.Colors.surfaceHover
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DS.Animation.fast) {
                isHovering = hovering ? suggestion.id.uuidString : nil
            }
        }
    }

    // MARK: - Helpers

    private func iconColor(for stepType: String) -> Color {
        switch stepType {
        case "tool", "code", "agent", "sub_workflow":
            return DS.Colors.orange
        case "condition", "parallel", "for_each", "delay", "noop":
            return DS.Colors.accent
        case "webhook_out", "custom":
            return DS.Colors.green
        case "approval", "waitpoint":
            return DS.Colors.warning
        case "transform":
            return DS.Colors.cyan
        default:
            return DS.Colors.textSecondary
        }
    }
}
