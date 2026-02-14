import SwiftUI

// MARK: - Workflow Dependency Model

struct WorkflowDependency: Identifiable, Hashable {
    var id: String { "\(fromWorkflowId)-\(toWorkflowId)-\(viaStepKey)" }
    let fromWorkflowId: String
    let fromWorkflowName: String
    let toWorkflowId: String
    let toWorkflowName: String
    let viaStepKey: String
}

// MARK: - Dependency Analyzer

enum DependencyAnalyzer {

    /// Scans all workflow graphs for sub_workflow nodes and builds a dependency list.
    static func analyze(workflows: [Workflow], graphs: [String: WorkflowGraph]) -> [WorkflowDependency] {
        let workflowLookup = Dictionary(uniqueKeysWithValues: workflows.map { ($0.id, $0) })
        var results: [WorkflowDependency] = []

        for workflow in workflows {
            guard let graph = graphs[workflow.id] else { continue }

            for node in graph.nodes where node.type == "sub_workflow" {
                guard let config = node.stepConfig,
                      let targetId = config["sub_workflow_id"]?.value as? String,
                      !targetId.isEmpty else { continue }

                let targetName = workflowLookup[targetId]?.name ?? "Unknown"

                results.append(WorkflowDependency(
                    fromWorkflowId: workflow.id,
                    fromWorkflowName: workflow.name,
                    toWorkflowId: targetId,
                    toWorkflowName: targetName,
                    viaStepKey: node.displayName
                ))
            }
        }

        return results
    }
}

// MARK: - Dependency Map View

struct WorkflowDependencyMap: View {
    let workflows: [Workflow]
    let graphs: [String: WorkflowGraph]
    var onSelectWorkflow: (String) -> Void = { _ in }

