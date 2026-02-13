import SwiftUI

// MARK: - Workflow Canvas
// Zoomable, pannable DAG canvas with step nodes and connections
// Renders workflow graph from server's `graph` action

struct WorkflowCanvas: View {
    let workflow: Workflow
    let storeId: UUID?

    @Binding var activeRunId: String?
    @Binding var showRunPanel: Bool

    @Environment(\.workflowService) private var service

    // Canvas state
    @State private var graph: WorkflowGraph?
    @State private var nodePositions: [String: CGPoint] = [:]
    @State private var zoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var selectedNodeId: String?
    @State private var liveStatus: [String: NodeStatus] = [:]

    // Editing
    @State private var showStepEditor = false
    @State private var editingStep: GraphNode?
    @State private var showPalette = true
    @State private var isDraggingNode = false

    // Drag tracking (to correctly handle cumulative translation)
    @State private var dragStartPosition: CGPoint?
    @State private var panStartOffset: CGSize?

    // Undo
    @State private var undoStack: [CanvasAction] = []

    // Position save debounce
    @State private var positionSaveTask: Task<Void, Never>?

    enum CanvasAction {
        case moveNode(id: String, from: CGPoint, to: CGPoint)
        case addNode(id: String)
        case deleteNode(id: String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            CanvasToolbar(
                workflow: workflow,
                storeId: storeId,
                zoom: $zoom,
                showPalette: $showPalette,
                onRun: startRun,
                onPublish: publishWorkflow,
                onAutoLayout: autoLayout,
                onFitToView: fitToView
            )

            // Canvas area
            ZStack {
                // Background grid
                canvasBackground

                // Transformed content (zoom + pan)
                canvasContent
                    .scaleEffect(zoom)
                    .offset(panOffset)
                    .gesture(panGesture)
                    .gesture(magnificationGesture)

                // Step palette overlay
                if showPalette {
                    VStack {
                        Spacer()
                        StepPalette(onAddStep: addStepAtCenter)
                            .padding(DS.Spacing.lg)
                    }
                }
            }
            .clipped()
            .background(Color.black.opacity(0.15))
        }
        .task {
            await loadGraph()
        }
        .onChange(of: workflow.id) { _, _ in
            Task { await loadGraph() }
        }
        .sheet(isPresented: $showStepEditor) {
            if let node = editingStep {
                StepEditorSheet(
                    node: node,
                    workflowId: workflow.id,
                    storeId: storeId,
                    existingStepKeys: Set(graph?.nodes.map(\.id) ?? []),
                    onSaved: { Task { await loadGraph() } }
                )
            }
        }
        .onKeyPress(.delete) {
            if let id = selectedNodeId { deleteSelectedNode(id) }
            return selectedNodeId != nil ? .handled : .ignored
        }
    }

    // MARK: - Canvas Background

    private var canvasBackground: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 20 * zoom
            let offsetX = panOffset.width.truncatingRemainder(dividingBy: gridSize)
            let offsetY = panOffset.height.truncatingRemainder(dividingBy: gridSize)

