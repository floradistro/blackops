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

// MARK: - Window Vibrancy Configurator
// Wraps the hosting view inside an NSVisualEffectView so vibrancy
// covers the entire window including the title bar area.

struct WindowVibrancy: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = _WiringView()
        // Delay one runloop so the window + hosting view exist
        DispatchQueue.main.async { v.wireWindow() }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    class _WiringView: NSView {
        private static var configured = Set<ObjectIdentifier>()

        func wireWindow() {
            guard let window = self.window else { return }
            let key = ObjectIdentifier(window)
            guard !Self.configured.contains(key) else { return }
            Self.configured.insert(key)

            window.titlebarAppearsTransparent = true

            // Replace contentView with an NSVisualEffectView that wraps it
            guard let hostingView = window.contentView,
                  !(hostingView is NSVisualEffectView) else { return }

            let effectView = NSVisualEffectView()
            effectView.material = .sidebar
            effectView.blendingMode = .behindWindow
            effectView.state = .active

            // Reparent: effectView becomes contentView, hosting view goes inside
            window.contentView = effectView
            effectView.addSubview(hostingView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            ])
        }
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
