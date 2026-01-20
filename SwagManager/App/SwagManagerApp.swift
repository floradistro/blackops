import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // CRITICAL FIX: Set activation policy to regular (not daemon/background)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        print("✅ App activation policy set to .regular")
    }
}

@main
struct SwagManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
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

            // MCP Server commands
            CommandMenu("MCP") {
                Button("New MCP Server...") {
                    NotificationCenter.default.post(name: NSNotification.Name("NewMCPServer"), object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .control])

                Divider()

                Button("Show MCP Servers") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowMCPServers"), object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button("Refresh MCP Servers") {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMCPServers"), object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .option])

                Button("Monitor MCP Servers") {
                    NotificationCenter.default.post(name: NSNotification.Name("MonitorMCPServers"), object: nil)
                }

                Divider()

                Button("MCP Server Documentation...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowMCPDocs"), object: nil)
                }
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
        }
    }
}

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var showNewCreationSheet = false
    @Published var showNewCollectionSheet = false
}
