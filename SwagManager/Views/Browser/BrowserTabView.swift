//
//  BrowserTabView.swift
//  SwagManager
//
//  Individual tab content view
//

import SwiftUI
import WebKit
import AVKit

struct BrowserTabView: View {
    @ObservedObject var tab: BrowserTab

    var body: some View {
        SimpleWebView(tab: tab)
    }
}

// MARK: - Simple WebView Wrapper

struct SimpleWebView: NSViewRepresentable {
    @ObservedObject var tab: BrowserTab

    func makeNSView(context: Context) -> WKWebView {
        // Create simple WKWebView configuration
        let config = WKWebViewConfiguration()

        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true

        // Enable fullscreen for videos
        #if os(macOS)
        if #available(macOS 10.15, *) {
            preferences.setValue(true, forKey: "elementFullscreenEnabled")
        }
        #endif

        config.preferences = preferences

        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = webpagePrefs

        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Store reference
        tab.webView = webView

        // Load URL
        if let urlString = tab.currentURL, let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        } else {
            if let url = URL(string: "https://www.google.com") {
                webView.load(URLRequest(url: url))
            }
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let tab: BrowserTab

        init(tab: BrowserTab) {
            self.tab = tab
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.tab.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.tab.isLoading = false
                self.tab.canGoBack = webView.canGoBack
                self.tab.canGoForward = webView.canGoForward
                self.tab.currentURL = webView.url?.absoluteString
                self.tab.pageTitle = webView.title
                self.tab.isSecure = webView.url?.scheme == "https"
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.tab.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.tab.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
