import SwiftUI

// MARK: - Connection Layer
// Bezier curves between workflow nodes on the canvas
// Edge color by type: success=green, failure=red (dashed), true=blue, false=orange, parallel=purple (dashed)

struct ConnectionLayer: View {
    let edges: [GraphEdge]
    let nodePositions: [String: CGPoint]
    let nodeStatus: [String: NodeStatus]
    let nodeSize: CGSize

    var body: some View {
        ZStack {
            // Bezier curves + arrow heads
            Canvas { context, _ in
                for edge in edges {
                    guard let fromPos = nodePositions[edge.from],
                          let toPos = nodePositions[edge.to] else { continue }

                    let startPoint = CGPoint(
                        x: fromPos.x,
                        y: fromPos.y + nodeSize.height / 2
                    )
                    let endPoint = CGPoint(
                        x: toPos.x,
                        y: toPos.y - nodeSize.height / 2
                    )

                    let path = bezierPath(from: startPoint, to: endPoint)
                    let color = edgeColor(edge)
                    let isRunning = isEdgeActive(edge)
                    let isDashed = isFailureEdge(edge) || edge.type == "parallel"

                    context.stroke(
                        path,
                        with: .color(color.opacity(isRunning ? 1.0 : 0.5)),
                        style: StrokeStyle(
                            lineWidth: isRunning ? 2.0 : 1.0,
                            dash: isDashed ? [6, 4] : []
                        )
                    )

                    // Arrow head at end point
                    let arrowPath = arrowHead(at: endPoint, from: startPoint)
                    context.fill(arrowPath, with: .color(color.opacity(isRunning ? 1.0 : 0.5)))
                }
            }

            // Edge labels at midpoints
            ForEach(edges) { edge in
                if let labelText = edgeLabel(edge),
                   let midpoint = edgeMidpoint(edge) {
                    Text(labelText)
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textQuaternary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.ultraThinMaterial)
                        )
                        .position(midpoint)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Bezier Path

    private func bezierPath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)

        let controlOffset = abs(end.y - start.y) * 0.4
        let cp1 = CGPoint(x: start.x, y: start.y + controlOffset)
        let cp2 = CGPoint(x: end.x, y: end.y - controlOffset)

        path.addCurve(to: end, control1: cp1, control2: cp2)
        return path
    }

    // MARK: - Arrow Head

    private func arrowHead(at point: CGPoint, from source: CGPoint) -> Path {
        let size: CGFloat = 6
        var path = Path()

        // Calculate angle
        let dx = point.x - source.x
        let dy = point.y - source.y
        let angle = atan2(dy, dx)

        let tip = point
        let left = CGPoint(
            x: tip.x - size * cos(angle - .pi / 6),
            y: tip.y - size * sin(angle - .pi / 6)
        )
        let right = CGPoint(
            x: tip.x - size * cos(angle + .pi / 6),
            y: tip.y - size * sin(angle + .pi / 6)
        )

        path.move(to: tip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }

    // MARK: - Edge Styling

    private func isFailureEdge(_ edge: GraphEdge) -> Bool {
        if edge.type == "failure" { return true }
        if let label = edge.label?.lowercased(),
           label.contains("fail") || label.contains("error") {
            return true
        }
        return false
    }

    private func edgeColor(_ edge: GraphEdge) -> Color {
        // Check label-based override first
        if isFailureEdge(edge) && edge.type != "failure" {
            return DS.Colors.error.opacity(0.6)
        }
        switch edge.type {
        case "success": return DS.Colors.success
        case "failure": return DS.Colors.error.opacity(0.6)
        case "true": return DS.Colors.accent
        case "false": return DS.Colors.orange
        case "parallel": return DS.Colors.purple
        default: return DS.Colors.textTertiary
        }
    }

    private func isEdgeActive(_ edge: GraphEdge) -> Bool {
        guard let fromStatus = nodeStatus[edge.from] else { return false }
        return fromStatus.status == "running" || fromStatus.status == "success"
    }

    // MARK: - Edge Labels

    private func edgeLabel(_ edge: GraphEdge) -> String? {
        if let label = edge.label, !label.isEmpty { return label }
        // Show type as label for non-default edges
        switch edge.type {
        case "failure", "true", "false": return edge.type
        default: return nil
        }
    }

    /// Approximate midpoint of the bezier curve between two connected nodes.
    private func edgeMidpoint(_ edge: GraphEdge) -> CGPoint? {
        guard let fromPos = nodePositions[edge.from],
              let toPos = nodePositions[edge.to] else { return nil }

        let start = CGPoint(x: fromPos.x, y: fromPos.y + nodeSize.height / 2)
        let end = CGPoint(x: toPos.x, y: toPos.y - nodeSize.height / 2)

        let controlOffset = abs(end.y - start.y) * 0.4
        let cp1 = CGPoint(x: start.x, y: start.y + controlOffset)
        let cp2 = CGPoint(x: end.x, y: end.y - controlOffset)

        // Cubic bezier at t=0.5
        let t: CGFloat = 0.5
        let u: CGFloat = 1.0 - t
        let x = u * u * u * start.x + 3 * u * u * t * cp1.x + 3 * u * t * t * cp2.x + t * t * t * end.x
        let y = u * u * u * start.y + 3 * u * u * t * cp1.y + 3 * u * t * t * cp2.y + t * t * t * end.y
        return CGPoint(x: x, y: y)
    }
}
