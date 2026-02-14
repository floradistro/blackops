import SwiftUI

// MARK: - Edge Drag State
// Observable state for the current drag-to-connect operation

struct EdgeDragState {
    var isActive: Bool = false
    var sourceNodeId: String?
    var sourceIsOutput: Bool = true
    var sourcePosition: CGPoint = .zero
    var currentPosition: CGPoint = .zero
    var hoveredTargetNodeId: String?
}

// MARK: - Node Port
// Small circle rendered at the top (input) or bottom (output) of a workflow node.
// Dragging from an output port draws a preview line; releasing over an input port creates an edge.

struct ConnectorPort: View {
    let nodeId: String
    let isOutput: Bool
    let position: CGPoint
    let isHighlighted: Bool

    var body: some View {
        Circle()
            .fill(isHighlighted ? DS.Colors.accent : DS.Colors.textTertiary)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(DS.Colors.accent, lineWidth: isHighlighted ? 2 : 0)
            )
            .shadow(color: isHighlighted ? DS.Colors.accent.opacity(0.5) : .clear, radius: 4)
    }
}

// MARK: - Edge Drag Preview
// Dashed bezier curve from the source port to the current cursor position during a drag.

struct EdgeDragPreview: View {
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        Path { path in
            path.move(to: from)
            let midY = (from.y + to.y) / 2
            path.addCurve(
                to: to,
                control1: CGPoint(x: from.x, y: midY),
                control2: CGPoint(x: to.x, y: midY)
            )
        }
        .stroke(
            DS.Colors.accent.opacity(0.7),
            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
        )
    }
}

// MARK: - Edge Connector Overlay
// Renders all input/output ports on workflow nodes and manages drag-to-connect interactions.

struct EdgeConnectorOverlay: View {
    let nodes: [GraphNode]
    let nodePositions: [String: CGPoint]
    let nodeSize: CGSize
    @Binding var dragState: EdgeDragState
    let onConnect: (String, String, String) -> Void

    var body: some View {
        ZStack {
            // Output ports (bottom center of each node)
            ForEach(nodes, id: \.id) { node in
                if let pos = nodePositions[node.id] {
                    let outputPos = CGPoint(x: pos.x, y: pos.y + nodeSize.height / 2)
                    ConnectorPort(
                        nodeId: node.id,
                        isOutput: true,
                        position: outputPos,
                        isHighlighted: dragState.sourceNodeId == node.id && dragState.sourceIsOutput
                    )
                    .position(outputPos)
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                if !dragState.isActive {
                                    dragState.isActive = true
                                    dragState.sourceNodeId = node.id
                                    dragState.sourceIsOutput = true
                                    dragState.sourcePosition = outputPos
                                }
                                dragState.currentPosition = CGPoint(
                                    x: outputPos.x + value.translation.width,
                                    y: outputPos.y + value.translation.height
                                )
                                dragState.hoveredTargetNodeId = findHoveredTarget(
                                    at: dragState.currentPosition,
                                    excluding: node.id
                                )
                            }
                            .onEnded { _ in
                                if let targetId = dragState.hoveredTargetNodeId,
                                   let sourceId = dragState.sourceNodeId {
                                    onConnect(sourceId, targetId, "on_success")
                                }
                                dragState = EdgeDragState()
                            }
                    )

                    // Input port (top center) — only highlights when a drag hovers over it
                    let inputPos = CGPoint(x: pos.x, y: pos.y - nodeSize.height / 2)
                    ConnectorPort(
                        nodeId: node.id,
                        isOutput: false,
                        position: inputPos,
                        isHighlighted: dragState.hoveredTargetNodeId == node.id
                    )
                    .position(inputPos)
                }
            }

            // Drag preview line
            if dragState.isActive {
                EdgeDragPreview(
                    from: dragState.sourcePosition,
                    to: dragState.currentPosition
                )
            }
        }
    }

    // MARK: - Hit Testing

    private func findHoveredTarget(at point: CGPoint, excluding sourceId: String) -> String? {
        let hitRadius: CGFloat = 20
        for node in nodes where node.id != sourceId {
            if let pos = nodePositions[node.id] {
                let inputPos = CGPoint(x: pos.x, y: pos.y - nodeSize.height / 2)
                let distance = hypot(point.x - inputPos.x, point.y - inputPos.y)
                if distance < hitRadius {
                    return node.id
                }
            }
        }
        return nil
    }
}

// MARK: - Edge Type Popover
// Shown after connecting from a condition node to let the user pick "on_success" vs "on_failure".

struct EdgeTypePopover: View {
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text("Connection Type")
                .font(DS.Typography.monoCaption)
                .foregroundStyle(DS.Colors.textSecondary)

            Button {
                onSelect("on_success")
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Circle().fill(DS.Colors.success).frame(width: 8, height: 8)
                    Text("On Success")
                        .font(DS.Typography.monoSmall)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.surfaceSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.xs))
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.Colors.textPrimary)

            Button {
                onSelect("on_failure")
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Circle().fill(DS.Colors.error).frame(width: 8, height: 8)
                    Text("On Failure")
                        .font(DS.Typography.monoSmall)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.surfaceSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.xs))
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.Colors.textPrimary)
        }
        .padding(DS.Spacing.sm)
        .frame(width: 160)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.border, lineWidth: 0.5)
        )
    }
}
