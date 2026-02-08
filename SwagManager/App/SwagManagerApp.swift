import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {}
}

@main
struct SwagManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared
    @State private var editorStore = EditorStore()
    @State private var toolbarState = ToolbarState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environment(\.editorStore, editorStore)
                .environment(\.toolbarState, toolbarState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            FileMenuCommands(toolbarState: toolbarState)
            StoreMenuCommands(store: editorStore)
            AgentMenuCommands(store: editorStore, toolbarState: toolbarState)
        }

        Settings {
            SettingsView()
                .environmentObject(authManager)
        }
    }
}

// MARK: - File Menu Commands (Save / Discard)

struct FileMenuCommands: Commands {
    let toolbarState: ToolbarState

    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                Task { @MainActor in
                    await toolbarState.saveAction?()
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(toolbarState.saveAction == nil || !toolbarState.agentHasChanges || toolbarState.agentIsSaving)

            Button("Discard Changes") {
                toolbarState.discardAction?()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(toolbarState.discardAction == nil || !toolbarState.agentHasChanges)
        }
    }
}

// MARK: - Agent Menu (macOS Menu Bar)
// Appears in the system menu bar: SwagManager > Agent > [agents list]

struct AgentMenuCommands: Commands {
    let store: EditorStore
    let toolbarState: ToolbarState

    var body: some Commands {
        CommandMenu("Agent") {
            ForEach(store.aiAgents) { agent in
                Button {
                    Task { @MainActor in
                        toolbarState.selectedAgentId = agent.id
                    }
                } label: {
                    if toolbarState.selectedAgentId == agent.id {
                        Text("✓ \(agent.displayName)")
                    } else {
                        Text("   \(agent.displayName)")
                    }
                }
            }

            if store.aiAgents.isEmpty {
                Text("No agents")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("New Agent...") {
                Task { @MainActor in
                    _ = await store.createAgent(name: "New Agent", systemPrompt: "You are a helpful assistant.")
                    await store.loadAIAgents()
                }
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Divider()

            Button(toolbarState.showConfig ? "Hide Config Inspector" : "Show Config Inspector") {
                Task { @MainActor in
                    toolbarState.showConfig.toggle()
                }
            }
            .keyboardShortcut("i", modifiers: .command)
        }
    }
}

// MARK: - Store Menu (macOS Menu Bar)
// Appears in the system menu bar: SwagManager > Store > [stores list]

struct StoreMenuCommands: Commands {
    let store: EditorStore

    var body: some Commands {
        CommandMenu("Store") {
            // List all stores with checkmark on selected
            ForEach(store.stores) { s in
                Button {
                    Task { @MainActor in
                        await store.selectStore(s)
                        await store.loadAIAgents()
                    }
                } label: {
                    Text(s.storeName)
                }
                .disabled(store.selectedStore?.id == s.id)
            }

            if store.stores.isEmpty {
                Text("Loading stores...")
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Show agents for current store
            if !store.aiAgents.isEmpty {
                Section("Agents") {
                    ForEach(store.aiAgents) { agent in
                        HStack {
                            Text(agent.displayName)
                            Spacer()
                            if agent.isActive {
                                Image(systemName: "circle.fill")
                            }
                        }
                    }
                }

                Divider()
            }

            Button("Add Store...") {
                store.showNewStoreSheet = true
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("Refresh") {
                Task { @MainActor in
                    await store.loadStores()
                    await store.loadAIAgents()
                }
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}
