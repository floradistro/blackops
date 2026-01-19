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
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Store...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowNewStore"), object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            // Store selector
            CommandMenu("Store") {
                Button("Switch Store...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowStoreSelector"), object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("Store Settings...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowStoreSettings"), object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command, .option])
            }

            // View commands
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleSidebar"), object: nil)
                }
                .keyboardShortcut("\\", modifiers: .command)

                Divider()

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

                Divider()

                Button("Find...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowSearch"), object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            // Browser commands
            CommandMenu("Browser") {
                Button("New Tab") {
                    NotificationCenter.default.post(name: NSNotification.Name("BrowserNewTab"), object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Reload Page") {
                    NotificationCenter.default.post(name: NSNotification.Name("BrowserReload"), object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Back") {
                    NotificationCenter.default.post(name: NSNotification.Name("BrowserBack"), object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Forward") {
                    NotificationCenter.default.post(name: NSNotification.Name("BrowserForward"), object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)
            }

            // File commands
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    NotificationCenter.default.post(name: NSNotification.Name("SaveDocument"), object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
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
        // Minimal unified titlebar with glass effect
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unifiedCompact
        window.isMovableByWindowBackground = true

        // Transparent background for glass effect
        window.backgroundColor = .clear
        window.isOpaque = false

        // Configure toolbar appearance
        if let toolbar = window.toolbar {
            toolbar.showsBaselineSeparator = false
        }

        // Set the window's titlebar to be compact
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
        }

        // Handle fullscreen transitions properly
        window.collectionBehavior.insert(.fullScreenPrimary)

        // Add observer for fullscreen changes - maintain glass effect
        NotificationCenter.default.addObserver(
            forName: NSWindow.willEnterFullScreenNotification,
            object: window,
            queue: .main
        ) { _ in
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .clear
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didExitFullScreenNotification,
            object: window,
            queue: .main
        ) { _ in
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .clear
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
