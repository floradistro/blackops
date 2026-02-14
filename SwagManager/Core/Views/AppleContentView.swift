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
// View switcher sits in the title bar region; ignoresSafeArea fills from y=0
// Agent selection via macOS menu bar; inspector toggled via Cmd+I

struct AppleContentView: View {
    @Environment(\.editorStore) private var store
    @Environment(\.toolbarState) private var toolbarState

    @State private var activeView: ActiveView = .telemetry

    enum ActiveView: String, CaseIterable {
        case telemetry = "Telemetry"
        case workflows = "Workflows"

        var icon: String {
            switch self {
            case .telemetry: return "chart.line.flattrend.xyaxis"
            case .workflows: return "point.3.filled.connected.trianglepath.dotted"
            }
        }
    }

    private var bindableToolbar: Bindable<ToolbarState> {
        Bindable(toolbarState)
    }

    var body: some View {
        // HSplitView (AppKit NSSplitView) must be the root content — no VStack,
        // padding, or safeAreaInset wrappers. View switcher floats via overlay
        // in the sidebar/title-bar area; each panel's sidebar adds top padding.
        Group {
            switch activeView {
            case .telemetry:
                TelemetryPanel(storeId: store.selectedStore?.id)
            case .workflows:
                WorkflowDashboard(storeId: store.selectedStore?.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            viewSwitcher
        }
        .ignoresSafeArea(.container, edges: .top)
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
        .keyboardShortcut("1", modifiers: .command, action: { activeView = .telemetry })
        .keyboardShortcut("2", modifiers: .command, action: { activeView = .workflows })
        .freezeDebugLifecycle("AppleContentView")
    }

    // MARK: - View Switcher (Title Bar Region)
    // Sits at y=0 with left padding to clear traffic light buttons (close/min/zoom)
    // Traffic lights on macOS: close ~x12, minimize ~x32, zoom ~x52, each ~12pt wide

    private var viewSwitcher: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(ActiveView.allCases, id: \.self) { view in
                Button {
                    withAnimation(DS.Animation.fast) {
                        activeView = view
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: view.icon)
                            .font(DesignSystem.font(10, weight: .medium))
                        Text(view.rawValue)
                            .font(DS.Typography.monoCaption)
                            .textCase(.uppercase)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(
                        activeView == view ? DS.Colors.surfaceActive : Color.clear,
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                    )
                    .foregroundStyle(activeView == view ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 76)
        .padding(.trailing, DS.Spacing.sm)
        .frame(height: 28, alignment: .center)
    }

    // MARK: - Inspector Content

    @ViewBuilder
    private var inspectorContent: some View {
        if let agentId = toolbarState.selectedAgentId,
           let agent = store.aiAgents.first(where: { $0.id == agentId }) {
            AgentConfigPanel(agent: agent)
        } else {
            ContentUnavailableView {
                Label("No Agent Selected", systemImage: "brain")
            } description: {
                Text("Select an agent from the Agent menu.")
            }
        }
    }
}

// MARK: - Keyboard Shortcut View Extension

private extension View {
    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        self.background(
            Button("") { action() }
                .keyboardShortcut(key, modifiers: modifiers)
                .frame(width: 0, height: 0)
                .opacity(0)
        )
    }
}

#Preview {
    AppleContentView()
}
