import SwiftUI
import AppKit

// MARK: - Canvas Exporter
// PNG export for the workflow canvas — renders nodes and edges to a static image

struct CanvasExporter {

    // MARK: - Export as NSImage

    @MainActor
    static func exportAsPNG(
        graph: WorkflowGraph,
        nodePositions: [String: CGPoint],
        liveStatus: [String: NodeStatus],
        scale: CGFloat = 2.0
    ) -> NSImage? {
        let bounds = computeBounds(nodePositions: nodePositions)
        let snapshot = CanvasSnapshot(
            graph: graph,
            nodePositions: nodePositions,
            liveStatus: liveStatus,
            bounds: bounds
        )

        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = scale
        return renderer.nsImage
    }

    // MARK: - Save to File

    @MainActor
    static func saveAsPNG(image: NSImage) async -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "workflow-export.png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        let response = await panel.begin()
        guard response == .OK, let url = panel.url else { return nil }

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try pngData.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Bounds Calculation

    private static func computeBounds(nodePositions: [String: CGPoint]) -> CGRect {
        guard !nodePositions.isEmpty else {
            return CGRect(x: 0, y: 0, width: 600, height: 400)
        }

        let padding: CGFloat = 140
        let nodeWidth: CGFloat = 200
        let nodeHeight: CGFloat = 80

        let xs = nodePositions.values.map(\.x)
        let ys = nodePositions.values.map(\.y)

        let minX = (xs.min() ?? 0) - nodeWidth / 2 - padding
        let maxX = (xs.max() ?? 0) + nodeWidth / 2 + padding
        let minY = (ys.min() ?? 0) - nodeHeight / 2 - padding
        let maxY = (ys.max() ?? 0) + nodeHeight / 2 + padding

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - Canvas Snapshot View

private struct CanvasSnapshot: View {
    let graph: WorkflowGraph
    let nodePositions: [String: CGPoint]
    let liveStatus: [String: NodeStatus]
    let bounds: CGRect

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))

            // Edges
            ConnectionLayer(
                edges: graph.edges,
                nodePositions: offsetPositions,
                nodeStatus: liveStatus,
                nodeSize: CGSize(width: 200, height: 80)
            )

            // Nodes
            ForEach(graph.nodes) { node in
                let pos = offsetPositions[node.id] ?? CGPoint(x: bounds.width / 2, y: bounds.height / 2)
                WorkflowNode(
                    node: node,
                    isSelected: false,
                    status: liveStatus[node.id]
                )
                .position(pos)
            }
        }
        .frame(width: bounds.width, height: bounds.height)
    }

    /// Translate node positions so the top-left of the bounding box maps to (0, 0)
    private var offsetPositions: [String: CGPoint] {
        var result: [String: CGPoint] = [:]
        for (id, point) in nodePositions {
            result[id] = CGPoint(
                x: point.x - bounds.origin.x,
                y: point.y - bounds.origin.y
            )
        }
        return result
    }
}
