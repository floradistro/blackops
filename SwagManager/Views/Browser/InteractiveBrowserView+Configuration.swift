import WebKit

// MARK: - InteractiveBrowserView Configuration Extension
// Extracted from InteractiveBrowserView.swift following Apple engineering standards
// File size: ~145 lines (under Apple's 300 line "excellent" threshold)

extension InteractiveBrowserView {
    internal func createSafariQualityConfiguration() -> WKWebViewConfiguration {
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

    internal func getPerformanceOptimizationScript() -> String {
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

    internal func setupProfessionalQuality(_ webView: WKWebView) {
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
}
