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
    @State private var authManager = AuthManager.shared
    @State private var editorStore = EditorStore()
    @State private var toolbarState = ToolbarState()
    @State private var workflowService = WorkflowService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.authManager, authManager)
                .environment(\.editorStore, editorStore)
                .environment(\.toolbarState, toolbarState)
                .environment(\.telemetryService, TelemetryService.shared)
                .environment(\.workflowService, workflowService)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            FileMenuCommands(toolbarState: toolbarState)
            StoreMenuCommands(store: editorStore)
            AgentMenuCommands(store: editorStore, toolbarState: toolbarState)
            WorkflowMenuCommands(toolbarState: toolbarState)
        }

        Settings {
            SettingsView()
                .environment(\.authManager, authManager)
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

    private var menuTitle: String {
        guard let id = toolbarState.selectedAgentId,
              let agent = store.aiAgents.first(where: { $0.id == id }) else {
            return "Agent"
        }
        return agent.displayName
    }

    var body: some Commands {
        CommandMenu(menuTitle) {
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

// MARK: - Workflow Menu (macOS Menu Bar)
// Appears when a workflow canvas is active — actions grayed out otherwise

struct WorkflowMenuCommands: Commands {
    let toolbarState: ToolbarState

    var body: some Commands {
        CommandMenu("Workflow") {
            Button("Run") {
                toolbarState.workflowRunAction?()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(toolbarState.workflowRunAction == nil)

            Button("Publish") {
                toolbarState.workflowPublishAction?()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(toolbarState.workflowPublishAction == nil)

            Divider()

            Button("Fit to View") {
                toolbarState.workflowFitViewAction?()
            }
            .disabled(toolbarState.workflowFitViewAction == nil)

            Divider()

            // Add Step submenu — all step types from the palette
            Menu("Add Step") {
                Section("Execution") {
                    stepButton("Tool", type: "tool")
                    stepButton("Code", type: "code")
                    stepButton("Agent", type: "agent")
                    stepButton("Sub-Workflow", type: "sub_workflow")
                }
                Section("Flow Control") {
                    stepButton("Condition", type: "condition")
                    stepButton("Parallel", type: "parallel")
                    stepButton("For Each", type: "for_each")
                    stepButton("Delay", type: "delay")
                }
                Section("Integration") {
                    stepButton("Webhook", type: "webhook_out")
                    stepButton("Transform", type: "transform")
                }
                Section("Human") {
                    stepButton("Approval", type: "approval")
                    stepButton("Wait", type: "waitpoint")
                }
            }
            .disabled(toolbarState.workflowAddStepAction == nil)

            Divider()

            Button("Settings...") {
                toolbarState.workflowSettingsAction?()
            }
            .disabled(toolbarState.workflowSettingsAction == nil)

            Button("Versions") {
                toolbarState.workflowVersionsAction?()
            }
            .disabled(toolbarState.workflowVersionsAction == nil)

            Button("Webhooks") {
                toolbarState.workflowWebhooksAction?()
            }
            .disabled(toolbarState.workflowWebhooksAction == nil)

            Button("Metrics") {
                toolbarState.workflowMetricsAction?()
            }
            .disabled(toolbarState.workflowMetricsAction == nil)

            Button("Run History") {
                toolbarState.workflowRunHistoryAction?()
            }
            .disabled(toolbarState.workflowRunHistoryAction == nil)

            Button("Dead Letter Queue") {
                toolbarState.workflowDLQAction?()
            }
            .disabled(toolbarState.workflowDLQAction == nil)

            Divider()

            Button("Export as PNG") {
                toolbarState.workflowExportAction?()
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(toolbarState.workflowExportAction == nil)
        }
    }

    private func stepButton(_ label: String, type: String) -> some View {
        Button(label) {
            toolbarState.workflowAddStepAction?(type)
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
