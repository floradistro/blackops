import SwiftUI
import WebKit

// MARK: - Workflow Canvas
// React Flow canvas embedded via WKWebView with native overlays
// All drag, pan, zoom, connections handled by React Flow
// Native SwiftUI handles: toolbar, sheets, panels, keyboard shortcuts

struct WorkflowCanvas: View {
    let workflow: Workflow
    let storeId: UUID?

    /// Use the workflow's own store_id for API calls (avoids store mismatch errors)
    private var effectiveStoreId: UUID? {
        if let wsid = graph?.ownerStoreId, let uuid = UUID(uuidString: wsid) { return uuid }
        if let wsid = workflow.storeId, let uuid = UUID(uuidString: wsid) { return uuid }
        return storeId
    }

    @Binding var rightPanel: RightPanelType?
    @Binding var canvasGraph: WorkflowGraph?
    var runTelemetry: WorkflowTelemetryService?

    @Environment(\.workflowService) private var service
    @Environment(\.toolbarState) private var toolbarState

    // Bridge to React Flow
    @State private var bridge: CanvasBridge?

    // Graph data (kept for native panels)
    @State private var graph: WorkflowGraph?
    @State private var nodePositions: [String: CGPoint] = [:]
    @State private var selectedNodeId: String?
    @State private var selectedNodeIds: Set<String> = []
    @State private var liveStatus: [String: NodeStatus] = [:]

    // Agent token streaming
    @State private var agentTokens: [String: String] = [:]

    // Previous status for detecting transitions
    @State private var prevStatus: [String: String] = [:]

    // Command palette
    @State private var showCommandPalette = false

    // Outline panel
    @State private var showOutlinePanel = false

    // Cost estimator
    @State private var showEstimator = false

    // Canvas search
    @State private var showCanvasSearch = false

    // Error feedback
    @State private var runError: String?

    // Context menu
    @State private var contextMenuNode: GraphNode?

    // Position save debounce
    @State private var positionSaveTask: Task<Void, Never>?

