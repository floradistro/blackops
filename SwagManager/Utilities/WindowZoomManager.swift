import AppKit
import SwiftUI

// MARK: - Content Zoom Environment
// Provides zoom level to all child views

private struct ContentZoomKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var contentZoom: CGFloat {
        get { self[ContentZoomKey.self] }
        set { self[ContentZoomKey.self] = newValue }
    }
}

extension View {
    /// Apply content zoom level to this view and all children
    func contentZoom(_ level: CGFloat) -> some View {
        environment(\.contentZoom, level)
    }
}

// MARK: - Unified Zoom Container
// Single container that handles zoom for entire app - macOS native style
// Scales content uniformly while keeping it centered and scrollable

struct UnifiedZoomView<Content: View>: View {
    let zoomLevel: CGFloat
    let content: Content

    init(zoomLevel: CGFloat, @ViewBuilder content: () -> Content) {
        self.zoomLevel = zoomLevel
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: zoomLevel > 1.0) {
                content
                    .frame(
                        width: geometry.size.width / zoomLevel,
                        height: geometry.size.height / zoomLevel
                    )
                    .scaleEffect(zoomLevel, anchor: .center)
                    .frame(
                        width: geometry.size.width * max(1, zoomLevel),
                        height: geometry.size.height * max(1, zoomLevel)
                    )
            }
            .scrollDisabled(zoomLevel <= 1.0)
            .frame(width: geometry.size.width, height: geometry.size.height)
            // Center content when zoomed out
            .overlay {
                if zoomLevel < 1.0 {
                    content
                        .frame(
                            width: geometry.size.width / zoomLevel,
                            height: geometry.size.height / zoomLevel
                        )
                        .scaleEffect(zoomLevel, anchor: .center)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
    }
}
