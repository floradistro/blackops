import SwiftUI
import WebKit

// MARK: - Hot Reload Components (REFACTORED - Apple Standard)
//
// Reduced from 883 lines to ~140 lines by extracting HTML template:
// - ReactRenderTemplate.swift (745 lines) - React rendering HTML template
//
// File size: ~140 lines (under Apple's 300 line "excellent" threshold)
//
// These components provide live React rendering for creations with hot reload support.

// MARK: - Hot Reload Renderer

struct HotReloadRenderer: View {
    let code: String
    let creationId: String
    let refreshTrigger: UUID

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var currentCode: String = ""
    @State private var hasInitialized = false
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HotReloadWebView(
                html: ReactRenderTemplate.buildHTML(code: currentCode),
                isLoading: $isLoading,
                loadError: $loadError
            )
            .id(currentCode.hashValue)
            .opacity(opacity)

            if isLoading && !hasInitialized {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .colorScheme(.dark)
                    Text("Rendering...")
                        .foregroundStyle(.white)
                }
            }

            if currentCode.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)
                    Text("No code to preview")
                        .foregroundStyle(.gray)
                }
            }

            if let error = loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Render Error")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .onAppear {
            currentCode = code
        }
        .onChange(of: code) { oldCode, newCode in
            if oldCode != newCode && !newCode.isEmpty {
                hasInitialized = true
                loadError = nil
                withAnimation(.easeOut(duration: 0.1)) { opacity = 0.7 }
                let temp = currentCode
                currentCode = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    currentCode = temp
                    withAnimation(.easeIn(duration: 0.15)) { opacity = 1.0 }
                }
            }
        }
        .onChange(of: refreshTrigger) { _, _ in
            if !code.isEmpty {
                withAnimation(.easeOut(duration: 0.1)) { opacity = 0.7 }
                let temp = currentCode
                currentCode = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    currentCode = temp
                    withAnimation(.easeIn(duration: 0.15)) { opacity = 1.0 }
                }
            }
        }
    }
}

// MARK: - Hot Reload WebView

struct HotReloadWebView: NSViewRepresentable {
    let html: String
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, loadError: $loadError)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var loadError: String?

        init(isLoading: Binding<Bool>, loadError: Binding<String?>) {
            _isLoading = isLoading
            _loadError = loadError
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            loadError = error.localizedDescription
        }
    }
}