    @State private var dependencies: [WorkflowDependency] = []
    @State private var hoveredNodeId: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)

            if dependencies.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        dependencyCanvas
                            .frame(height: canvasHeight)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.top, DS.Spacing.md)

                        Divider().opacity(0.2).padding(.horizontal, DS.Spacing.md)

                        dependencyList
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.bottom, DS.Spacing.md)
                    }
                }
            }
        }
        .background(DS.Colors.surfaceTertiary)
        .onAppear { dependencies = DependencyAnalyzer.analyze(workflows: workflows, graphs: graphs) }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "diagram.predecessorsuccessor")
                .font(DesignSystem.font(12, weight: .medium))
                .foregroundStyle(DS.Colors.accent)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("WORKFLOW DEPENDENCIES")
                    .font(DS.Typography.monoHeader)
                    .foregroundStyle(DS.Colors.textTertiary)
                Text("\(dependencies.count) connections")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textQuaternary)
            }

            Spacer()
        }
        .padding(DS.Spacing.md)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            ContentUnavailableView {
                Label("No Dependencies", systemImage: "arrow.triangle.branch")
            } description: {
                Text("No cross-workflow references found.")
            }
            Spacer()
        }
    }

    // MARK: - Canvas

    private var involvedWorkflowIds: [String] {
        var ids = Set<String>()
        for dep in dependencies {
            ids.insert(dep.fromWorkflowId)
            ids.insert(dep.toWorkflowId)
        }
        return Array(ids)
    }

    private var sourceIds: [String] {
        let sources = Set(dependencies.map(\.fromWorkflowId))
        return Array(sources).sorted()
    }

    private var targetIds: [String] {
        let targets = Set(dependencies.map(\.toWorkflowId))
        return Array(targets).sorted()
    }

    private let nodeWidth: CGFloat = 160
    private let nodeHeight: CGFloat = 48
    private let columnGap: CGFloat = 200

    private var canvasHeight: CGFloat {
        let maxRows = max(sourceIds.count, targetIds.count, 1)
        return CGFloat(maxRows) * (nodeHeight + DS.Spacing.lg) + DS.Spacing.lg
    }

    private func sourceY(for index: Int) -> CGFloat {
        let totalHeight = CGFloat(sourceIds.count) * (nodeHeight + DS.Spacing.lg) - DS.Spacing.lg
        let offset = (canvasHeight - totalHeight) / 2
        return offset + CGFloat(index) * (nodeHeight + DS.Spacing.lg) + nodeHeight / 2
    }

    private func targetY(for index: Int) -> CGFloat {
        let totalHeight = CGFloat(targetIds.count) * (nodeHeight + DS.Spacing.lg) - DS.Spacing.lg
        let offset = (canvasHeight - totalHeight) / 2
        return offset + CGFloat(index) * (nodeHeight + DS.Spacing.lg) + nodeHeight / 2
    }

    private var dependencyCanvas: some View {
        GeometryReader { geo in
            let leftX = DS.Spacing.md
            let rightX = geo.size.width - nodeWidth - DS.Spacing.md

            ZStack {
                // Bezier connections
                ForEach(dependencies) { dep in
                    let srcIdx = sourceIds.firstIndex(of: dep.fromWorkflowId) ?? 0
                    let tgtIdx = targetIds.firstIndex(of: dep.toWorkflowId) ?? 0
                    let startPoint = CGPoint(x: leftX + nodeWidth, y: sourceY(for: srcIdx))
                    let endPoint = CGPoint(x: rightX, y: targetY(for: tgtIdx))

                    connectionPath(from: startPoint, to: endPoint)
                        .stroke(
                            DS.Colors.accent.opacity(hoveredNodeId == dep.fromWorkflowId || hoveredNodeId == dep.toWorkflowId ? 0.9 : 0.5),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )

                    // Arrowhead
                    arrowHead(at: endPoint, from: startPoint)
                        .fill(DS.Colors.accent.opacity(hoveredNodeId == dep.fromWorkflowId || hoveredNodeId == dep.toWorkflowId ? 0.9 : 0.5))
                }

                // Source nodes (left)
                ForEach(Array(sourceIds.enumerated()), id: \.element) { index, wfId in
                    let workflow = workflows.first { $0.id == wfId }
                    let stepCount = graphs[wfId]?.nodes.count ?? 0

                    workflowNode(
                        name: workflow?.name ?? "Unknown",
                        stepCount: stepCount,
                        icon: workflow?.icon,
                        workflowId: wfId
                    )
                    .position(x: leftX + nodeWidth / 2, y: sourceY(for: index))
                }

                // Target nodes (right)
                ForEach(Array(targetIds.enumerated()), id: \.element) { index, wfId in
                    let workflow = workflows.first { $0.id == wfId }
                    let stepCount = graphs[wfId]?.nodes.count ?? 0

                    workflowNode(
                        name: workflow?.name ?? "Unknown",
                        stepCount: stepCount,
                        icon: workflow?.icon,
                        workflowId: wfId
                    )
                    .position(x: rightX + nodeWidth / 2, y: targetY(for: index))
                }
            }
        }
    }

    // MARK: - Workflow Node

    private func workflowNode(name: String, stepCount: Int, icon: String?, workflowId: String) -> some View {
        Button {
            onSelectWorkflow(workflowId)
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon ?? "flowchart")
                    .font(DesignSystem.font(11, weight: .medium))
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(name)
                        .font(DS.Typography.monoCaption)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    Text("\(stepCount) steps")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textQuaternary)
                }

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .frame(width: nodeWidth, height: nodeHeight)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(
                        hoveredNodeId == workflowId ? DS.Colors.accent.opacity(0.5) : DS.Colors.border,
                        lineWidth: 0.5
                    )
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredNodeId = isHovered ? workflowId : nil
        }
    }

    // MARK: - Connection Path

    private func connectionPath(from start: CGPoint, to end: CGPoint) -> Path {
        Path { path in
            path.move(to: start)
            let controlOffset = (end.x - start.x) * 0.5
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x + controlOffset, y: start.y),
                control2: CGPoint(x: end.x - controlOffset, y: end.y)
            )
        }
    }

    private func arrowHead(at point: CGPoint, from start: CGPoint) -> Path {
        let size: CGFloat = 6
        let angle = atan2(point.y - start.y, point.x - start.x)
        let p1 = CGPoint(
            x: point.x - size * cos(angle - .pi / 6),
            y: point.y - size * sin(angle - .pi / 6)
        )
        let p2 = CGPoint(
            x: point.x - size * cos(angle + .pi / 6),
            y: point.y - size * sin(angle + .pi / 6)
        )
        return Path { path in
            path.move(to: point)
            path.addLine(to: p1)
            path.addLine(to: p2)
            path.closeSubpath()
        }
    }

    // MARK: - Dependency List

    private var dependencyList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("CONNECTIONS")
                .font(DS.Typography.monoHeader)
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.bottom, DS.Spacing.xxs)

            ForEach(dependencies) { dep in
                dependencyRow(dep)
            }
        }
    }

    private func dependencyRow(_ dep: WorkflowDependency) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            // Source
            Button { onSelectWorkflow(dep.fromWorkflowId) } label: {
                Text(dep.fromWorkflowName)
                    .font(DS.Typography.monoCaption)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Image(systemName: "arrow.right")
                .font(DesignSystem.font(9, weight: .medium))
                .foregroundStyle(DS.Colors.accent)

            // Target
            Button { onSelectWorkflow(dep.toWorkflowId) } label: {
                Text(dep.toWorkflowName)
                    .font(DS.Typography.monoCaption)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Spacer()

            // Step key badge
            Text(dep.viaStepKey)
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.vertical, DS.Spacing.xxs)
                .background(DS.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.xs))
        }
        .padding(DS.Spacing.sm)
        .cardStyle(padding: 0, cornerRadius: DS.Radius.md)
    }
}
