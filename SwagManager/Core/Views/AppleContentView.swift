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

    @State private var activeView: ActiveView = .telemetry

    enum ActiveView: String, CaseIterable {
        case telemetry = "Telemetry"
        case workflows = "Workflows"

        var icon: String {
            switch self {
            case .telemetry: return "waveform.path.ecg"
            case .workflows: return "arrow.triangle.branch"
            }
        }

        var shortcut: KeyEquivalent {
            switch self {
            case .telemetry: return "1"
            case .workflows: return "2"
            }
        }
    }

    private var bindableToolbar: Bindable<ToolbarState> {
        Bindable(toolbarState)
    }

    var body: some View {
        Group {
            switch activeView {
            case .telemetry:
                TelemetryPanel(storeId: store.selectedStore?.id)
            case .workflows:
                WorkflowDashboard(storeId: store.selectedStore?.id)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            viewSwitcher
        }
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

    // MARK: - View Switcher

    private var viewSwitcher: some View {
        HStack(spacing: DS.Spacing.xxs) {
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

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 3)
        .background {
            DS.Colors.surfaceTertiary
                .overlay(alignment: .bottom) {
                    Divider().opacity(0.3)
                }
        }
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