    private var htmlURL: URL {
        Bundle.main.url(forResource: "index", withExtension: "html")
            ?? URL(fileURLWithPath: "/Users/whale/Desktop/blackops/SwagManager/Resources/index.html")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Canvas area — full bleed, no toolbar bar
            HStack(spacing: 0) {
                // Outline panel (left)
                if showOutlinePanel {
                    WorkflowOutlinePanel(
                        graph: graph,
                        liveStatus: liveStatus,
                        selectedNodeId: $selectedNodeId,
                        selectedNodeIds: $selectedNodeIds,
                        onEditStep: { node in
                            rightPanel = .stepEditor(node.id)
                        },
                        onDeleteStep: { nodeId in
                            deleteNode(nodeId)
                        },
                        onToggleEntryPoint: { node in
                            toggleEntryPoint(node)
                        }
                    )
                    .transition(.move(edge: .leading))
                }

                // Main canvas area
                ZStack {
                    // React Flow WebView
                    WorkflowCanvasWebView(
                        htmlURL: htmlURL,
                        bridge: $bridge,
                        onEvent: { event in handleCanvasEvent(event) }
                    )

                    // Floating overlays — title pill, fit button, play button
                    CanvasOverlay(
                        workflow: workflow,
                        onRun: startRun,
                        onFitToView: { bridge?.fitView() }
                    )

                    // Cost estimator overlay (top-right)
                    if showEstimator, let graph {
                        VStack {
                            HStack {
                                Spacer()
                                WorkflowEstimatorPanel(graph: graph)
                            }
                            Spacer()
                        }
                        .padding(DS.Spacing.md)
                    }

                    // Canvas search overlay (top center)
                    if showCanvasSearch, let graph {
                        VStack {
                            CanvasSearchOverlay(
                                isPresented: $showCanvasSearch,
                                nodes: graph.nodes,
                                nodePositions: nodePositions,
                                onNavigateToNode: { nodeId in
                                    bridge?.selectNode(nodeId)
                                    selectedNodeId = nodeId
                                    selectedNodeIds = [nodeId]
                                },
                                onDismiss: { showCanvasSearch = false }
                            )
                            .padding(.top, DS.Spacing.md)
                            Spacer()
                        }
                    }

                    // Command palette overlay
                    if showCommandPalette {
                        CommandPalette(isPresented: $showCommandPalette, onAction: handleCommandAction)
                    }
                }
            }
            .background(Color.black.opacity(0.15))
        }
        .task {
            await loadGraph()
            populateToolbarActions()
        }
        .onChange(of: workflow.id) { _, _ in
            Task {
                await loadGraph()
                populateToolbarActions()
            }
        }
        .onDisappear {
            toolbarState.resetWorkflow()
            runPollTask?.cancel()
        }
        .alert("Run Error", isPresented: .init(
            get: { runError != nil },
            set: { if !$0 { runError = nil } }
        )) {
            Button("OK") { runError = nil }
        } message: {
            Text(runError ?? "")
        }
        // Right-click context menu
        .sheet(item: $contextMenuNode) { node in
            contextMenuSheet(for: node)
        }
        // Keyboard shortcuts
        .onKeyPress("k", phases: .down) { press in
            if press.modifiers == .command {
                showCommandPalette.toggle()
                return .handled
            }
            return .ignored
        }
        .onKeyPress("d", phases: .down) { press in
            if press.modifiers == .command {
                if let id = selectedNodeId, let node = graph?.nodes.first(where: { $0.id == id }) {
                    duplicateNode(node)
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress("f", phases: .down) { press in
            if press.modifiers == .command {
                withAnimation(DS.Animation.fast) { showCanvasSearch.toggle() }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            selectedNodeId = nil
            selectedNodeIds.removeAll()
            return .handled
        }
    }

    // MARK: - Canvas Event Handling

    private func handleCanvasEvent(_ event: CanvasEvent) {
        switch event {
        case .ready:
            // WebView is ready — send graph data
            if graph != nil {
                sendGraphToBridge()
            }

        case .nodeSelected(let id):
            selectedNodeId = id
            selectedNodeIds = [id]

        case .nodeDoubleClicked(let id):
            if let node = graph?.nodes.first(where: { $0.id == id }) {
                rightPanel = .stepEditor(node.id)
            }

        case .nodeContextMenu(let id, _, _):
            selectedNodeId = id
            selectedNodeIds = [id]
            if let node = graph?.nodes.first(where: { $0.id == id }) {
                contextMenuNode = node
            }

        case .nodeMoved(let id, let x, let y):
            nodePositions[id] = CGPoint(x: x, y: y)
            saveNodePosition(id, position: CGPoint(x: x, y: y))

        case .edgeCreated(let from, let to, let edgeType):
            createEdge(from: from, to: to, edgeType: edgeType)

        case .nodesDeleted(let ids):
            for id in ids {
                deleteNode(id)
            }

        case .edgesDeleted(let edges):
            for edge in edges {
                removeEdge(from: edge.from, edgeType: edge.edgeType)
            }

        case .selectionChanged(let ids):
            selectedNodeIds = Set(ids)
            selectedNodeId = ids.first
        }
    }

    // MARK: - Graph Loading

    private func loadGraph() async {
        graph = await service.getGraph(workflowId: workflow.id, storeId: effectiveStoreId)
        canvasGraph = graph
        if let graph {
            // Build positions map from server data
            var positions: [String: CGPoint] = [:]
            for node in graph.nodes {
                if let pos = node.position {
                    positions[node.id] = CGPoint(x: pos.x, y: pos.y)
                }
            }
            nodePositions = positions
            liveStatus = graph.nodeStatus ?? [:]
            sendGraphToBridge()
        }
    }

    private func sendGraphToBridge() {
        guard let graph, let bridge else { return }

        let nodes: [[String: Any]] = graph.nodes.map { node in
            var dict: [String: Any] = [
                "id": node.id,
                "type": node.type,
                "label": node.label,
                "is_entry_point": node.isEntryPoint,
                "on_failure": node.onFailure as Any,
            ]

            // Position
            if let pos = node.position {
                dict["position"] = ["x": pos.x, "y": pos.y]
            } else if let localPos = nodePositions[node.id] {
                dict["position"] = ["x": localPos.x, "y": localPos.y]
            }

            // Step config for display name derivation
            if let sc = node.stepConfig {
                var cfg: [String: Any] = [:]
                for (k, v) in sc { cfg[k] = v.value }
                dict["stepConfig"] = cfg
            }

            return dict
        }

        let edges: [[String: Any]] = graph.edges.map { edge in
            var dict: [String: Any] = [
                "from": edge.from,
                "to": edge.to,
                "type": edge.type,
            ]
            if let label = edge.label { dict["label"] = label }
            return dict
        }

        bridge.loadGraph(nodes: nodes, edges: edges)

        // Send live status if any
        if !liveStatus.isEmpty {
            pushStatusToBridge()
        }
    }

    private func pushStatusToBridge() {
        guard let bridge else { return }
        var statuses: [String: [String: Any]] = [:]
        for (key, status) in liveStatus {
            var dict: [String: Any] = ["status": status.status]
            if let ms = status.durationMs { dict["duration_ms"] = ms }
            if let err = status.error { dict["error"] = err }
            if let tool = status.activeTool { dict["tool_name"] = tool }
            if let tokens = status.totalTokens { dict["token_count"] = tokens }
            if let cost = status.totalCost { dict["cost"] = cost }
            statuses[key] = dict
        }
        bridge.updateNodeStatus(statuses)

        // Detect transitions and animate edges
        for (key, status) in liveStatus {
            let prev = prevStatus[key]
            let current = status.status

            // When a step completes, highlight outgoing edges
            if prev == "running" && (current == "success" || current == "completed") {
                if let node = graph?.nodes.first(where: { $0.id == key }) {
                    if let successTarget = node.onSuccess, !successTarget.isEmpty {
                        bridge.highlightPath(fromKey: key, toKey: successTarget)
                    }
                    // Clear after 1.5s
                    Task {
                        try? await Task.sleep(for: .milliseconds(1500))
                        bridge.clearEdgeHighlights()
                    }
                }
            } else if prev == "running" && (current == "failed" || current == "error") {
                if let node = graph?.nodes.first(where: { $0.id == key }) {
                    if let failTarget = node.onFailure, !failTarget.isEmpty {
                        bridge.highlightPath(fromKey: key, toKey: failTarget)
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(1500))
                        bridge.clearEdgeHighlights()
                    }
                }
            }
        }

        // Update previous status
        var newPrev: [String: String] = [:]
        for (key, status) in liveStatus {
            newPrev[key] = status.status
        }
        prevStatus = newPrev
    }

    // MARK: - Actions

    private func addStep(stepType: String) {
        let existingKeys = Set(graph?.nodes.map(\.id) ?? [])
        let stepKey: String = {
            let base = stepType
            for i in 1...99 {
                let candidate = "\(base)_\(i)"
                if !existingKeys.contains(candidate) { return candidate }
            }
            return "\(base)_\(Int.random(in: 100...999))"
        }()

        // Place below existing nodes or at center
        let targetX: Double
        let targetY: Double
        if !nodePositions.isEmpty {
            let avgX = nodePositions.values.map(\.x).reduce(0, +) / CGFloat(nodePositions.count)
            let maxY = nodePositions.values.map(\.y).max() ?? 100
            targetX = avgX
            targetY = maxY + 150
        } else {
            targetX = 400
            targetY = 300
        }

        Task {
            if let step = await service.addStep(
                workflowId: workflow.id,
                stepKey: stepKey,
                stepType: stepType,
                config: [:],
                positionX: targetX,
                positionY: targetY,
                storeId: effectiveStoreId
            ) {
                nodePositions[step.stepKey] = CGPoint(x: targetX, y: targetY)
                await loadGraph()
                selectedNodeId = step.stepKey
                selectedNodeIds = [step.stepKey]
                bridge?.selectNode(step.stepKey)
            }
        }
    }

    private func deleteNode(_ nodeId: String) {
        // Resolve the DB UUID from the step_key
        let dbId = graph?.nodes.first(where: { $0.id == nodeId })?.stepId ?? nodeId
        Task {
            _ = await service.deleteStep(stepId: dbId, storeId: effectiveStoreId)
            selectedNodeId = nil
            selectedNodeIds.remove(nodeId)
            await loadGraph()
        }
    }

    private func duplicateNode(_ node: GraphNode) {
        let existingKeys = Set(graph?.nodes.map(\.id) ?? [])
        let newKey: String = {
            let base = node.type
            for i in 1...99 {
                let candidate = "\(base)_\(i)"
                if !existingKeys.contains(candidate) { return candidate }
            }
            return "\(base)_\(Int.random(in: 100...999))"
        }()
        let pos = nodePositions[node.id] ?? CGPoint(x: 300, y: 300)
        let offsetPos = CGPoint(x: pos.x + 50, y: pos.y + 50)

        var config: [String: Any] = [:]
        if let sc = node.stepConfig {
            for (k, v) in sc { config[k] = v.value }
        }

        Task {
            if let step = await service.addStep(
                workflowId: workflow.id,
                stepKey: newKey,
                stepType: node.type,
                config: config,
                positionX: offsetPos.x,
                positionY: offsetPos.y,
                storeId: effectiveStoreId
            ) {
                nodePositions[step.stepKey] = offsetPos
                await loadGraph()
                selectedNodeId = step.stepKey
                selectedNodeIds = [step.stepKey]
            }
        }
    }

    private func toggleEntryPoint(_ node: GraphNode) {
        let dbId = node.stepId ?? node.id
        Task {
            _ = await service.updateStep(
                stepId: dbId,
                updates: ["is_entry_point": !node.isEntryPoint],
                storeId: effectiveStoreId
            )
            await loadGraph()
        }
    }

    private func createEdge(from sourceId: String, to targetId: String, edgeType: String) {
        // React Flow already added the edge locally — just persist to server
        let dbId = graph?.nodes.first(where: { $0.id == sourceId })?.stepId ?? sourceId
        let updateKey = edgeType == "failure" ? "on_failure" : "on_success"
        Task {
            _ = await service.updateStep(
                stepId: dbId,
                updates: [updateKey: targetId],
                storeId: effectiveStoreId
            )
        }
    }

    private func removeEdge(from sourceId: String, edgeType: String) {
        // React Flow already removed the edge locally — just persist to server
        let dbId = graph?.nodes.first(where: { $0.id == sourceId })?.stepId ?? sourceId
        let updateKey = edgeType == "failure" ? "on_failure" : "on_success"
        Task {
            // Send empty string to clear the field (null not supported in JSON encoding)
            _ = await service.updateStep(
                stepId: dbId,
                updates: [updateKey: ""],
                storeId: effectiveStoreId
            )
        }
    }

    private func saveNodePosition(_ nodeId: String, position: CGPoint) {
        let dbId = graph?.nodes.first(where: { $0.id == nodeId })?.stepId ?? nodeId
        positionSaveTask?.cancel()
        positionSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            _ = await service.updateStep(
                stepId: dbId,
                updates: ["position_x": position.x, "position_y": position.y],
                storeId: effectiveStoreId
            )
        }
    }

    private func startRun() {
        Task {
            // Auto-activate draft workflows before running
            if !workflow.isActive || workflow.status == "draft" {
                _ = await service.updateWorkflow(
                    id: workflow.id,
                    updates: ["is_active": true, "status": "active"],
                    storeId: effectiveStoreId
                )
            }

            // Clear any stale error from previous operations
            let errorBefore = service.error
            service.error = nil

            if let run = await service.startRun(workflowId: workflow.id, storeId: effectiveStoreId) {
                runError = nil
                rightPanel = .run(run.id)
                pollRunStatus(run.id)
            } else {
                // Only show error if startRun actually set one
                let runErr = service.error
                if let runErr {
                    runError = runErr
                } else {
                    runError = "Failed to start workflow run"
                }
                print("[WorkflowCanvas] startRun failed — error: \(runError ?? "nil"), errorBefore: \(errorBefore ?? "nil")")
            }
        }
    }

    @State private var runPollTask: Task<Void, Never>?

    private func pollRunStatus(_ runId: String) {
        // Cancel any existing poll
        runPollTask?.cancel()

        runPollTask = Task {
            var isComplete = false
            var pollCount = 0

            while !Task.isCancelled && !isComplete {
                pollCount += 1

                // Fetch step runs for this run
                let stepRuns = await service.getStepRuns(runId: runId, storeId: effectiveStoreId)

                guard !Task.isCancelled else { break }

                // Update live status from step runs, enriched with telemetry
                for sr in stepRuns {
                    var newStatus = NodeStatus(
                        status: sr.status,
                        durationMs: sr.durationMs,
                        error: sr.error,
                        startedAt: sr.startedAt
                    )

                    // Enrich with telemetry data if available
                    if let tel = runTelemetry {
                        newStatus.activeTool = tel.activeTool(for: sr.stepKey)
                        let tokens = tel.tokenCount(for: sr.stepKey)
                        if tokens > 0 { newStatus.totalTokens = tokens }
                        let cost = tel.cost(for: sr.stepKey)
                        if cost > 0 { newStatus.totalCost = cost }
                        let spans = tel.spans(for: sr.stepKey)
                        if !spans.isEmpty { newStatus.spanCount = spans.count }
                    }

                    liveStatus[sr.stepKey] = newStatus
                }

                // Push to canvas bridge
                pushStatusToBridge()

                // Check if the overall run is complete
                let runs = await service.getRuns(workflowId: workflow.id, status: nil, limit: 1, storeId: effectiveStoreId)
                if let latestRun = runs.first(where: { $0.id == runId }) {
                    let runStatus = latestRun.status
                    if runStatus == "success" || runStatus == "failed" || runStatus == "cancelled" {
                        isComplete = true

                        // Do one final step_runs fetch to get all terminal statuses
                        let finalSteps = await service.getStepRuns(runId: runId, storeId: effectiveStoreId)
                        guard !Task.isCancelled else { break }

                        for sr in finalSteps {
                            liveStatus[sr.stepKey] = NodeStatus(
                                status: sr.status,
                                durationMs: sr.durationMs,
                                error: sr.error,
                                startedAt: sr.startedAt
                            )
                        }
                        pushStatusToBridge()

                        // Clear agent tokens
                        agentTokens.removeAll()

                        // Keep final statuses visible for 5 seconds, then clear
                        Task {
                            try? await Task.sleep(for: .seconds(5))
                            guard !Task.isCancelled else { return }
                            liveStatus.removeAll()
                            prevStatus.removeAll()
                            bridge?.clearStatus()
                            bridge?.clearEdgeHighlights()
                        }
                        break
                    }
                }

                // Poll interval: faster at start (running), slower later
                let interval: Duration = pollCount < 10 ? .milliseconds(1500) : .seconds(3)
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func publishWorkflow() {
        Task {
            _ = await service.publish(workflowId: workflow.id, changelog: nil, storeId: effectiveStoreId)
        }
    }

    @ViewBuilder
    private func contextMenuSheet(for node: GraphNode) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(node.displayName)
                    .font(.headline)
                Spacer()
                Button { contextMenuNode = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            VStack(spacing: 2) {
                contextMenuItem(icon: "pencil", label: "Edit Step") {
                    contextMenuNode = nil
                    rightPanel = .stepEditor(node.id)
                }
                contextMenuItem(icon: "play.circle", label: "Test Step") {
                    contextMenuNode = nil
                    rightPanel = .stepTest(node.id)
                }
                contextMenuItem(icon: "clock", label: "Run History") {
                    contextMenuNode = nil
                    rightPanel = .stepHistory(node.id)
                }
                contextMenuItem(icon: node.isEntryPoint ? "bolt.slash" : "bolt.fill",
                              label: node.isEntryPoint ? "Remove Entry Point" : "Set as Entry Point") {
                    contextMenuNode = nil
                    toggleEntryPoint(node)
                }
                Divider().padding(.vertical, 4)
                contextMenuItem(icon: "trash", label: "Delete", isDestructive: true) {
                    contextMenuNode = nil
                    deleteNode(node.id)
                }
            }
            .padding(8)
        }
        .frame(width: 240)
        .background(.ultraThinMaterial)
    }

    private func contextMenuItem(icon: String, label: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 18)
                    .foregroundStyle(isDestructive ? .red : .secondary)
                Text(label)
                    .font(.body)
                    .foregroundStyle(isDestructive ? .red : .primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.clear)
        )
    }

    private func exportCanvas() {
        guard let graph else { return }
        if let image = CanvasExporter.exportAsPNG(
            graph: graph,
            nodePositions: nodePositions,
            liveStatus: liveStatus
        ) {
            Task {
                _ = await CanvasExporter.saveAsPNG(image: image)
            }
        }
    }

    // MARK: - Toolbar State

    private func populateToolbarActions() {
        toolbarState.activeWorkflowName = workflow.name
        toolbarState.workflowRunAction = { startRun() }
        toolbarState.workflowPublishAction = { publishWorkflow() }
        toolbarState.workflowFitViewAction = { bridge?.fitView() }
        toolbarState.workflowSettingsAction = { rightPanel = .settings }
        toolbarState.workflowVersionsAction = { rightPanel = .versions }
        toolbarState.workflowWebhooksAction = { rightPanel = .webhooks }
        toolbarState.workflowDLQAction = { rightPanel = .dlq }
        toolbarState.workflowMetricsAction = { rightPanel = .metrics }
        toolbarState.workflowRunHistoryAction = { rightPanel = .runHistory }
        toolbarState.workflowExportAction = { exportCanvas() }
        toolbarState.workflowAddStepAction = { stepType in addStep(stepType: stepType) }
    }

    // MARK: - Command Palette

    private func handleCommandAction(_ action: CommandAction) {
        switch action {
        case .addTool: addStep(stepType: "tool")
        case .addCondition: addStep(stepType: "condition")
        case .addCode: addStep(stepType: "code")
        case .addAgent: addStep(stepType: "agent")
        case .addDelay: addStep(stepType: "delay")
        case .addWebhook: addStep(stepType: "webhook_out")
        case .addApproval: addStep(stepType: "approval")
        case .addParallel: addStep(stepType: "parallel")
        case .addForEach: addStep(stepType: "for_each")
        case .addSubWorkflow: addStep(stepType: "sub_workflow")
        case .addTransform: addStep(stepType: "transform")
        case .autoLayout, .fitToView: bridge?.fitView()
        case .zoomIn, .zoomOut, .resetZoom: bridge?.fitView()
        case .togglePalette: break // Palette moved to Workflow menu bar
        case .toggleOutline: withAnimation(DS.Animation.fast) { showOutlinePanel.toggle() }
        case .toggleMinimap: break // Minimap is in React Flow
        case .addStickyNote: break // Sticky notes removed (React handles annotations)
        case .exportPNG: exportCanvas()
        case .showEstimator: withAnimation(DS.Animation.fast) { showEstimator.toggle() }
        case .runWorkflow: startRun()
        case .publishWorkflow: publishWorkflow()
        case .openSettings: rightPanel = .settings
        case .openVersions: rightPanel = .versions
        case .openWebhooks: rightPanel = .webhooks
        case .openDLQ: rightPanel = .dlq
        case .openMetrics: rightPanel = .metrics
        case .openTrace: break
        case .testSelectedStep:
            if let id = selectedNodeId, let node = graph?.nodes.first(where: { $0.id == id }) {
                rightPanel = .stepTest(node.id)
            }
        case .showDependencies: rightPanel = .dependencies
        case .undo, .redo: break // Undo/redo handled by React Flow
        case .deleteSelected:
            if let id = selectedNodeId { deleteNode(id) }
        case .selectAll: break // Handled by React Flow
        }
    }
}
