import SwiftUI
import WebKit

// MARK: - Interactive Browser View
// Extracted from BrowserSessionView.swift following Apple engineering standards
// Contains: WKWebView wrapper with full browser functionality
// File size: ~315 lines (under Apple's 500 line "good" threshold)

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

    private func createSafariQualityConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()

        // ===== Preferences =====
        let preferences = WKPreferences()
        preferences.minimumFontSize = 9.0
        preferences.javaScriptCanOpenWindowsAutomatically = true
        preferences.tabFocusesLinks = true
        configuration.preferences = preferences

        // ===== Webpage Preferences =====
        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = true
        webpagePrefs.preferredContentMode = .desktop
        configuration.defaultWebpagePreferences = webpagePrefs

        // ===== Media Configuration =====
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // ===== Data Store (use default for proper caching) =====
        configuration.websiteDataStore = .default()

        // ===== User Content Controller =====
        let contentController = WKUserContentController()

        // Inject performance and quality optimizations
        let optimizationScript = WKUserScript(
            source: getPerformanceOptimizationScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(optimizationScript)

        configuration.userContentController = contentController

        return configuration
    }

    private func getPerformanceOptimizationScript() -> String {
        return """
        (function() {
            'use strict';

            // ===== Passive Event Listeners for Smooth Scrolling =====
            if (typeof EventTarget !== 'undefined') {
                const originalAddEventListener = EventTarget.prototype.addEventListener;
                EventTarget.prototype.addEventListener = function(type, listener, options) {
                    if (type === 'touchstart' || type === 'touchmove' || type === 'wheel' || type === 'mousewheel') {
                        if (typeof options === 'boolean') {
                            options = { capture: options, passive: true };
                        } else if (typeof options === 'object') {
                            options.passive = true;
                        } else {
                            options = { passive: true };
                        }
                    }
                    return originalAddEventListener.call(this, type, listener, options);
                };
            }

            // ===== Font Rendering Optimization =====
            const fontOptimizationCSS = document.createElement('style');
            fontOptimizationCSS.textContent = `
                body {
                    -webkit-font-smoothing: antialiased;
                    -moz-osx-font-smoothing: grayscale;
                    text-rendering: optimizeLegibility;
                }
            `;

            if (document.head) {
                document.head.appendChild(fontOptimizationCSS);
            } else {
                document.addEventListener('DOMContentLoaded', () => {
                    document.head.appendChild(fontOptimizationCSS);
                });
            }

            // ===== Smooth Image Loading =====
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', optimizeImages);
            } else {
                optimizeImages();
            }

            function optimizeImages() {
                const imageCSS = document.createElement('style');
                imageCSS.textContent = `
                    img {
                        image-rendering: -webkit-optimize-contrast;
                        image-rendering: crisp-edges;
                    }
                `;
                document.head.appendChild(imageCSS);
            }
        })();
        """
    }

    private func setupProfessionalQuality(_ webView: WKWebView) {
        // ===== Desktop User Agent =====
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

        // ===== Navigation Gestures =====
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = true

        // ===== Layer-Backed Rendering for GPU Acceleration =====
        webView.wantsLayer = true

        guard let layer = webView.layer else { return }

        // Async drawing for smooth performance
        layer.drawsAsynchronously = true

        // Retina/HiDPI support - CRITICAL for quality
        // Use window's backing scale, not screen's (handles multi-monitor correctly)
        if let window = webView.window {
            layer.contentsScale = window.backingScaleFactor
        } else {
            layer.contentsScale = 2.0 // Default to retina
        }

        // High-quality image scaling filters
        layer.magnificationFilter = .trilinear
        layer.minificationFilter = .trilinear

        // Opaque for better compositing performance
        layer.isOpaque = true

        // Don't rasterize - keeps vector quality
        layer.shouldRasterize = false

        // Smooth edges
        layer.edgeAntialiasingMask = [.layerLeftEdge, .layerRightEdge, .layerTopEdge, .layerBottomEdge]

        // Prevent white flash on dark mode
        if #available(macOS 10.14, *) {
            webView.setValue(false, forKey: "drawsBackground")
        }
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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: InteractiveBrowserView
        var initialURLLoaded = false

        init(_ parent: InteractiveBrowserView) {
            self.parent = parent
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                self.parent.currentURL = webView.url?.absoluteString
                self.parent.pageTitle = webView.title
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                NSLog("[InteractiveBrowser] Navigation failed: \(error.localizedDescription)")
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                NSLog("[InteractiveBrowser] Provisional navigation failed: \(error.localizedDescription)")
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation - this enables clicking links
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            // Allow all responses for better compatibility
            decisionHandler(.allow)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // Handle web process crashes
            NSLog("[InteractiveBrowser] Web content process terminated - reloading")
            DispatchQueue.main.async {
                self.parent.isLoading = false
                webView.reload()
            }
        }

        // MARK: - WKUIDelegate (for popups, alerts, rendering enhancements)

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Handle popup windows by loading in the same webView
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = "Alert"
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = NSAlert()
            alert.messageText = "Confirm"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn)
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let alert = NSAlert()
            alert.messageText = prompt
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            textField.stringValue = defaultText ?? ""
            alert.accessoryView = textField

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                completionHandler(textField.stringValue)
            } else {
                completionHandler(nil)
            }
        }
    }
}

