//
//  BrowserSessionView.swift
//  SwagManager
//
//  Main view for displaying a browser session as a tab with fully interactive browser
//

import SwiftUI
import WebKit

struct BrowserSessionView: View {
    let session: BrowserSession
    @ObservedObject var store: EditorStore
    @State private var isRefreshing = false
    @State private var autoRefresh = false  // Disabled for interactive mode
    @State private var refreshTimer: Timer?

    // Interactive browser state
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var currentURL: String?
    @State private var pageTitle: String?
    @State private var webView: WKWebView?
    @State private var isDarkMode = false

    var body: some View {
        VStack(spacing: 0) {
            // Browser controls
            BrowserControls(
                canGoBack: canGoBack,
                canGoForward: canGoForward,
                isLoading: isLoading,
                currentURL: currentURL ?? session.currentUrl,
                pageTitle: pageTitle ?? session.pageTitle,
                webView: webView,
                isDarkMode: $isDarkMode,
                onBack: { webView?.goBack() },
                onForward: { webView?.goForward() },
                onRefresh: { webView?.reload() },
                onStop: { webView?.stopLoading() },
                onNewTab: { /* TODO: Create new browser session */ },
                onToggleDarkMode: { toggleDarkMode() }
            )

            // Interactive browser view
            ZStack {
                DesignSystem.Colors.surfacePrimary.ignoresSafeArea()

                if let url = session.currentUrl, !url.isEmpty {
                    InteractiveBrowserView(
                        initialURL: url,
                        isLoading: $isLoading,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        currentURL: $currentURL,
                        pageTitle: $pageTitle,
                        webView: $webView
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "globe")
                            .font(.system(size: 48))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Text("No URL available")
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        if session.hasError, let error = session.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.error.opacity(0.8))
                                .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if session.hasError {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(DesignSystem.Colors.error)
                                Text("Error")
                                    .foregroundColor(DesignSystem.Colors.error)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DesignSystem.Colors.error.opacity(0.15))
                            .cornerRadius(6)
                            .padding()
                        }
                        Spacer()
                    }
                }
            }
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
        .onDisappear { stopAutoRefresh() }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func toggleDarkMode() {
        isDarkMode.toggle()
        guard let webView = webView else { return }

        if isDarkMode {
            webView.evaluateJavaScript(InteractiveBrowserView.darkModeScript) { _, error in
                if let error = error {
                    NSLog("[DarkMode] Failed to enable: \(error.localizedDescription)")
                }
            }
        } else {
            webView.evaluateJavaScript(InteractiveBrowserView.removeDarkModeScript) { _, error in
                if let error = error {
                    NSLog("[DarkMode] Failed to disable: \(error.localizedDescription)")
                }
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

// MARK: - Interactive Browser View

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

// MARK: - Browser Controls

struct BrowserControls: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let isLoading: Bool
    let currentURL: String?
    let pageTitle: String?
    let webView: WKWebView?
    @Binding var isDarkMode: Bool

    let onBack: () -> Void
    let onForward: () -> Void
    let onRefresh: () -> Void
    let onStop: () -> Void
    let onNewTab: () -> Void
    let onToggleDarkMode: () -> Void

    @State private var urlText: String = ""
    @FocusState private var isURLFieldFocused: Bool

    private func navigateToURL() {
        guard let webView = webView, !urlText.isEmpty else { return }

        var urlString = urlText.trimmingCharacters(in: .whitespaces)

        // Add https:// if no scheme is present
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            // Check if it looks like a URL (contains a dot)
            if urlString.contains(".") {
                urlString = "https://" + urlString
            } else {
                // Otherwise, treat as a search query
                urlString = "https://www.google.com/search?q=" + urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            }
        }

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }

    var body: some View {
        let backButton = Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(canGoBack ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(!canGoBack)
        .help("Back")

        let forwardButton = Button(action: onForward) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(canGoForward ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(!canGoForward)
        .help("Forward")

        let refreshButton = Button(action: isLoading ? onStop : onRefresh) {
            Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(isLoading ? "Stop" : "Refresh")

        let urlBar = HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundStyle(DesignSystem.Colors.green.opacity(0.8))

            TextField("Enter URL or search...", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .focused($isURLFieldFocused)
                .onSubmit {
                    navigateToURL()
                    isURLFieldFocused = false
                }

            if !urlText.isEmpty {
                Button(action: { urlText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(DesignSystem.Colors.surfaceElevated)
        .cornerRadius(8)

        let darkModeButton = Button(action: onToggleDarkMode) {
            Image(systemName: isDarkMode ? "moon.fill" : "moon")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isDarkMode ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(isDarkMode ? "Disable Dark Mode" : "Enable Dark Mode")

        let newTabButton = Button(action: onNewTab) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help("New tab")

        return HStack(spacing: 8) {
            HStack(spacing: 4) {
                backButton
                forwardButton
                refreshButton
            }
            .padding(.leading, 8)

            urlBar

            darkModeButton
            newTabButton
                .padding(.trailing, 8)
        }
        .frame(height: 44)
        .background(DesignSystem.Colors.surfaceSecondary)
        .onAppear {
            urlText = currentURL ?? ""
        }
        .onChange(of: currentURL) { _, newURL in
            if !isURLFieldFocused {
                urlText = newURL ?? ""
            }
        }
    }
}

#Preview {
    BrowserSessionView(
        session: BrowserSession(
            id: UUID(),
            creationId: nil,
            storeId: UUID(),
            name: "Test Session",
            currentUrl: "https://example.com",
            viewportWidth: 1280,
            viewportHeight: 800,
            userAgent: nil,
            cookies: nil,
            localStorage: nil,
            sessionStorage: nil,
            screenshotUrl: nil,
            screenshotAt: Date(),
            interactiveElements: nil,
            pageTitle: "Example Domain",
            browserWsEndpoint: nil,
            browserService: "browserless",
            status: "active",
            errorMessage: nil,
            lastActivity: Date(),
            createdAt: Date(),
            updatedAt: Date()
        ),
        store: EditorStore()
    )
    .frame(width: 800, height: 600)
}
