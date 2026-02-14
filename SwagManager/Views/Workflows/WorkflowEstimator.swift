import SwiftUI

// MARK: - Estimation Data Types

struct StepEstimate: Identifiable {
    let id = UUID()
    let stepKey: String
    let stepType: String
    let estimatedDurationMs: Int
    let estimatedCostCents: Double
    let notes: String?
}

struct WorkflowEstimate {
    let steps: [StepEstimate]
    let totalDurationMs: Int
    let totalCostCents: Double
    let criticalPathMs: Int
    let hasHumanWait: Bool
}

// MARK: - Estimation Engine

enum WorkflowEstimationEngine {

    // MARK: Duration Lookup (milliseconds)

    static func baseDuration(for node: GraphNode) -> Int {
        switch node.type {
        case "tool":        return 500
        case "condition":   return 50
        case "code":        return 200
        case "agent":       return 5000
        case "delay":       return delayDuration(from: node.stepConfig)
        case "webhook_out": return 1000
        case "approval":    return 0
        case "waitpoint":   return 0
        case "parallel":    return 0   // resolved via children
        case "for_each":    return 0   // resolved via children
        case "sub_workflow": return 3000
        case "transform":  return 100
        case "noop":        return 10
        default:            return 100
        }
    }

    // MARK: Cost Lookup (cents)

    static func baseCost(for stepType: String) -> Double {
        switch stepType {
        case "agent":       return 2.0
        case "tool":        return 0.1
        case "webhook_out": return 0.05
        default:            return 0.01
        }
    }

    // MARK: Main Entry Point

    static func estimate(graph: WorkflowGraph) -> WorkflowEstimate {
        let nodeMap = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })

        // Build adjacency from edges
        var successors: [String: [String]] = [:]
        for edge in graph.edges {
            successors[edge.from, default: []].append(edge.to)
        }

        // Per-step estimates
        var stepEstimates: [StepEstimate] = []
        var hasHumanWait = false

        for node in graph.nodes {
            let duration = baseDuration(for: node)
            let cost = baseCost(for: node.type)
            let notes = stepNotes(for: node)

            if node.type == "approval" || node.type == "waitpoint" {
                hasHumanWait = true
            }

            stepEstimates.append(StepEstimate(
                stepKey: node.displayName,
                stepType: node.type,
                estimatedDurationMs: duration,
                estimatedCostCents: cost,
                notes: notes
            ))
        }

        let totalDuration = stepEstimates.reduce(0) { $0 + $1.estimatedDurationMs }
        let totalCost = stepEstimates.reduce(0.0) { $0 + $1.estimatedCostCents }

        // Critical path: BFS longest path from entry points
        let entryPoints = graph.nodes.filter { $0.isEntryPoint }.map { $0.id }
        let criticalPath = longestPath(
            entryPoints: entryPoints,
            successors: successors,
            nodeMap: nodeMap
        )

        return WorkflowEstimate(
            steps: stepEstimates,
            totalDurationMs: totalDuration,
            totalCostCents: totalCost,
            criticalPathMs: criticalPath,
            hasHumanWait: hasHumanWait
        )
    }

    // MARK: Helpers

    private static func delayDuration(from config: [String: AnyCodable]?) -> Int {
        guard let config else { return 1000 }
        if let seconds = config["seconds"]?.intValue {
            return seconds * 1000
        }
        if let seconds = config["seconds"]?.value as? Double {
            return Int(seconds * 1000)
        }
        return 1000
    }

    private static func stepNotes(for node: GraphNode) -> String? {
        switch node.type {
        case "agent":
            let name = node.stepConfig?["agent_name"]?.stringValue ?? "AI"
            return "\(name) inference call"
        case "delay":
            if let secs = node.stepConfig?["seconds"]?.intValue {
                return "Configured delay: \(secs)s"
            }
            return "Delay step"
        case "approval":
            return "Waiting for human approval"
        case "waitpoint":
            return "Waiting for external trigger"
        case "tool":
            let tool = node.stepConfig?["tool_name"]?.stringValue ?? "tool"
            return "API call: \(tool)"
        case "sub_workflow":
            let name = node.stepConfig?["workflow_name"]?.stringValue ?? "sub-workflow"
            return "Executes \(name)"
        case "for_each":
            return "Iterates ~3x (estimate)"
        case "parallel":
            return "Parallel branches (max of children)"
        default:
            return nil
        }
    }

    /// BFS-based longest path calculation from entry points.
    /// Sums durations along the longest serial chain.
    private static func longestPath(
        entryPoints: [String],
        successors: [String: [String]],
        nodeMap: [String: GraphNode]
    ) -> Int {
        var dist: [String: Int] = [:]

        // Initialize entry points with their own duration
        var queue: [String] = []
        for ep in entryPoints {
            let d = nodeMap[ep].map { baseDuration(for: $0) } ?? 0
            dist[ep] = d
            queue.append(ep)
        }

        // If no entry points, use all nodes
        if queue.isEmpty {
            for node in nodeMap.values {
                let d = baseDuration(for: node)
                dist[node.id] = d
                queue.append(node.id)
            }
        }

        // Topological relaxation (BFS)
        var idx = 0
        while idx < queue.count {
            let current = queue[idx]
            idx += 1
            let currentDist = dist[current] ?? 0

            for next in successors[current] ?? [] {
                let nextDuration = nodeMap[next].map { baseDuration(for: $0) } ?? 0
                let candidate = currentDist + nextDuration
                if candidate > (dist[next] ?? 0) {
                    dist[next] = candidate
                    queue.append(next)
                }
            }
        }

        return dist.values.max() ?? 0
    }
}

