import SwiftUI

// MARK: - Workflow Dashboard
// HSplitView: workflow list (left) + canvas (center) + run panel (right)
// Matches TelemetryPanel's proven 3-column pattern

enum RightPanelType: Equatable {
    case run(String)
    case runHistory
    case versions
    case webhooks
    case dlq
    case metrics
    case dependencies
    case stepEditor(String)   // step key
    case stepTest(String)     // step key
    case stepHistory(String)  // step key
    case settings
}

struct WorkflowDashboard: View {
    let storeId: UUID?

    @Environment(\.workflowService) private var service

    @State private var selectedWorkflowId: String?
    @State private var searchText = ""
    @State private var statusFilter: String?
    @State private var showNewWorkflow = false
    @State private var showTemplates = false
    @State private var rightPanel: RightPanelType?
    @State private var allGraphs: [String: WorkflowGraph] = [:]
    @State private var isLoadingGraphs = false
    @State private var canvasGraph: WorkflowGraph?
    @State private var runTelemetry = WorkflowTelemetryService()

    private var filteredWorkflows: [Workflow] {
        var list = service.workflows
        if let filter = statusFilter {
            list = list.filter { $0.status == filter }
        }
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return list
    }

    private var selectedWorkflow: Workflow? {
        guard let id = selectedWorkflowId else { return nil }
        return service.workflows.first { $0.id == id }
    }

