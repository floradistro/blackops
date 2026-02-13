import SwiftUI

// MARK: - Connection Layer
// Bezier curves between workflow nodes on the canvas
// Edge color by type: success=green, failure=red, true=blue, false=orange, parallel=purple

struct ConnectionLayer: View {
    let edges: [GraphEdge]
    let nodePositions: [String: CGPoint]
    let nodeStatus: [String: NodeStatus]
    let nodeSize: CGSize

    var body: some View {
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

                context.stroke(
                    path,
                    with: .color(color.opacity(isRunning ? 1.0 : 0.5)),
                    style: StrokeStyle(
                        lineWidth: isRunning ? 2.0 : 1.0,
                        dash: edge.type == "parallel" ? [6, 4] : []
                    )
                )

                // Arrow head at end point
                let arrowPath = arrowHead(at: endPoint, from: startPoint)
                context.fill(arrowPath, with: .color(color.opacity(isRunning ? 1.0 : 0.5)))
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

    private func edgeColor(_ edge: GraphEdge) -> Color {
        switch edge.type {
        case "success": return DS.Colors.success
        case "failure": return DS.Colors.error
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
}
