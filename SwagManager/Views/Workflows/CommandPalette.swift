import SwiftUI

// MARK: - Command Action

enum CommandAction: String, CaseIterable, Hashable {
    // Add steps
    case addTool
    case addCondition
    case addCode
    case addAgent
    case addDelay
    case addWebhook
    case addApproval
    case addParallel
    case addForEach
    case addSubWorkflow
    case addTransform

    // Canvas actions
    case autoLayout
    case fitToView
    case zoomIn
    case zoomOut
    case resetZoom
    case togglePalette
    case toggleOutline
    case toggleMinimap
    case addStickyNote
    case exportPNG
    case showEstimator

    // Panels
    case openTrace
    case testSelectedStep
    case showDependencies

    // Workflow actions
    case runWorkflow
    case publishWorkflow
    case openSettings
    case openVersions
    case openWebhooks
    case openDLQ
    case openMetrics

    // Edit actions
    case undo
    case redo
    case deleteSelected
    case selectAll

    var label: String {
        switch self {
        case .addTool: return "Add Tool Step"
        case .addCondition: return "Add Condition"
        case .addCode: return "Add Code Step"
        case .addAgent: return "Add Agent Step"
        case .addDelay: return "Add Delay"
        case .addWebhook: return "Add Webhook"
        case .addApproval: return "Add Approval"
        case .addParallel: return "Add Parallel"
        case .addForEach: return "Add For-Each"
        case .addSubWorkflow: return "Add Sub-Workflow"
        case .addTransform: return "Add Transform"
        case .autoLayout: return "Auto Layout"
        case .fitToView: return "Fit to View"
        case .zoomIn: return "Zoom In"
        case .zoomOut: return "Zoom Out"
        case .resetZoom: return "Reset Zoom"
        case .togglePalette: return "Toggle Step Palette"
        case .toggleOutline: return "Toggle Outline Panel"
        case .toggleMinimap: return "Toggle Minimap"
        case .addStickyNote: return "Add Sticky Note"
        case .exportPNG: return "Export as PNG"
        case .showEstimator: return "Show Cost Estimator"
        case .openTrace: return "Show Execution Trace"
        case .testSelectedStep: return "Test Selected Step"
        case .showDependencies: return "Show Dependencies"
        case .runWorkflow: return "Run Workflow"
        case .publishWorkflow: return "Publish Workflow"
        case .openSettings: return "Open Settings"
        case .openVersions: return "Show Versions"
        case .openWebhooks: return "Show Webhooks"
        case .openDLQ: return "Show Dead Letter Queue"
        case .openMetrics: return "Show Metrics"
        case .undo: return "Undo"
        case .redo: return "Redo"
        case .deleteSelected: return "Delete Selected Node"
        case .selectAll: return "Select All"
        }
    }

    var icon: String {
        switch self {
        case .addTool: return "hammer.fill"
        case .addCondition: return "point.3.filled.connected.trianglepath.dotted"
        case .addCode: return "terminal.fill"
        case .addAgent: return "brain.fill"
        case .addDelay: return "hourglass"
        case .addWebhook: return "paperplane.fill"
        case .addApproval: return "checkmark.seal.fill"
        case .addParallel: return "arrow.triangle.branch"
        case .addForEach: return "arrow.3.trianglepath"
        case .addSubWorkflow: return "arrow.triangle.capsulepath"
        case .addTransform: return "wand.and.rays"
        case .autoLayout: return "squares.leading.rectangle"
        case .fitToView: return "viewfinder"
        case .zoomIn: return "plus.magnifyingglass"
        case .zoomOut: return "minus.magnifyingglass"
        case .resetZoom: return "1.magnifyingglass"
        case .togglePalette: return "square.grid.2x2"
        case .toggleOutline: return "list.bullet.indent"
        case .toggleMinimap: return "map.fill"
        case .addStickyNote: return "note.text"
        case .exportPNG: return "square.and.arrow.up.on.square.fill"
        case .showEstimator: return "dollarsign.gauge.chart.lefthalf.righthalf"
        case .openTrace: return "chart.bar.xaxis.ascending"
        case .testSelectedStep: return "play.rectangle.fill"
        case .showDependencies: return "point.3.filled.connected.trianglepath.dotted"
        case .runWorkflow: return "play.fill"
        case .publishWorkflow: return "arrow.up.circle.fill"
        case .openSettings: return "gearshape.fill"
        case .openVersions: return "clock.badge.checkmark.fill"
        case .openWebhooks: return "antenna.radiowaves.left.and.right"
        case .openDLQ: return "exclamationmark.warninglight.fill"
        case .openMetrics: return "chart.bar.xaxis.ascending"
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .deleteSelected: return "trash.fill"
        case .selectAll: return "checkmark.circle.fill"
        }
    }