// MARK: - Duration Formatting

private func formatDuration(_ ms: Int) -> String {
    if ms <= 0 { return "0ms" }
    if ms < 1000 { return "< 1s" }

    let totalSeconds = ms / 1000
    if totalSeconds < 60 {
        return "\(totalSeconds)s"
    }

    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    if seconds == 0 {
        return "\(minutes)m"
    }
    return "\(minutes)m \(seconds)s"
}

private func formatDurationWithWait(_ ms: Int, hasHumanWait: Bool) -> String {
    let base = formatDuration(ms)
    if hasHumanWait {
        return "\(base) + human wait"
    }
    return base
}

private func formatCost(_ cents: Double) -> String {
    let dollars = cents / 100.0
    if dollars < 0.01 {
        return "< $0.01"
    }
    return String(format: "$%.2f", dollars)
}

// MARK: - Estimator Panel View

struct WorkflowEstimatorPanel: View {
    let graph: WorkflowGraph
    @State private var isExpanded = false

    private var estimate: WorkflowEstimate {
        WorkflowEstimationEngine.estimate(graph: graph)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            headerRow
            Divider()
                .background(DS.Colors.divider)
            summarySection
            Divider()
                .background(DS.Colors.divider)
            criticalPathRow
            Divider()
                .background(DS.Colors.divider)
            breakdownSection
        }
        .padding(DS.Spacing.lg)
        .frame(width: 280)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Colors.border, lineWidth: 0.5)
        }
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Colors.accent)
            Text("Estimated Execution")
                .font(DS.Typography.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(DS.Colors.textPrimary)
            Spacer()
        }
    }

    // MARK: Summary

    private var summarySection: some View {
        HStack(spacing: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Duration")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textTertiary)
                Text(formatDurationWithWait(estimate.totalDurationMs, hasHumanWait: estimate.hasHumanWait))
                    .font(DS.Typography.monoBody)
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                Text("Cost")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textTertiary)
                Text(formatCost(estimate.totalCostCents))
                    .font(DS.Typography.monoBody)
                    .foregroundStyle(DS.Colors.textPrimary)
            }
        }
    }

    // MARK: Critical Path

    private var criticalPathRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Critical Path")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textTertiary)
                Text(formatDuration(estimate.criticalPathMs))
                    .font(DS.Typography.monoCaption)
                    .foregroundStyle(DS.Colors.warning)
            }
            Spacer()
            Text("\(estimate.steps.count) steps")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.textTertiary)
        }
    }

    // MARK: Breakdown

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Button {
                withAnimation(DS.Animation.fast) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text("Step Breakdown")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                let sorted = estimate.steps.sorted { $0.estimatedCostCents > $1.estimatedCostCents }
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(sorted) { step in
                        stepRow(step)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func stepRow(_ step: StepEstimate) -> some View {
        let isExpensive = step.estimatedCostCents > 1.0
        return HStack(spacing: DS.Spacing.sm) {
            Image(systemName: WorkflowStepType.icon(for: step.stepType))
                .font(.system(size: 10))
                .foregroundStyle(isExpensive ? DS.Colors.warning : DS.Colors.textTertiary)
                .frame(width: 16, alignment: .center)

            Text(step.stepKey)
                .font(DS.Typography.caption2)
                .foregroundStyle(isExpensive ? DS.Colors.warning : DS.Colors.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Text(formatDuration(step.estimatedDurationMs))
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textTertiary)

            Text(formatStepCost(step.estimatedCostCents))
                .font(DS.Typography.monoSmall)
                .foregroundStyle(isExpensive ? DS.Colors.warning : DS.Colors.textQuaternary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, DS.Spacing.xxs)
        .padding(.horizontal, DS.Spacing.xs)
        .background(
            isExpensive
                ? DS.Colors.warning.opacity(0.06)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: DS.Radius.xs)
        )
    }

    private func formatStepCost(_ cents: Double) -> String {
        if cents < 0.01 { return "< 0.01c" }
        if cents >= 1.0 {
            return String(format: "%.1fc", cents)
        }
        return String(format: "%.2fc", cents)
    }
}
