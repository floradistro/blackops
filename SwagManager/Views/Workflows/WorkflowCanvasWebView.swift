import SwiftUI
import WebKit

// MARK: - Canvas Bridge Protocol
// Messages from React Flow → Swift

enum CanvasEvent {
    case ready
    case nodeSelected(id: String)
    case nodeDoubleClicked(id: String)
    case nodeContextMenu(id: String, x: CGFloat, y: CGFloat)
    case nodeMoved(id: String, x: Double, y: Double)
    case edgeCreated(from: String, to: String, edgeType: String)
    case nodesDeleted(ids: [String])
    case edgesDeleted(edges: [(from: String, to: String, edgeType: String)])
    case selectionChanged(ids: [String])
}

// MARK: - WKWebView Wrapper

struct WorkflowCanvasWebView: NSViewRepresentable {
    let htmlURL: URL
    @Binding var bridge: CanvasBridge?
    var onEvent: ((CanvasEvent) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Register message handler
        let handler = context.coordinator
        config.userContentController.add(handler, name: "canvas")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")  // Transparent background
        webView.navigationDelegate = context.coordinator

        // Retina rendering — ensure layer renders at screen scale
        webView.wantsLayer = true
        webView.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0

        // Allow magnification for pinch-to-zoom (optional)
        webView.allowsMagnification = false

        // Load the bundled HTML
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onEvent = onEvent
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent, bridge: $bridge)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var onEvent: ((CanvasEvent) -> Void)?
        @Binding var bridge: CanvasBridge?

        init(onEvent: ((CanvasEvent) -> Void)?, bridge: Binding<CanvasBridge?>) {
            self.onEvent = onEvent
            self._bridge = bridge
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Create bridge once page loads
            Task { @MainActor in
                bridge = CanvasBridge(webView: webView)
            }
        }

        // MARK: WKScriptMessageHandler — receive messages from JS

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }
            let payload = body["payload"] as? [String: Any] ?? [:]

            Task { @MainActor [weak self] in
                guard let self else { return }
                let event = self.parseEvent(type: type, payload: payload)
                if let event {
                    self.onEvent?(event)
                }
            }
        }

        private func parseEvent(type: String, payload: [String: Any]) -> CanvasEvent? {
            switch type {
            case "ready":
                return .ready
            case "nodeSelected":
                guard let id = payload["id"] as? String else { return nil }
                return .nodeSelected(id: id)
            case "nodeDoubleClicked":
                guard let id = payload["id"] as? String else { return nil }
                return .nodeDoubleClicked(id: id)
            case "nodeContextMenu":
                guard let id = payload["id"] as? String,
                      let x = payload["x"] as? CGFloat,
                      let y = payload["y"] as? CGFloat else { return nil }
                return .nodeContextMenu(id: id, x: x, y: y)
            case "nodeMoved":
                guard let id = payload["id"] as? String,
                      let x = payload["x"] as? Double,
                      let y = payload["y"] as? Double else { return nil }
                return .nodeMoved(id: id, x: x, y: y)
            case "edgeCreated":
                guard let from = payload["from"] as? String,
                      let to = payload["to"] as? String else { return nil }
                let edgeType = payload["edgeType"] as? String ?? "success"
                return .edgeCreated(from: from, to: to, edgeType: edgeType)
            case "nodesDeleted":
                guard let ids = payload["ids"] as? [String] else { return nil }
                return .nodesDeleted(ids: ids)
            case "edgesDeleted":
                guard let edgeList = payload["edges"] as? [[String: Any]] else { return nil }
                let edges = edgeList.compactMap { e -> (from: String, to: String, edgeType: String)? in
                    guard let from = e["from"] as? String, let to = e["to"] as? String else { return nil }
                    return (from, to, e["edgeType"] as? String ?? "success")
                }
                return .edgesDeleted(edges: edges)
            case "selectionChanged":
                guard let ids = payload["ids"] as? [String] else { return nil }
                return .selectionChanged(ids: ids)
            default:
                return nil
            }
        }
    }
}

// MARK: - Canvas Bridge (Swift → JS commands)

@MainActor
class CanvasBridge {
    private weak var webView: WKWebView?

    init(webView: WKWebView) {
        self.webView = webView
    }

    /// Load full graph data
    func loadGraph(nodes: [[String: Any]], edges: [[String: Any]]) {
        let data: [String: Any] = ["nodes": nodes, "edges": edges]
        callJS("loadGraph", data: data)
    }

    /// Update live node statuses during a run
    func updateNodeStatus(_ statuses: [String: [String: Any]]) {
        callJS("updateNodeStatus", data: statuses)
    }

    /// Clear all status indicators
    func clearStatus() {
        eval("window.bridge.clearStatus()")
    }

    /// Programmatically select a node
    func selectNode(_ id: String) {
        eval("window.bridge.selectNode('\(id.escapedForJS)')")
    }

    /// Fit all content in view
    func fitView() {
        eval("window.bridge.fitView()")
    }

    /// Set agent streaming tokens
    func setAgentTokens(_ tokens: [String: String]) {
        callJS("setAgentTokens", data: tokens)
    }

    /// Add a new node (from native palette)
    func addNode(_ nodeData: [String: Any]) {
        callJS("addNode", data: nodeData)
    }

    /// Remove a node
    func removeNode(_ id: String) {
        eval("window.bridge.removeNode('\(id.escapedForJS)')")
    }

    /// Highlight the edge between two step keys
    func highlightPath(fromKey: String, toKey: String) {
        eval("window.bridge.highlightPath('\(fromKey.escapedForJS)', '\(toKey.escapedForJS)')")
    }

    /// Clear all edge highlights
    func clearEdgeHighlights() {
        eval("window.bridge.clearEdgeHighlights()")
    }

    // MARK: - Internal

    private func callJS(_ method: String, data: Any) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        eval("window.bridge.\(method)(\(jsonString))")
    }

    private func eval(_ js: String) {
        webView?.evaluateJavaScript(js) { _, error in
            if let error {
                print("[CanvasBridge] JS error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - String Escaping Helper

private extension String {
    var escapedForJS: String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
