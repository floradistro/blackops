import SwiftUI
import AppKit

// MARK: - Vibrancy Background
// NSVisualEffectView for proper macOS frosted glass (not window transparency)

struct VibrancyBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Apple-Style Content View
// .hiddenTitleBar gives transparent title bar with traffic lights
// Agent selection via macOS menu bar; inspector toggled via Cmd+I

struct AppleContentView: View {
    @Environment(\.editorStore) private var store
    @Environment(\.toolbarState) private var toolbarState

    private var bindableToolbar: Bindable<ToolbarState> {
        Bindable(toolbarState)
    }

    var body: some View {
        TelemetryPanel(storeId: store.selectedStore?.id)
            .background(WindowVibrancy())
            .inspector(isPresented: bindableToolbar.showConfig) {
                inspectorContent
                    .inspectorColumnWidth(min: 300, ideal: 380, max: 500)
            }
            .task {
                await store.loadStores()
                if store.selectedStore != nil {
                    await store.loadAIAgents()
                }
            }
            .onChange(of: store.selectedStore?.id) { _, newId in
                toolbarState.selectedAgentId = nil
                toolbarState.agentHasChanges = false
                if newId != nil {
                    Task { await store.loadAIAgents() }
                }
            }
            .alert("Error", isPresented: Bindable(store).showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(store.error ?? "An unknown error occurred.")
            }
            .freezeDebugLifecycle("AppleContentView")
    }

    // MARK: - Inspector Content

    @ViewBuilder
    private var inspectorContent: some View {
        if let agentId = toolbarState.selectedAgentId,
           let agent = store.aiAgents.first(where: { $0.id == agentId }) {
            AgentConfigPanel(agent: agent)
        } else {
            ContentUnavailableView {
                Label("No Agent Selected", systemImage: "cpu")
            } description: {
                Text("Select an agent from the Agent menu.")
            }
        }
    }
}

#Preview {
    AppleContentView()
}
