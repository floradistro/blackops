import SwiftUI

// MARK: - Workflow Minimap
// Compact overview of the DAG canvas shown in the bottom-right corner.
// Displays node dots, edge lines, and a viewport rectangle.
// Click/drag to navigate the canvas.

struct WorkflowMinimap: View {
    let nodePositions: [String: CGPoint]
    let graph: WorkflowGraph?
    let liveStatus: [String: NodeStatus]
    let zoom: CGFloat
    let panOffset: CGSize
    let canvasSize: CGSize
    let onNavigate: (CGSize) -> Void

    // MARK: - Constants

    private let minimapWidth: CGFloat = 160
    private let minimapHeight: CGFloat = 120
    private let nodeDotSize: CGFloat = 5
    private let contentPadding: CGFloat = 10

    // MARK: - Body

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                minimapContent
                    .frame(width: minimapWidth, height: minimapHeight)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(DS.Colors.divider.opacity(0.5), lineWidth: 0.5)
                    )
            }
        }
        .padding(DS.Spacing.md)
        .allowsHitTesting(true)
    }

    // MARK: - Minimap Content

    private var minimapContent: some View {
        Canvas { context, size in
            let transform = minimapTransform(in: size)
            drawEdges(context: context, transform: transform)
            drawNodes(context: context, transform: transform)
            drawViewport(context: context, size: size, transform: transform)
        }
        .gesture(minimapNavigationGesture)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Transform

    /// Computes a scale and offset that fits all node positions into the minimap bounds.
    private func minimapTransform(in size: CGSize) -> MinimapTransform {
        guard !nodePositions.isEmpty else {
            return MinimapTransform(scale: 1, offsetX: size.width / 2, offsetY: size.height / 2)
        }

        let xs = nodePositions.values.map(\.x)
        let ys = nodePositions.values.map(\.y)

        let minX = xs.min()!
        let maxX = xs.max()!
        let minY = ys.min()!
        let maxY = ys.max()!

        let spanX = max(maxX - minX, 1)
        let spanY = max(maxY - minY, 1)

        let drawableWidth = size.width - contentPadding * 2
        let drawableHeight = size.height - contentPadding * 2

        let scale = min(drawableWidth / spanX, drawableHeight / spanY)

        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        let offsetX = size.width / 2 - centerX * scale
        let offsetY = size.height / 2 - centerY * scale

        return MinimapTransform(scale: scale, offsetX: offsetX, offsetY: offsetY)
    }

    // MARK: - Draw Edges

    private func drawEdges(context: GraphicsContext, transform: MinimapTransform) {
        guard let graph else { return }

        for edge in graph.edges {
            guard let fromPos = nodePositions[edge.from],
                  let toPos = nodePositions[edge.to] else { continue }

            let from = transform.apply(fromPos)
            let to = transform.apply(toPos)

            var path = Path()
            path.move(to: from)
            path.addLine(to: to)

            let edgeColor: Color = edge.type == "failure" ? DS.Colors.error : DS.Colors.textQuaternary
            context.stroke(path, with: .color(edgeColor.opacity(0.5)), lineWidth: 0.5)
        }
    }

    // MARK: - Draw Nodes

    private func drawNodes(context: GraphicsContext, transform: MinimapTransform) {
        for (nodeId, position) in nodePositions {
            let mapped = transform.apply(position)
            let color = dotColor(for: nodeId)
            let rect = CGRect(
                x: mapped.x - nodeDotSize / 2,
                y: mapped.y - nodeDotSize / 2,
                width: nodeDotSize,
                height: nodeDotSize
            )
            context.fill(Circle().path(in: rect), with: .color(color))
        }
    }

    // MARK: - Draw Viewport

    private func drawViewport(context: GraphicsContext, size: CGSize, transform: MinimapTransform) {
        // The visible area in canvas-space:
        //   topLeft = (-panOffset.width / zoom, -panOffset.height / zoom)
        //   size    = (canvasSize.width / zoom, canvasSize.height / zoom)
        let vpX = -panOffset.width / zoom
        let vpY = -panOffset.height / zoom
        let vpW = canvasSize.width / zoom
        let vpH = canvasSize.height / zoom

        let topLeft = transform.apply(CGPoint(x: vpX, y: vpY))
        let bottomRight = transform.apply(CGPoint(x: vpX + vpW, y: vpY + vpH))

        let rect = CGRect(
            x: topLeft.x,
            y: topLeft.y,
            width: bottomRight.x - topLeft.x,
            height: bottomRight.y - topLeft.y
        )

        let clippedRect = rect.intersection(CGRect(origin: .zero, size: size))
        guard !clippedRect.isNull else { return }

        context.fill(
            RoundedRectangle(cornerRadius: 2).path(in: clippedRect),
            with: .color(DS.Colors.accent.opacity(0.1))
        )
        context.stroke(
            RoundedRectangle(cornerRadius: 2).path(in: clippedRect),
            with: .color(DS.Colors.accent.opacity(0.6)),
            lineWidth: 1
        )
    }

    // MARK: - Navigation Gesture

    private var minimapNavigationGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                navigateTo(minimapPoint: value.location)
            }
    }

    /// Converts a click/drag point in minimap coordinates to a new panOffset.
    private func navigateTo(minimapPoint: CGPoint) {
        let transform = minimapTransform(in: CGSize(width: minimapWidth, height: minimapHeight))
        guard transform.scale > 0 else { return }

        // Convert minimap point to canvas-space coordinate
        let canvasX = (minimapPoint.x - transform.offsetX) / transform.scale
        let canvasY = (minimapPoint.y - transform.offsetY) / transform.scale

        // Center the viewport on that point
        let newPanOffset = CGSize(
            width: canvasSize.width / 2 - canvasX * zoom,
            height: canvasSize.height / 2 - canvasY * zoom
        )
        onNavigate(newPanOffset)
    }

    // MARK: - Helpers

    private func dotColor(for nodeId: String) -> Color {
        // Prefer live status color if available
        if let status = liveStatus[nodeId] {
            return nodeStatusColor(status.status)
        }

        // Fall back to step type color
        if let node = graph?.nodes.first(where: { $0.id == nodeId }) {
            return stepTypeColor(for: node.type)
        }

        return DS.Colors.textTertiary
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

    private func stepTypeColor(for stepType: String) -> Color {
        switch stepType {
        case "tool":         return DS.Colors.accent
        case "condition":    return DS.Colors.warning
        case "delay":        return DS.Colors.purple
        case "agent":        return DS.Colors.cyan
        case "code":         return DS.Colors.green
        case "webhook_out":  return DS.Colors.orange
        case "approval":     return DS.Colors.warning
        case "waitpoint":    return DS.Colors.cyan
        case "parallel":     return DS.Colors.blue
        case "for_each":     return DS.Colors.blue
        case "transform":    return DS.Colors.purple
        case "sub_workflow": return DS.Colors.accent
        case "noop":         return DS.Colors.textTertiary
        case "custom":       return DS.Colors.pink
        default:             return DS.Colors.textSecondary
        }
    }
}

// MARK: - Minimap Transform

private struct MinimapTransform {
    let scale: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat

    func apply(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * scale + offsetX,
            y: point.y * scale + offsetY
        )
    }
}
