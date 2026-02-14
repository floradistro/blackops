import SwiftUI

// MARK: - Workflow Outline Panel
// Collapsible side panel listing all workflow nodes for quick navigation
// Similar to n8n's node list — flat list grouped by type with search, selection, and context menus

struct WorkflowOutlinePanel: View {
    let graph: WorkflowGraph?
    let liveStatus: [String: NodeStatus]
    @Binding var selectedNodeId: String?
    @Binding var selectedNodeIds: Set<String>
    let onEditStep: (GraphNode) -> Void
    let onDeleteStep: (String) -> Void
    let onToggleEntryPoint: (GraphNode) -> Void

    @State private var searchText = ""
    @State private var hoveredNodeId: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            searchBar
            Divider().opacity(0.3)
            nodeList
        }
        .frame(width: 240)
        .background(DS.Colors.surfaceTertiary)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "list.bullet.indent")
                .font(DesignSystem.font(12, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)

            Text("OUTLINE")
                .font(DS.Typography.monoHeader)
                .foregroundStyle(DS.Colors.textTertiary)

            Spacer()

            if let graph {
                Text("\(graph.nodes.count)")
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textQuaternary)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.xs))
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(DesignSystem.font(11))
                .foregroundStyle(DS.Colors.textTertiary)

            TextField("Filter nodes...", text: $searchText)
                .font(DS.Typography.caption1)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .glassBackground(cornerRadius: DS.Radius.sm)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Node List

    private var nodeList: some View {
        Group {
            if let graph, !graph.nodes.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.xs) {
                            ForEach(filteredNodes, id: \.id) { node in
                                nodeRow(node)
                                    .id(node.id)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.sm)
                    }
                    .onChange(of: selectedNodeId) { _, newId in
                        if let id = newId {
                            withAnimation(DS.Animation.fast) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            } else {
                emptyState
            }
        }
    }

    // MARK: - Node Row

    private func nodeRow(_ node: GraphNode) -> some View {
        let isSelected = selectedNodeId == node.id || selectedNodeIds.contains(node.id)
        let status = liveStatus[node.id]

        return Button {
            withAnimation(DS.Animation.fast) {
                selectedNodeId = node.id
                selectedNodeIds = [node.id]
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                // Step type icon
                Image(systemName: WorkflowStepType.icon(for: node.type))
                    .font(DesignSystem.font(11))
                    .foregroundStyle(iconColor(for: node.type))
                    .frame(width: 16, alignment: .center)

                // Labels
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(node.displayName)
                            .font(DS.Typography.caption1)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .lineLimit(1)

                        // Entry point indicator
                        if node.isEntryPoint {
                            Circle()
                                .fill(DS.Colors.success)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Text(WorkflowStepType.label(for: node.type))
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Spacer()

                // Live status indicator
                if let status {
                    Circle()
                        .fill(nodeStatusColor(status.status))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isSelected
                    ? DS.Colors.selectionActive
                    : hoveredNodeId == node.id
                        ? DS.Colors.surfaceHover
                        : Color.clear,
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .glassBackground(cornerRadius: DS.Radius.sm)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredNodeId = isHovered ? node.id : nil
        }
        .contextMenu {
            Button {
                onEditStep(node)
            } label: {
                Label("Edit Step", systemImage: "pencil")
            }

            Button {
                onToggleEntryPoint(node)
            } label: {
                Label(
                    node.isEntryPoint ? "Remove Entry Point" : "Set as Entry Point",
                    systemImage: node.isEntryPoint ? "arrow.down.right.circle" : "arrow.down.right.circle.fill"
                )
            }

            Divider()

            Button(role: .destructive) {
                onDeleteStep(node.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "squares.leading.rectangle")
                .font(DesignSystem.font(28, weight: .light))
                .foregroundStyle(DS.Colors.textQuaternary)

            Text("No Steps")
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textSecondary)

            Text("Add steps to the canvas to see them listed here.")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.lg)
    }

    // MARK: - Filtered & Sorted Nodes

    private var filteredNodes: [GraphNode] {
        guard let graph else { return [] }

        let nodes: [GraphNode]
        if searchText.isEmpty {
            nodes = graph.nodes
        } else {
            let query = searchText.lowercased()
            nodes = graph.nodes.filter { node in
                node.displayName.lowercased().contains(query) ||
                node.type.lowercased().contains(query) ||
                WorkflowStepType.label(for: node.type).lowercased().contains(query)
            }
        }

        // Sort: entry points first, then alphabetically by type, then by label
        return nodes.sorted { a, b in
            if a.isEntryPoint != b.isEntryPoint {
                return a.isEntryPoint
            }
            if a.type != b.type {
                return a.type < b.type
            }
            return a.label.localizedCaseInsensitiveCompare(b.label) == .orderedAscending
        }
    }

    // MARK: - Helpers

    private func iconColor(for stepType: String) -> Color {
        switch stepType {
        case "tool":        return DS.Colors.accent
        case "condition":   return DS.Colors.warning
        case "delay":       return DS.Colors.purple
        case "agent":       return DS.Colors.cyan
        case "code":        return DS.Colors.green
        case "webhook_out": return DS.Colors.orange
        case "approval":    return DS.Colors.warning
        case "waitpoint":   return DS.Colors.cyan
        case "parallel":    return DS.Colors.blue
        case "for_each":    return DS.Colors.blue
        case "transform":   return DS.Colors.purple
        case "sub_workflow": return DS.Colors.accent
        case "noop":        return DS.Colors.textTertiary
        case "custom":      return DS.Colors.pink
        default:            return DS.Colors.textSecondary
        }
    }

    private func nodeStatusColor(_ status: String) -> Color {
        switch status {
        case "success", "completed": return DS.Colors.success
        case "running":              return DS.Colors.warning
        case "failed", "error":      return DS.Colors.error
        case "pending":              return DS.Colors.textQuaternary
        case "skipped":              return DS.Colors.textTertiary
        default:                     return DS.Colors.textQuaternary
        }
    }
}
