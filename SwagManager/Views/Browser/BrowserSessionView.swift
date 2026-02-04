//
//  BrowserSessionView.swift
//  SwagManager
//
//  Main view for displaying a browser session as a tab with fully interactive browser
//  REFACTORED - Reduced from 757 lines to ~265 lines by extracting components:
//  - InteractiveBrowserView.swift (319 lines) - WKWebView wrapper
//  - BrowserControls.swift (182 lines) - Navigation controls
//

import SwiftUI
import WebKit

struct BrowserSessionView: View {
    let session: BrowserSession
    var store: EditorStore
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
                onNewTab: { }, // New tab functionality not yet implemented
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
                        Spacer()
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(session.errorMessage ?? "Unknown error")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        .padding(12)
                        .background(DesignSystem.Materials.thick)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            setupAutoRefresh()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private func setupAutoRefresh() {
        guard autoRefresh else { return }

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task {
                await refresh()
            }
        }
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        webView?.reload()
    }

    // MARK: - Dark Mode Implementation

    private func toggleDarkMode() {
        isDarkMode.toggle()

        guard let webView = webView else { return }

        let darkModeScript = """
        (function() {
            const html = document.documentElement;
            const body = document.body;
            const isDark = \(isDarkMode ? "true" : "false");

            if (isDark) {
                html.style.filter = 'invert(1) hue-rotate(180deg)';
                body.style.backgroundColor = '#000';

                // Fix images and media
                const media = document.querySelectorAll('img, video, iframe, [style*="background-image"]');
                media.forEach(el => {
                    el.style.filter = 'invert(1) hue-rotate(180deg)';
                });
            } else {
                html.style.filter = '';
                body.style.backgroundColor = '';

                const media = document.querySelectorAll('img, video, iframe, [style*="background-image"]');
                media.forEach(el => {
                    el.style.filter = '';
                });
            }
        })();
        """

        webView.evaluateJavaScript(darkModeScript) { result, error in
            if let error = error {
            }
        }
    }
}