    var shortcutHint: String? {
        switch self {
        case .undo: return "\u{2318}Z"
        case .redo: return "\u{21E7}\u{2318}Z"
        case .runWorkflow: return "\u{2318}R"
        case .publishWorkflow: return "\u{2318}P"
        case .deleteSelected: return "\u{232B}"
        case .fitToView: return "\u{2318}1"
        case .zoomIn: return "\u{2318}+"
        case .zoomOut: return "\u{2318}-"
        case .selectAll: return "\u{2318}A"
        case .exportPNG: return "\u{2318}E"
        default: return nil
        }
    }

    var category: String {
        switch self {
        case .addTool, .addCondition, .addCode, .addAgent, .addDelay, .addWebhook,
             .addApproval, .addParallel, .addForEach, .addSubWorkflow, .addTransform:
            return "Add Step"
        case .autoLayout, .fitToView, .zoomIn, .zoomOut, .resetZoom, .togglePalette, .toggleOutline, .toggleMinimap, .addStickyNote, .exportPNG, .showEstimator:
            return "Canvas"
        case .runWorkflow, .publishWorkflow, .openSettings, .openVersions, .openWebhooks, .openDLQ, .openMetrics, .openTrace, .testSelectedStep, .showDependencies:
            return "Workflow"
        case .undo, .redo, .deleteSelected, .selectAll:
            return "Edit"
        }
    }
}

// MARK: - Command Palette

struct CommandPalette: View {
    @Binding var isPresented: Bool
    let onAction: (CommandAction) -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    // MARK: - Filtered Actions

    private var filteredActions: [CommandAction] {
        if query.isEmpty { return CommandAction.allCases }
        let q = query.lowercased()
        return CommandAction.allCases.filter {
            $0.label.lowercased().contains(q) || $0.category.lowercased().contains(q)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                // Search field
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(DesignSystem.font(14))
                        .foregroundStyle(DS.Colors.textTertiary)

                    TextField("Type a command...", text: $query)
                        .textFieldStyle(.plain)
                        .font(DS.Typography.body)
                        .focused($isSearchFocused)
                }
                .padding(DS.Spacing.md)

                Divider().opacity(0.3)

                // Results
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredActions.enumerated()), id: \.element) { index, action in
                                commandRow(action, isHighlighted: index == selectedIndex)
                                    .id(index)
                                    .onTapGesture {
                                        executeAction(action)
                                    }
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation(DS.Animation.fast) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
            .frame(width: 480)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .strokeBorder(DS.Colors.border, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .padding(.top, 80)
            .onAppear {
                isSearchFocused = true
                selectedIndex = 0
            }
            .onChange(of: query) { _, _ in
                selectedIndex = 0
            }
            .onKeyPress(.upArrow) {
                selectedIndex = max(0, selectedIndex - 1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                selectedIndex = min(filteredActions.count - 1, selectedIndex + 1)
                return .handled
            }
            .onKeyPress(.return) {
                if let action = filteredActions[safe: selectedIndex] {
                    executeAction(action)
                }
                return .handled
            }
            .onKeyPress(.escape) {
                isPresented = false
                return .handled
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Command Row

    private func commandRow(_ action: CommandAction, isHighlighted: Bool) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: action.icon)
                .font(DesignSystem.font(12))
                .foregroundStyle(DS.Colors.textSecondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 0) {
                Text(action.label)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(action.category)
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            Spacer()

            if let hint = action.shortcutHint {
                Text(hint)
                    .font(DS.Typography.monoSmall)
                    .foregroundStyle(DS.Colors.textQuaternary)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(isHighlighted ? DS.Colors.selectionActive : Color.clear)
        .contentShape(Rectangle())
    }

    // MARK: - Execute

    private func executeAction(_ action: CommandAction) {
        isPresented = false
        onAction(action)
    }
}

// MARK: - Safe Collection Subscript

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
