//
//  BrowserTabManager.swift
//  SwagManager
//
//  Manages browser tabs Safari-style
//

import SwiftUI
import WebKit

// MARK: - Browser Tab Model

class BrowserTab: Identifiable, ObservableObject {
    let id = UUID()
    @Published var currentURL: String?
    @Published var pageTitle: String?
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isDarkMode = false
    @Published var isSecure = false

    var webView: WKWebView?

    init(url: String? = nil) {
        self.currentURL = url
    }

    func navigate(to urlString: String) {
        guard let webView = webView, let url = URL(string: urlString) else { return }
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func refresh() {
        webView?.reload()
    }

    func stop() {
        webView?.stopLoading()
    }

    func toggleDarkMode() {
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

// MARK: - Browser Tab Manager

class BrowserTabManager: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var activeTab: BrowserTab?

    func newTab(url: String? = nil) {
        let tab = BrowserTab(url: url)
        tabs.append(tab)
        selectTab(tab)
    }

    func selectTab(_ tab: BrowserTab) {
        activeTab = tab
    }

    func closeTab(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }

        tabs.remove(at: index)

        // Select adjacent tab or create new one
        if tabs.isEmpty {
            newTab()
        } else if activeTab?.id == tab.id {
            let newIndex = min(index, tabs.count - 1)
            activeTab = tabs[newIndex]
        }
    }
}
