import SwiftUI
import WebKit

// MARK: - Interactive Browser View
// Extracted from BrowserSessionView.swift following Apple engineering standards
// Refactored - configuration, coordinator, and dark mode extracted to extensions
// File size: ~55 lines (under Apple's 300 line "excellent" threshold)

struct InteractiveBrowserView: NSViewRepresentable {
    let initialURL: String
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var currentURL: String?
    @Binding var pageTitle: String?
    @Binding var webView: WKWebView?

    func makeNSView(context: Context) -> WKWebView {
        // MARK: - Safari-Quality Configuration
        let config = createSafariQualityConfiguration()

        // MARK: - Create WebView with Production Settings
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // MARK: - Professional Polish
        setupProfessionalQuality(webView)

        // Store reference (async to avoid blocking)
        Task { @MainActor in
            self.webView = webView
        }

        // Load URL (async to avoid blocking)
        if let urlToLoad = URL(string: initialURL) {
            context.coordinator.initialURLLoaded = true
            Task {
                let request = URLRequest(url: urlToLoad, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
                await MainActor.run {
                    _ = webView.load(request)
                }
            }
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Don't reload on every update - let the webView handle navigation internally
        // This prevents the infinite refresh loop

        // Update backing scale if window changes (multi-monitor support)
        if let window = webView.window, let layer = webView.layer {
            let currentScale = layer.contentsScale
            let windowScale = window.backingScaleFactor

            if currentScale != windowScale {
                layer.contentsScale = windowScale
            }
        }
    }

    // Additional implementation extracted to extensions:
    // - InteractiveBrowserView+Configuration.swift: WebView configuration and optimization
    // - InteractiveBrowserView+Coordinator.swift: Navigation and UI delegates
    // - InteractiveBrowserView+DarkMode.swift: Dark mode scripts and CSS
}
