import SwiftUI

// MARK: - Alignment Guide

struct AlignmentGuide {
    let axis: Axis
    let position: CGFloat
    let start: CGFloat
    let end: CGFloat
}

// MARK: - Canvas Grid Helper

struct CanvasGridHelper {

    static let nodeSize = CGSize(width: 200, height: 80)

    /// Snaps a point to the nearest grid intersection.
    static func snapToGrid(_ point: CGPoint, gridSize: CGFloat = 20) -> CGPoint {
        CGPoint(
            x: (point.x / gridSize).rounded() * gridSize,
            y: (point.y / gridSize).rounded() * gridSize
        )
    }

    /// Returns alignment guides when the dragged node's center is near-aligned with other nodes.
    static func alignmentGuides(
        for nodeId: String,
        at position: CGPoint,
        allPositions: [String: CGPoint],
        threshold: CGFloat = 8
    ) -> [AlignmentGuide] {
        let draggedCenter = CGPoint(
            x: position.x + nodeSize.width / 2,
            y: position.y + nodeSize.height / 2
        )

        var guides: [AlignmentGuide] = []

        for (id, pos) in allPositions where id != nodeId {
            let otherCenter = CGPoint(
                x: pos.x + nodeSize.width / 2,
                y: pos.y + nodeSize.height / 2
            )

            // Vertical center alignment (same X)
            if abs(draggedCenter.x - otherCenter.x) < threshold {
                let minY = min(draggedCenter.y, otherCenter.y) - 20
                let maxY = max(draggedCenter.y, otherCenter.y) + 20
                guides.append(AlignmentGuide(
                    axis: .vertical,
                    position: otherCenter.x,
                    start: minY,
                    end: maxY
                ))
            }

            // Horizontal center alignment (same Y)
            if abs(draggedCenter.y - otherCenter.y) < threshold {
                let minX = min(draggedCenter.x, otherCenter.x) - 20
                let maxX = max(draggedCenter.x, otherCenter.x) + 20
                guides.append(AlignmentGuide(
                    axis: .horizontal,
                    position: otherCenter.y,
                    start: minX,
                    end: maxX
                ))
            }
        }

        return guides
    }
}

// MARK: - Alignment Guides Overlay

struct AlignmentGuidesOverlay: View {
    let guides: [AlignmentGuide]
    let zoom: CGFloat
    let panOffset: CGSize

    var body: some View {
        Canvas { context, size in
            let dash = StrokeStyle(lineWidth: 1, dash: [4, 4])

            for guide in guides {
                var path = Path()

                switch guide.axis {
                case .horizontal:
                    let y = guide.position * zoom + panOffset.height
                    let startX = guide.start * zoom + panOffset.width
                    let endX = guide.end * zoom + panOffset.width
                    path.move(to: CGPoint(x: startX, y: y))
                    path.addLine(to: CGPoint(x: endX, y: y))

                case .vertical:
                    let x = guide.position * zoom + panOffset.width
                    let startY = guide.start * zoom + panOffset.height
                    let endY = guide.end * zoom + panOffset.height
                    path.move(to: CGPoint(x: x, y: startY))
                    path.addLine(to: CGPoint(x: x, y: endY))
                }

                context.stroke(
                    path,
                    with: .color(DS.Colors.accent.opacity(0.5)),
                    style: dash
                )
            }
        }
        .allowsHitTesting(false)
    }
}
