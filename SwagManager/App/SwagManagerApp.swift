import SwiftUI
import SwiftData
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // CRITICAL FIX: Set activation policy to regular (not daemon/background)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Configure URLCache for persistent image caching (survives app restart)
        // Apple's approach: aggressive disk caching for images
        let memoryCapacity = 100 * 1024 * 1024   // 100 MB memory
        let diskCapacity = 1024 * 1024 * 1024    // 1 GB disk (persistent)
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
        URLCache.shared = cache

        // Start local agent server for AI chat with local file tools
        AgentProcessManager.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop the agent server when app quits
        AgentProcessManager.shared.stop()
    }
}

@main
struct SwagManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var appState = AppState.shared

    // SwiftData container for local persistence
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                SDOrder.self,
                SDLocation.self,
                SDCustomer.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(appState)
                .modelContainer(modelContainer)
                .frame(minWidth: 900, minHeight: 600)
        }
        // Translucent toolbar matching sidebar vibrancy
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
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

            // Tab commands
            CommandGroup(replacing: .windowArrangement) {
                Button("Close Tab") {
                    NotificationCenter.default.post(name: NSNotification.Name("CloseTab"), object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)

                Divider()

                Button("Previous Tab") {
                    NotificationCenter.default.post(name: NSNotification.Name("PreviousTab"), object: nil)
                }
                .keyboardShortcut(KeyEquivalent.leftArrow, modifiers: [.command, .option])

                Button("Next Tab") {
                    NotificationCenter.default.post(name: NSNotification.Name("NextTab"), object: nil)
                }
                .keyboardShortcut(KeyEquivalent.rightArrow, modifiers: [.command, .option])

                Divider()

                // Cmd+1-9 for tab selection
                Button("Show Tab 1") {
                    NotificationCenter.default.post(name: NSNotification.Name("SelectTab1"), object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Show Tab 2") {
                    NotificationCenter.default.post(name: NSNotification.Name("SelectTab2"), object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Show Tab 3") {
                    NotificationCenter.default.post(name: NSNotification.Name("SelectTab3"), object: nil)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Show Tab 4") {
                    NotificationCenter.default.post(name: NSNotification.Name("SelectTab4"), object: nil)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Show Tab 5") {
                    NotificationCenter.default.post(name: NSNotification.Name("SelectTab5"), object: nil)
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("Show Tab 6") {
                    NotificationCenter.default.post(name: NSNotification.Name("SelectTab6"), object: nil)
                }
                .keyboardShortcut("6", modifiers: .command)

                Button("Show Tab 7") {
                    NotificationCenter.default.post(name: NSNotification.Name("SelectTab7"), object: nil)
                }
                .keyboardShortcut("7", modifiers: .command)

                Button("Show Tab 8") {
                    NotificationCenter.default.post(name: NSNotification.Name("SelectTab8"), object: nil)
                }
                .keyboardShortcut("8", modifiers: .command)

                Button("Show Last Tab") {
                    NotificationCenter.default.post(name: NSNotification.Name("SelectTab9"), object: nil)
                }
                .keyboardShortcut("9", modifiers: .command)
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
        }
    }
}

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var showNewCreationSheet = false
    @Published var showNewCollectionSheet = false
}
