import SwiftUI
import AppKit

@main
struct SwagManagerApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }

            // Zoom commands for browser
            CommandGroup(after: .sidebar) {
                Button("Zoom In") {
                    NotificationCenter.default.post(name: NSNotification.Name("ZoomIn"), object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    NotificationCenter.default.post(name: NSNotification.Name("ZoomOut"), object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    NotificationCenter.default.post(name: NSNotification.Name("ZoomReset"), object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(authManager)
                .preferredColorScheme(.dark)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)

        // Configure all windows with glass effect
        configureAllWindows()

        // Watch for new windows
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let window = notification.object as? NSWindow {
                self?.configureWindow(window)
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        configureAllWindows()
    }

    private func configureAllWindows() {
        for window in NSApp.windows {
            configureWindow(window)
        }
    }

    private func configureWindow(_ window: NSWindow) {
        // Terminal-style minimal window chrome with glass effect
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false

        // Configure toolbar - slim and minimal like Safari
        if let toolbar = window.toolbar {
            toolbar.showsBaselineSeparator = true

            // Make toolbar slimmer by setting size mode
            if #available(macOS 11.0, *) {
                toolbar.displayMode = .iconOnly
            }
        }

        // Set the window's titlebar to be compact
        if let contentView = window.contentView {
            contentView.wantsLayer = true
        }

        // Ensure window is key and accepts input
        if window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
        }
    }
}

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var showNewCreationSheet = false
    @Published var showNewCollectionSheet = false
}