            for x in stride(from: offsetX, through: size.width, by: gridSize) {
                for y in stride(from: offsetY, through: size.height, by: gridSize) {
                    context.fill(
                        Circle().path(in: CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1)),
                        with: .color(.white.opacity(0.06))
                    )
                }
            }
        }
    }

    // MARK: - Canvas Content

    @ViewBuilder
    private var canvasContent: some View {
        ZStack {
            // Edges
            if let graph {
                ConnectionLayer(
                    edges: graph.edges,
                    nodePositions: nodePositions,
                    nodeStatus: liveStatus,
                    nodeSize: CGSize(width: 200, height: 80)
                )
            }

            // Nodes
            if let graph {
                ForEach(graph.nodes) { node in
                    nodeView(node)
                }
            }
        }
    }

    @ViewBuilder
    private func nodeView(_ node: GraphNode) -> some View {
        let position = nodePositions[node.id] ?? CGPoint(x: 300, y: 300)
        let isSelected = selectedNodeId == node.id
        let status = liveStatus[node.id]

        WorkflowNode(
            node: node,
            isSelected: isSelected,
            status: status
        )
        .position(position)
        .onTapGesture(count: 2) {
            editingStep = node
            showStepEditor = true
        }
        .onTapGesture {
            withAnimation(DS.Animation.fast) {
                selectedNodeId = node.id
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDraggingNode = true
                    if dragStartPosition == nil {
                        dragStartPosition = nodePositions[node.id] ?? position
                    }
                    let start = dragStartPosition!
                    nodePositions[node.id] = CGPoint(
                        x: start.x + value.translation.width / zoom,
                        y: start.y + value.translation.height / zoom
                    )
                }
                .onEnded { _ in
                    isDraggingNode = false
                    dragStartPosition = nil
                    let finalPos = nodePositions[node.id] ?? position
                    saveNodePosition(node.id, position: finalPos)
                }
        )
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isDraggingNode else { return }
                if panStartOffset == nil {
                    panStartOffset = panOffset
                }
                let start = panStartOffset!
                panOffset = CGSize(
                    width: start.width + value.translation.width,
                    height: start.height + value.translation.height
                )
            }
            .onEnded { _ in
                panStartOffset = nil
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = max(0.25, min(3.0, value.magnification))
            }
    }

    // MARK: - Actions

    private func loadGraph() async {
        graph = await service.getGraph(workflowId: workflow.id, storeId: storeId)
        if let graph {
            // Apply positions from graph or auto-layout
            var positions: [String: CGPoint] = [:]
            var needsAutoLayout = false

            for node in graph.nodes {
                if let pos = node.position {
                    positions[node.id] = CGPoint(x: pos.x, y: pos.y)
                } else {
                    needsAutoLayout = true
                }
            }

            if needsAutoLayout {
                positions = autoLayoutPositions(graph)
            }

            nodePositions = positions
            liveStatus = graph.nodeStatus ?? [:]
        }
    }

    private func startRun() {
        Task {
            if let run = await service.startRun(workflowId: workflow.id, storeId: storeId) {
                activeRunId = run.id
                showRunPanel = true
                // Start SSE streaming for live status updates
                listenToRun(run.id)
            }
        }
    }

    private func listenToRun(_ runId: String) {
        Task {
            for await event in service.streamRun(runId: runId) {
                await MainActor.run {
                    handleSSEEvent(event)
                }
            }
        }
    }

    private func handleSSEEvent(_ event: WorkflowSSEEvent) {
        switch event {
        case .snapshot(_, let steps):
            for step in steps {
                liveStatus[step.stepKey] = NodeStatus(
                    status: step.status,
                    durationMs: step.durationMs,
                    error: step.error,
                    startedAt: step.startedAt
                )
            }
        case .stepUpdate(let stepKey, let status, let durationMs, let error):
            liveStatus[stepKey] = NodeStatus(
                status: status,
                durationMs: durationMs,
                error: error,
                startedAt: nil
            )
        case .runUpdate(let status, _):
            if status == "success" || status == "failed" || status == "cancelled" {
                // Run finished — could refresh graph
            }
        default:
            break
        }
    }

    private func publishWorkflow() {
        Task {
            _ = await service.publish(workflowId: workflow.id, changelog: nil, storeId: storeId)
        }
    }

    private func addStepAtCenter(stepType: String) {
        let center = CGPoint(
            x: (-panOffset.width / zoom) + 400,
            y: (-panOffset.height / zoom) + 300
        )
        let stepKey = "\(stepType)_\(Int.random(in: 1000...9999))"

        Task {
            if let step = await service.addStep(
                workflowId: workflow.id,
                stepKey: stepKey,
                stepType: stepType,
                config: [:],
                positionX: center.x,
                positionY: center.y,
                storeId: storeId
            ) {
                await loadGraph()
                selectedNodeId = step.stepKey
            }
        }
    }

    private func deleteSelectedNode(_ nodeId: String) {
        guard let graph else { return }
        guard let node = graph.nodes.first(where: { $0.id == nodeId }) else { return }

        // Need the step_id — we only have step_key from graph
        // Use step_key as step_id fallback (server resolves both)
        Task {
            _ = await service.deleteStep(stepId: nodeId, storeId: storeId)
            selectedNodeId = nil
            await loadGraph()
        }
    }

    private func saveNodePosition(_ nodeId: String, position: CGPoint) {
        positionSaveTask?.cancel()
        positionSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            _ = await service.updateStep(
                stepId: nodeId,
                updates: ["position_x": position.x, "position_y": position.y],
                storeId: storeId
            )
        }
    }

    // MARK: - Auto Layout

    private func autoLayout() {
        guard let graph else { return }
        let positions = autoLayoutPositions(graph)
        nodePositions = positions

        // Save all positions
        Task {
            for (nodeId, pos) in positions {
                _ = await service.updateStep(
                    stepId: nodeId,
                    updates: ["position_x": pos.x, "position_y": pos.y],
                    storeId: storeId
                )
            }
        }
    }

    private func fitToView() {
        guard !nodePositions.isEmpty else { return }
        let xs = nodePositions.values.map(\.x)
        let ys = nodePositions.values.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return }

        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        withAnimation(DS.Animation.spring) {
            panOffset = CGSize(width: -centerX + 400, height: -centerY + 300)
            zoom = 1.0
        }
    }

    private func autoLayoutPositions(_ graph: WorkflowGraph) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        let spacingX: CGFloat = 250
        let spacingY: CGFloat = 150

        // Build adjacency map
        var children: [String: [String]] = [:]
        for edge in graph.edges {
            children[edge.from, default: []].append(edge.to)
        }

        // Find entry points
        let entryNodes = graph.nodes.filter(\.isEntryPoint)
        let startNodes = entryNodes.isEmpty ? Array(graph.nodes.prefix(1)) : entryNodes

        // BFS layered layout
        var visited = Set<String>()
        var layers: [[String]] = []
        var queue = startNodes.map(\.id)
        visited.formUnion(queue)

        while !queue.isEmpty {
            layers.append(queue)
            var nextQueue: [String] = []
            for nodeId in queue {
                for child in children[nodeId] ?? [] {
                    if !visited.contains(child) {
                        visited.insert(child)
                        nextQueue.append(child)
                    }
                }
            }
            queue = nextQueue
        }

        // Place unvisited nodes in last layer
        let unvisited = graph.nodes.filter { !visited.contains($0.id) }.map(\.id)
        if !unvisited.isEmpty { layers.append(unvisited) }

        // Assign positions
        let startX: CGFloat = 100
        let startY: CGFloat = 100

        for (layerIdx, layer) in layers.enumerated() {
            let totalWidth = CGFloat(layer.count - 1) * spacingX
            let offsetX = -totalWidth / 2

            for (nodeIdx, nodeId) in layer.enumerated() {
                positions[nodeId] = CGPoint(
                    x: startX + offsetX + CGFloat(nodeIdx) * spacingX + totalWidth / 2,
                    y: startY + CGFloat(layerIdx) * spacingY
                )
            }
        }

        return positions
    }
}