// MARK: - Dark Mode Implementation

extension InteractiveBrowserView {
    static let darkModeCSS = """
        /* Night Eye Style Dark Mode - Simple Inversion with Smart Image Handling */

        /* Apply filter to root, which inverts the entire page */
        html {
            background-color: #fff !important;
            filter: invert(90%) hue-rotate(180deg) !important;
        }

        /* Images: use screen blend mode to eliminate dark backgrounds (which were white before inversion) */
        img {
            mix-blend-mode: screen !important;
        }

        /* Counter-invert photos/content images to preserve their colors */
        img[src*="photo"], img[src*="image"], img[src*="upload"],
        img[src*="avatar"], img[src*="profile"], img[src*="thumb"],
        img[src*="content"] {
            filter: invert(90%) hue-rotate(180deg) !important;
            mix-blend-mode: normal !important;
        }

        /* Videos and iframes should be counter-inverted to look normal */
        video, canvas, iframe {
            filter: invert(90%) hue-rotate(180deg) !important;
        }

        /* Scrollbars */
        ::-webkit-scrollbar {
            filter: invert(90%) hue-rotate(180deg);
        }
    """

    static let darkModeScript = """
        (function() {
            'use strict';

            // Inject dark mode stylesheet
            const style = document.createElement('style');
            style.id = 'swag-dark-mode';
            style.textContent = `\(darkModeCSS)`;

            if (document.head) {
                document.head.appendChild(style);
            } else {
                document.addEventListener('DOMContentLoaded', () => {
                    if (document.head && !document.getElementById('swag-dark-mode')) {
                        document.head.appendChild(style);
                    }
                });
            }

            // Fix image container backgrounds (removes white boxes around logos)
            function fixImageContainers() {
                // Find all images
                const images = document.querySelectorAll('img');

                images.forEach(img => {
                    // Force transparent background on the image itself
                    img.style.backgroundColor = 'transparent';

                    // Get the parent element
                    let parent = img.parentElement;

                    // Check up to 5 levels of parents and force transparent backgrounds
                    for (let i = 0; i < 5 && parent; i++) {
                        // Force transparent on ANY parent container with a background
                        const computedBg = window.getComputedStyle(parent).backgroundColor;

                        if (computedBg && computedBg !== 'rgba(0, 0, 0, 0)' && computedBg !== 'transparent') {
                            // Force transparent background
                            parent.style.setProperty('background-color', 'transparent', 'important');
                            parent.style.setProperty('background', 'transparent', 'important');
                        }

                        // Also remove inline style backgrounds
                        if (parent.style.backgroundColor || parent.style.background) {
                            parent.style.setProperty('background-color', 'transparent', 'important');
                            parent.style.setProperty('background', 'transparent', 'important');
                        }

                        parent = parent.parentElement;
                    }
                });
            }

            // Run after DOM loads
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', () => {
                    setTimeout(fixImageContainers, 100);
                    setTimeout(fixImageContainers, 500);
                });
            } else {
                setTimeout(fixImageContainers, 100);
                setTimeout(fixImageContainers, 500);
            }

            // Watch for new images being added
            const observer = new MutationObserver((mutations) => {
                let hasNewImages = false;
                mutations.forEach(mutation => {
                    if (mutation.addedNodes.length > 0) {
                        mutation.addedNodes.forEach(node => {
                            if (node.nodeType === 1 && (node.tagName === 'IMG' || node.querySelector('img'))) {
                                hasNewImages = true;
                            }
                        });
                    }
                });

                if (hasNewImages) {
                    setTimeout(fixImageContainers, 100);
                }
            });

            if (document.body) {
                observer.observe(document.body, {
                    childList: true,
                    subtree: true
                });
            }
        })();
    """

    static let removeDarkModeScript = """
        (function() {
            const style = document.getElementById('swag-dark-mode');
            if (style) {
                style.remove();
            }
            document.querySelectorAll('[style*="--bg-color"]').forEach(el => {
                el.style.removeProperty('--bg-color');
            });
        })();
    """
}

