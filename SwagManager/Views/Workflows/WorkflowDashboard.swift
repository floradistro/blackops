import SwiftUI

// MARK: - Workflow Dashboard
// HSplitView: workflow list (left) + canvas (center) + run panel (right)
// Matches TelemetryPanel's proven 3-column pattern

struct WorkflowDashboard: View {
    let storeId: UUID?

    @Environment(\.workflowService) private var service

    @State private var selectedWorkflowId: String?
    @State private var searchText = ""
    @State private var statusFilter: String?
    @State private var showNewWorkflow = false
    @State private var showTemplates = false
    @State private var activeRunId: String?
    @State private var showRunPanel = false

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
                    activeRunId: $activeRunId,
                    showRunPanel: $showRunPanel
                )
                .frame(minWidth: 320, idealWidth: 600)
            } else {
                emptyCanvas
                    .frame(minWidth: 320, idealWidth: 600)
            }

            // Right: Run panel (optional)
            if showRunPanel, let runId = activeRunId {
                WorkflowRunPanel(
                    runId: runId,
                    workflowId: selectedWorkflowId,
                    storeId: storeId,
                    onDismiss: { showRunPanel = false }
                )
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 500)
            }
        }
        .focusable()
        .onKeyPress(.escape) {
            if showRunPanel {
                withAnimation(.easeOut(duration: 0.2)) {
                    showRunPanel = false
                }
                return .handled
            }
            return .ignored
        }
        .task {
            await service.listWorkflows(storeId: storeId)
        }
        .sheet(isPresented: $showNewWorkflow) {
            NewWorkflowSheet(storeId: storeId) { workflow in
                selectedWorkflowId = workflow.id
            }
        }
        .sheet(isPresented: $showTemplates) {
            TemplatePickerSheet(storeId: storeId) { workflow in
                selectedWorkflowId = workflow.id
            }
        }
    }

    // MARK: - Workflow List

    private var workflowList: some View {
        VStack(spacing: 0) {
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
                    Label("No Workflows", systemImage: "arrow.triangle.branch")
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
            Label("Select a Workflow", systemImage: "arrow.triangle.branch")
        } description: {
            Text("Choose a workflow from the list or create a new one.")
        } actions: {
            Button("New Workflow") { showNewWorkflow = true }
            Button("Browse Templates") { showTemplates = true }
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
        ("manual", "Hand Tap", "hand.tap"),
        ("webhook", "Webhook", "arrow.down.forward.square"),
        ("schedule", "Schedule", "clock"),
        ("event", "Event", "bolt"),
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
                ContentUnavailableView("No Templates", systemImage: "doc.on.doc")
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
