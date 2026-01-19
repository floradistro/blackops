import Foundation

// MARK: - EditorStore Zoom Functions
// Extracted from EditorView.swift following Apple engineering standards
// File size: ~16 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Zoom Functions

    func zoomIn() {
        zoomLevel = min(zoomLevel + 0.1, 3.0)
    }

    func zoomOut() {
        zoomLevel = max(zoomLevel - 0.1, 0.5)
    }

    func resetZoom() {
        zoomLevel = 1.0
    }
}