    var body: some View {
        HSplitView {
            // Left: Workflow list
            workflowList
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 360)

            // Center: Canvas
            if let workflow = selectedWorkflow {
                WorkflowCanvas(
                    workflow: workflow,
                    storeId: storeId,
                    rightPanel: $rightPanel,
                    canvasGraph: $canvasGraph,
                    runTelemetry: runTelemetry
                )
                .frame(minWidth: 320, idealWidth: 600)
            } else {
                emptyCanvas
                    .frame(minWidth: 320, idealWidth: 600)
            }

            // Right: Context panel (optional)
            if let panel = rightPanel {
                rightPanelView(panel, workflowId: selectedWorkflowId)
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 500)
            }
        }
        .focusable()
        .onKeyPress(.escape) {
            if rightPanel != nil {
                withAnimation(.easeOut(duration: 0.2)) {
                    rightPanel = nil
                }
                return .handled
            }
            return .ignored
        }
        .task(id: storeId) {
            guard storeId != nil else { return }
            await service.listWorkflows(storeId: storeId)
        }
        .sheet(isPresented: $showNewWorkflow) {
            NewWorkflowSheet(storeId: storeId) { workflow in
                selectedWorkflowId = workflow.id
            }
        }
        .sheet(isPresented: $showTemplates) {
            WorkflowTemplateGallery(
                storeId: storeId,
                onClone: { workflow in
                    selectedWorkflowId = workflow.id
                    showTemplates = false
                },
                onDismiss: { showTemplates = false }
            )
        }
    }

    // MARK: - Workflow List

    private var workflowList: some View {
        VStack(spacing: 0) {
            // Clear the view switcher overlay in title bar area
            Color.clear.frame(height: 28)

            // Header
            HStack {
                Text("WORKFLOWS")
                    .font(DS.Typography.monoHeader)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .textCase(.uppercase)

                Spacer()

                Menu {
                    Button("New Workflow") { showNewWorkflow = true }
                    Button("From Template...") { showTemplates = true }
                } label: {
                    Image(systemName: "plus")
                        .font(DesignSystem.font(12, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)

            // Search
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(DesignSystem.font(11))
                    .foregroundStyle(DS.Colors.textQuaternary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.caption1)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .glassBackground(cornerRadius: DS.Radius.sm)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.sm)

            // Status filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    filterPill("All", filter: nil)
                    filterPill("Active", filter: "active")
                    filterPill("Draft", filter: "draft")
                    filterPill("Archived", filter: "archived")
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
            .padding(.bottom, DS.Spacing.sm)

            Divider().opacity(0.3)

            // List
            if service.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
                Spacer()
            } else if filteredWorkflows.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("No Workflows", systemImage: "point.3.filled.connected.trianglepath.dotted")
                } description: {
                    Text("Create a workflow or clone a template.")
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.xxs) {
                        ForEach(filteredWorkflows) { workflow in
                            workflowRow(workflow)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
        }
        .background(DS.Colors.surfaceTertiary)
    }

    private func filterPill(_ label: String, filter: String?) -> some View {
        Button {
            withAnimation(DS.Animation.fast) { statusFilter = filter }
        } label: {
            Text(label)
                .font(DS.Typography.monoLabel)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs)
                .background(
                    statusFilter == filter ? DS.Colors.accent.opacity(0.2) : DS.Colors.surfaceElevated,
                    in: RoundedRectangle(cornerRadius: DS.Radius.pill)
                )
                .foregroundStyle(statusFilter == filter ? DS.Colors.accent : DS.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func workflowRow(_ workflow: Workflow) -> some View {
        let isSelected = selectedWorkflowId == workflow.id

        Button {
            withAnimation(DS.Animation.fast) {
                selectedWorkflowId = workflow.id
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                // Icon
                Image(systemName: workflow.icon ?? workflow.triggerIcon)
                    .font(DesignSystem.font(14))
                    .foregroundStyle(statusColor(workflow.statusColor))
                    .frame(width: 24)

                // Info
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(workflow.name)
                        .font(DS.Typography.sidebarItem)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.xs) {
                        // Status badge
                        Text(workflow.status.uppercased())
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(statusColor(workflow.statusColor))

                        // Trigger type
                        Image(systemName: workflow.triggerIcon)
                            .font(DesignSystem.font(8))
                            .foregroundStyle(DS.Colors.textQuaternary)

                        Spacer()

                        // Run count
                        if let count = workflow.runCount, count > 0 {
                            Text("\(count) runs")
                                .font(DS.Typography.monoSmall)
                                .foregroundStyle(DS.Colors.textQuaternary)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isSelected ? DS.Colors.selectionActive : Color.clear,
                in: RoundedRectangle(cornerRadius: DS.Radius.md)
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Duplicate") {
                Task {
                    if let wf = await service.cloneTemplate(templateId: workflow.id, name: "\(workflow.name) Copy", storeId: storeId) {
                        selectedWorkflowId = wf.id
                    }
                }
            }

            Button(workflow.isActive ? "Deactivate" : "Activate") {
                Task {
                    _ = await service.updateWorkflow(id: workflow.id, updates: ["is_active": !workflow.isActive], storeId: storeId)
                }
            }

            Divider()

            Button("Delete", role: .destructive) {
                Task {
                    _ = await service.deleteWorkflow(id: workflow.id, storeId: storeId)
                }
            }
        }
    }

    // MARK: - Empty Canvas

    private var emptyCanvas: some View {
        ContentUnavailableView {
            Label("Select a Workflow", systemImage: "point.3.filled.connected.trianglepath.dotted")
        } description: {
            Text("Choose a workflow from the list or create a new one.")
        } actions: {
            Button("New Workflow") { showNewWorkflow = true }
            Button("Browse Templates") { showTemplates = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Right Panel

    @ViewBuilder
    private func rightPanelView(_ panel: RightPanelType, workflowId: String?) -> some View {
        switch panel {
        case .run(let runId):
            WorkflowRunPanel(
                runId: runId,
                workflowId: workflowId,
                storeId: storeId,
                onDismiss: { rightPanel = nil },
                telemetry: runTelemetry
            )

        case .runHistory:
            if let wid = workflowId {
                WorkflowRunHistoryPanel(
                    workflowId: wid,
                    storeId: storeId,
                    onSelectRun: { runId in
                        withAnimation(DS.Animation.fast) {
                            rightPanel = .run(runId)
                        }
                    },
                    onDismiss: { rightPanel = nil }
                )
            }

        case .versions:
            if let wid = workflowId {
                WorkflowVersionPanel(
                    workflowId: wid,
                    storeId: storeId,
                    onDismiss: { rightPanel = nil }
                )
            }

        case .webhooks:
            if let wid = workflowId {
                WorkflowWebhookPanel(
                    workflowId: wid,
                    storeId: storeId,
                    onDismiss: { rightPanel = nil }
                )
            }

        case .dlq:
            WorkflowDLQPanel(
                storeId: storeId,
                onDismiss: { rightPanel = nil }
            )

        case .metrics:
            WorkflowMetricsPanel(
                storeId: storeId,
                onDismiss: { rightPanel = nil }
            )

        case .stepEditor(let stepKey):
            if let wid = workflowId,
               let node = canvasGraph?.nodes.first(where: { $0.id == stepKey }) {
                StepEditorSheet(
                    node: node,
                    workflowId: wid,
                    storeId: storeId,
                    existingStepKeys: Set(canvasGraph?.nodes.map(\.id) ?? []),
                    onSaved: { canvasGraph = nil },
                    onDismiss: { rightPanel = nil }
                )
            }

        case .stepTest(let stepKey):
            if let wid = workflowId,
               let node = canvasGraph?.nodes.first(where: { $0.id == stepKey }) {
                StepTestPanel(
                    node: node,
                    workflowId: wid,
                    storeId: storeId,
                    onDismiss: { rightPanel = nil }
                )
            }

        case .stepHistory(let stepKey):
            if let wid = workflowId {
                StepExecutionHistory(
                    stepKey: stepKey,
                    workflowId: wid,
                    storeId: storeId,
                    onDismiss: { rightPanel = nil }
                )
            }

        case .settings:
            if let workflow = selectedWorkflow {
                WorkflowSettingsSheet(
                    workflow: workflow,
                    storeId: storeId,
                    onSaved: { canvasGraph = nil },
                    onDismiss: { rightPanel = nil }
                )
            }

        case .dependencies:
            VStack(spacing: 0) {
                if isLoadingGraphs {
                    Spacer()
                    VStack(spacing: DS.Spacing.sm) {
                        ProgressView().scaleEffect(0.7)
                        Text("Loading dependency data...")
                            .font(DS.Typography.caption1)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    Spacer()
                } else {
                    WorkflowDependencyMap(
                        workflows: service.workflows,
                        graphs: allGraphs,
                        onSelectWorkflow: { wfId in
                            selectedWorkflowId = wfId
                            rightPanel = nil
                        }
                    )
                }
            }
            .task {
                guard allGraphs.isEmpty else { return }
                isLoadingGraphs = true
                for workflow in service.workflows {
                    if let graph = await service.getGraph(workflowId: workflow.id, storeId: storeId) {
                        allGraphs[workflow.id] = graph
                    }
                }
                isLoadingGraphs = false
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(_ key: String) -> Color {
        switch key {
        case "success": return DS.Colors.success
        case "warning": return DS.Colors.warning
        case "error": return DS.Colors.error
        default: return DS.Colors.textTertiary
        }
    }
}

// MARK: - New Workflow Sheet

struct NewWorkflowSheet: View {
    let storeId: UUID?
    let onCreated: (Workflow) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.workflowService) private var service

    @State private var name = ""
    @State private var description = ""
    @State private var triggerType = "manual"
    @State private var isCreating = false

    private let triggerTypes = [
        ("manual", "Hand Tap", "hand.point.up.fill"),
        ("webhook", "Webhook", "antenna.radiowaves.left.and.right"),
        ("schedule", "Schedule", "calendar.badge.clock"),
        ("event", "Event", "bolt.horizontal.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Workflow")
                    .font(DS.Typography.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Spacing.lg)

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Name
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("NAME")
                            .font(DS.Typography.monoHeader)
                            .foregroundStyle(DS.Colors.textTertiary)
                        TextField("My Workflow", text: $name)
                            .textFieldStyle(.plain)
                            .font(DS.Typography.body)
                            .padding(DS.Spacing.sm)
                            .glassBackground(cornerRadius: DS.Radius.md)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("DESCRIPTION")
                            .font(DS.Typography.monoHeader)
                            .foregroundStyle(DS.Colors.textTertiary)
                        TextField("Optional description...", text: $description)
                            .textFieldStyle(.plain)
                            .font(DS.Typography.footnote)
                            .padding(DS.Spacing.sm)
                            .glassBackground(cornerRadius: DS.Radius.md)
                    }

                    // Trigger type
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("TRIGGER TYPE")
                            .font(DS.Typography.monoHeader)
                            .foregroundStyle(DS.Colors.textTertiary)

                        HStack(spacing: DS.Spacing.sm) {
                            ForEach(triggerTypes, id: \.0) { type in
                                Button {
                                    triggerType = type.0
                                } label: {
                                    VStack(spacing: DS.Spacing.xs) {
                                        Image(systemName: type.2)
                                            .font(DesignSystem.font(18))
                                        Text(type.1)
                                            .font(DS.Typography.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DS.Spacing.md)
                                    .background(
                                        triggerType == type.0 ? DS.Colors.accent.opacity(0.15) : DS.Colors.surfaceElevated,
                                        in: RoundedRectangle(cornerRadius: DS.Radius.md)
                                    )
                                    .overlay {
                                        if triggerType == type.0 {
                                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                                .strokeBorder(DS.Colors.accent.opacity(0.5), lineWidth: 1)
                                        }
                                    }
                                    .foregroundStyle(triggerType == type.0 ? DS.Colors.accent : DS.Colors.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(DS.Spacing.lg)
            }

            Divider().opacity(0.3)

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Create") {
                    isCreating = true
                    Task {
                        if let wf = await service.createWorkflow(
                            name: name,
                            description: description.isEmpty ? nil : description,
                            triggerType: triggerType,
                            storeId: storeId
                        ) {
                            onCreated(wf)
                            dismiss()
                        }
                        isCreating = false
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(name.isEmpty || isCreating)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(width: 480, height: 420)
    }
}

// MARK: - Template Picker Sheet

struct TemplatePickerSheet: View {
    let storeId: UUID?
    let onCloned: (Workflow) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.workflowService) private var service

    @State private var templates: [Workflow] = []
    @State private var isLoading = true
    @State private var cloningId: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Workflow Templates")
                    .font(DS.Typography.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Spacing.lg)

            Divider().opacity(0.3)

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if templates.isEmpty {
                ContentUnavailableView("No Templates", systemImage: "doc.on.doc.fill")
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(templates) { template in
                            templateRow(template)
                        }
                    }
                    .padding(DS.Spacing.lg)
                }
            }
        }
        .frame(width: 560, height: 500)
        .task {
            templates = await service.listTemplates(storeId: storeId)
            isLoading = false
        }
    }

    private func templateRow(_ template: Workflow) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: template.icon ?? template.triggerIcon)
                .font(DesignSystem.font(20))
                .foregroundStyle(DS.Colors.accent)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(template.name)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textPrimary)
                if let desc = template.description {
                    Text(desc)
                        .font(DS.Typography.caption1)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                cloningId = template.id
                Task {
                    if let wf = await service.cloneTemplate(templateId: template.id, name: template.name, storeId: storeId) {
                        onCloned(wf)
                        dismiss()
                    }
                    cloningId = nil
                }
            } label: {
                if cloningId == template.id {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Text("Clone")
                        .font(DS.Typography.buttonSmall)
                }
            }
            .disabled(cloningId != nil)
        }
        .padding(DS.Spacing.md)
        .cardStyle(padding: 0, cornerRadius: DS.Radius.md)
    }
}

// MARK: - Run History Panel

struct WorkflowRunHistoryPanel: View {
    let workflowId: String
    let storeId: UUID?
    let onSelectRun: (String) -> Void
    let onDismiss: () -> Void

    @Environment(\.workflowService) private var service

    @State private var runs: [WorkflowRun] = []
    @State private var isLoading = true
    @State private var statusFilter: String?

    private var filteredRuns: [WorkflowRun] {
        guard let filter = statusFilter else { return runs }
        switch filter {
        case "running":
            return runs.filter { $0.status == "running" || $0.status == "pending" }
        case "success":
            return runs.filter { $0.status == "success" || $0.status == "completed" }
        case "failed":
            return runs.filter { $0.status == "failed" || $0.status == "error" }
        default:
            return runs
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            filterBar
            Divider().opacity(0.3)
            content
        }
        .background(DS.Colors.surfaceTertiary)
        .task {
            await loadRuns()
        }
    }

    // MARK: - Header (compact inline)

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("\(runs.count) runs")
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textQuaternary)

            Spacer()

            Button {
                Task { await loadRuns() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(DesignSystem.font(10, weight: .medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
            }
            .buttonStyle(.plain)

            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(DesignSystem.font(9, weight: .medium))
                    .foregroundStyle(DS.Colors.textQuaternary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                runFilterPill("All", filter: nil)
                runFilterPill("Running", filter: "running")
                runFilterPill("Success", filter: "success")
                runFilterPill("Failed", filter: "failed")
            }
            .padding(.horizontal, DS.Spacing.md)
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private func runFilterPill(_ label: String, filter: String?) -> some View {
        Button {
            withAnimation(DS.Animation.fast) { statusFilter = filter }
        } label: {
            Text(label)
                .font(DS.Typography.monoLabel)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs)
                .background(
                    statusFilter == filter ? DS.Colors.accent.opacity(0.2) : DS.Colors.surfaceElevated,
                    in: RoundedRectangle(cornerRadius: DS.Radius.pill)
                )
                .foregroundStyle(statusFilter == filter ? DS.Colors.accent : DS.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            Spacer()
            ProgressView()
                .scaleEffect(0.7)
            Spacer()
        } else if filteredRuns.isEmpty {
            Spacer()
            ContentUnavailableView {
                Label("No Runs", systemImage: "text.line.last.and.arrowtriangle.forward")
            } description: {
                if statusFilter != nil {
                    Text("No runs match this filter.")
                } else {
                    Text("This workflow has not been run yet.")
                }
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.xxs) {
                    ForEach(filteredRuns) { run in
                        runRow(run)
                    }
                }
                .padding(DS.Spacing.md)
            }
        }
    }

    // MARK: - Run Row

    private func runRow(_ run: WorkflowRun) -> some View {
        Button {
            onSelectRun(run.id)
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                // Status icon
                Image(systemName: run.statusIcon)
                    .font(DesignSystem.font(14))
                    .foregroundStyle(runStatusColor(run))
                    .frame(width: 20)

                // Run info
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack {
                        Text(String(run.id.prefix(8)))
                            .font(DS.Typography.monoCaption)
                            .foregroundStyle(DS.Colors.textPrimary)

                        Spacer()

                        if let timestamp = relativeTime(run) {
                            Text(timestamp)
                                .font(DS.Typography.monoSmall)
                                .foregroundStyle(DS.Colors.textQuaternary)
                        }
                    }

                    HStack(spacing: DS.Spacing.sm) {
                        // Status
                        Text(run.status.uppercased())
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(runStatusColor(run))

                        // Trigger type
                        if let trigger = run.triggerType {
                            HStack(spacing: DS.Spacing.xxs) {
                                Image(systemName: triggerIcon(trigger))
                                    .font(DesignSystem.font(8))
                                Text(trigger)
                                    .font(DS.Typography.monoSmall)
                            }
                            .foregroundStyle(DS.Colors.textQuaternary)
                        }

                        Spacer()

                        // Duration
                        if let duration = runDuration(run) {
                            Text(duration)
                                .font(DS.Typography.monoSmall)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                }
            }
            .padding(DS.Spacing.sm)
            .background(
                Color.clear,
                in: RoundedRectangle(cornerRadius: DS.Radius.md)
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Helpers

    private func loadRuns() async {
        isLoading = true
        runs = await service.getRuns(workflowId: workflowId, storeId: storeId)
        isLoading = false
    }

    private func runStatusColor(_ run: WorkflowRun) -> Color {
        switch run.status {
        case "success", "completed": return DS.Colors.success
        case "running", "pending": return DS.Colors.warning
        case "failed", "error": return DS.Colors.error
        case "cancelled": return DS.Colors.textTertiary
        case "paused": return DS.Colors.warning
        default: return DS.Colors.textQuaternary
        }
    }

    private func triggerIcon(_ trigger: String) -> String {
        switch trigger {
        case "manual": return "hand.point.up.fill"
        case "webhook": return "antenna.radiowaves.left.and.right"
        case "schedule", "cron": return "calendar.badge.clock"
        case "event": return "bolt.horizontal.fill"
        default: return "play.circle.fill"
        }
    }

    private func relativeTime(_ run: WorkflowRun) -> String? {
        guard let dateStr = run.startedAt ?? run.completedAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr) else {
            return String(dateStr.prefix(16))
        }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        return String(dateStr.prefix(10))
    }

    private func runDuration(_ run: WorkflowRun) -> String? {
        guard let startStr = run.startedAt, let endStr = run.completedAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        guard let start = formatter.date(from: startStr) ?? fallback.date(from: startStr),
              let end = formatter.date(from: endStr) ?? fallback.date(from: endStr) else { return nil }
        let seconds = end.timeIntervalSince(start)
        if seconds < 1 { return "<1s" }
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let mins = Int(seconds / 60)
        let secs = Int(seconds) % 60
        return "\(mins)m\(secs)s"
    }
}
