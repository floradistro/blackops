import SwiftUI

// MARK: - Step Editor Sheet
// Dynamic step configuration form — fields change based on step_type
// Matches UserToolEditorSheet pattern (600x700, header/scroll/footer)

struct StepEditorSheet: View {
    let node: GraphNode
    let workflowId: String
    let storeId: UUID?
    let existingStepKeys: Set<String>
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.workflowService) private var service

    // Common fields
    @State private var stepKey: String
    @State private var stepType: String
    @State private var isEntryPoint: Bool
    @State private var onSuccess: String = ""
    @State private var onFailure: String = ""
    @State private var maxRetries: Int = 0
    @State private var timeoutSeconds: Int = 30

    // Type-specific config
    @State private var toolName: String = ""
    @State private var toolAction: String = ""
    @State private var toolArgs: String = "{}"
    @State private var conditionExpression: String = ""
    @State private var conditionOnTrue: String = ""
    @State private var conditionOnFalse: String = ""
    @State private var delaySeconds: Int = 10
    @State private var codeLanguage: String = "javascript"
    @State private var codeContent: String = ""
    @State private var agentName: String = ""
    @State private var agentPrompt: String = ""
    @State private var agentMaxTurns: Int = 5
    @State private var webhookUrl: String = ""
    @State private var webhookMethod: String = "POST"
    @State private var webhookBody: String = "{}"
    @State private var approvalTitle: String = ""
    @State private var approvalDescription: String = ""
    @State private var approvalTimeout: Int = 3600
    @State private var waitpointLabel: String = ""
    @State private var waitpointTimeout: Int = 86400
    @State private var parallelSteps: String = ""
    @State private var forEachItems: String = ""
    @State private var forEachStepKey: String = ""
    @State private var subWorkflowId: String = ""
    @State private var transformMapping: String = "{}"
    @State private var customUrl: String = ""
    @State private var customPayload: String = "{}"

    // Webhook presets
    @State private var selectedPreset: String?

    @State private var isSaving = false
    @State private var hasChanges = false

    init(node: GraphNode, workflowId: String, storeId: UUID?, existingStepKeys: Set<String>, onSaved: @escaping () -> Void) {
        self.node = node
        self.workflowId = workflowId
        self.storeId = storeId
        self.existingStepKeys = existingStepKeys
        self.onSaved = onSaved
        self._stepKey = State(initialValue: node.id)
        self._stepType = State(initialValue: node.type)
        self._isEntryPoint = State(initialValue: node.isEntryPoint)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider().opacity(0.3)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    commonSection
                    typeSpecificSection
                    flowSection
                    retrySection
                }
                .padding(DS.Spacing.lg)
            }

            Divider().opacity(0.3)

            // Footer
            footer
        }
        .frame(width: 600, height: 700)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: WorkflowStepType.icon(for: stepType))
                .font(DesignSystem.font(16))
                .foregroundStyle(DS.Colors.accent)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Edit Step")
                    .font(DS.Typography.headline)
                Text(WorkflowStepType.label(for: stepType))
                    .font(DS.Typography.caption1)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Common Section

    private var commonSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("IDENTITY")

            // Step key
            fieldRow("Step Key") {
                TextField("my_step", text: $stepKey)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: stepKey) { _, _ in hasChanges = true }
            }

            // Entry point toggle
            Toggle("Entry Point", isOn: $isEntryPoint)
                .font(DS.Typography.footnote)
                .onChange(of: isEntryPoint) { _, _ in hasChanges = true }
        }
    }

    // MARK: - Type-Specific Section

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch stepType {
        case "tool":
            toolSection
        case "condition":
            conditionSection
        case "delay":
            delaySection
        case "code":
            codeSection
        case "agent":
            agentSection
        case "webhook_out":
            webhookSection
        case "approval":
            approvalSection
        case "waitpoint":
            waitpointSection
        case "parallel":
            parallelSection
        case "for_each":
            forEachSection
        case "sub_workflow":
            subWorkflowSection
        case "transform":
            transformSection
        case "custom":
            customSection
        default:
            EmptyView()
        }
    }

    // MARK: - Tool Step

    private var toolSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("TOOL CONFIGURATION")

            fieldRow("Tool Name") {
                TextField("inventory", text: $toolName)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: toolName) { _, _ in hasChanges = true }
            }

            fieldRow("Action") {
                TextField("summary", text: $toolAction)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: toolAction) { _, _ in hasChanges = true }
            }

            fieldRow("Arguments (JSON)") {
                TextEditor(text: $toolArgs)
                    .font(DS.Typography.monoCaption)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(DS.Spacing.xs)
                    .glassBackground(cornerRadius: DS.Radius.sm)
                    .onChange(of: toolArgs) { _, _ in hasChanges = true }
            }
        }
    }

    // MARK: - Condition Step

    private var conditionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("CONDITION")

            fieldRow("Expression") {
                TextField("steps.check.output.count > 0", text: $conditionExpression)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: conditionExpression) { _, _ in hasChanges = true }
            }

            fieldRow("On True → Step") {
                TextField("step_key for true branch", text: $conditionOnTrue)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: conditionOnTrue) { _, _ in hasChanges = true }
            }

            fieldRow("On False → Step") {
                TextField("step_key for false branch", text: $conditionOnFalse)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: conditionOnFalse) { _, _ in hasChanges = true }
            }
        }
    }

    // MARK: - Delay Step

    private var delaySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("DELAY")

            fieldRow("Seconds") {
                HStack {
                    Stepper("\(delaySeconds)s", value: $delaySeconds, in: 1...86400)
                        .font(DS.Typography.monoBody)
                        .onChange(of: delaySeconds) { _, _ in hasChanges = true }
                }
            }
        }
    }

    // MARK: - Code Step

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("CODE")

            fieldRow("Language") {
                Picker("", selection: $codeLanguage) {
                    Text("JavaScript").tag("javascript")
                    Text("Python").tag("python")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: codeLanguage) { _, _ in hasChanges = true }
            }

            fieldRow("Code") {
                TextEditor(text: $codeContent)
                    .font(DS.Typography.monoCaption)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(DS.Spacing.xs)
                    .glassBackground(cornerRadius: DS.Radius.sm)
                    .onChange(of: codeContent) { _, _ in hasChanges = true }
            }
        }
    }

    // MARK: - Agent Step

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("AGENT")

            fieldRow("Agent Name") {
                TextField("support_agent", text: $agentName)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: agentName) { _, _ in hasChanges = true }
            }

            fieldRow("Prompt Template") {
                TextEditor(text: $agentPrompt)
                    .font(DS.Typography.monoCaption)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(DS.Spacing.xs)
                    .glassBackground(cornerRadius: DS.Radius.sm)
                    .onChange(of: agentPrompt) { _, _ in hasChanges = true }
            }

            fieldRow("Max Turns") {
                Stepper("\(agentMaxTurns)", value: $agentMaxTurns, in: 1...50)
                    .font(DS.Typography.monoBody)
                    .onChange(of: agentMaxTurns) { _, _ in hasChanges = true }
            }
        }
    }

    // MARK: - Webhook Step

    private var webhookSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("WEBHOOK")

            // Presets
            HStack(spacing: DS.Spacing.xs) {
                Text("Preset:")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textTertiary)
                ForEach(["Slack", "Discord", "Zapier"], id: \.self) { preset in
                    Button {
                        applyWebhookPreset(preset)
                    } label: {
                        Text(preset)
                            .font(DS.Typography.monoSmall)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(
                                selectedPreset == preset ? DS.Colors.accent.opacity(0.2) : DS.Colors.surfaceElevated,
                                in: RoundedRectangle(cornerRadius: DS.Radius.xs)
                            )
                            .foregroundStyle(selectedPreset == preset ? DS.Colors.accent : DS.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            fieldRow("URL") {
                TextField("https://hooks.slack.com/...", text: $webhookUrl)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoCaption)
                    .onChange(of: webhookUrl) { _, _ in hasChanges = true }
            }

            fieldRow("Method") {
                Picker("", selection: $webhookMethod) {
                    Text("POST").tag("POST")
                    Text("PUT").tag("PUT")
                    Text("PATCH").tag("PATCH")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: webhookMethod) { _, _ in hasChanges = true }
            }

            fieldRow("Body (JSON)") {
                TextEditor(text: $webhookBody)
                    .font(DS.Typography.monoCaption)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(DS.Spacing.xs)
                    .glassBackground(cornerRadius: DS.Radius.sm)
                    .onChange(of: webhookBody) { _, _ in hasChanges = true }
            }
        }
    }

    // MARK: - Approval Step

    private var approvalSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("APPROVAL")

            fieldRow("Title") {
                TextField("Approve reorder?", text: $approvalTitle)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: approvalTitle) { _, _ in hasChanges = true }
            }

            fieldRow("Description") {
                TextEditor(text: $approvalDescription)
                    .font(DS.Typography.monoCaption)
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
                    .padding(DS.Spacing.xs)
                    .glassBackground(cornerRadius: DS.Radius.sm)
                    .onChange(of: approvalDescription) { _, _ in hasChanges = true }
            }

            fieldRow("Timeout (seconds)") {
                Stepper("\(approvalTimeout)s", value: $approvalTimeout, in: 60...604800, step: 300)
                    .font(DS.Typography.monoBody)
                    .onChange(of: approvalTimeout) { _, _ in hasChanges = true }
            }
        }
    }

    // MARK: - Waitpoint Step

    private var waitpointSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("WAITPOINT")

            fieldRow("Label") {
                TextField("Upload document", text: $waitpointLabel)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: waitpointLabel) { _, _ in hasChanges = true }
            }

            fieldRow("Timeout (seconds)") {
                Stepper("\(waitpointTimeout)s", value: $waitpointTimeout, in: 60...604800, step: 3600)
                    .font(DS.Typography.monoBody)
                    .onChange(of: waitpointTimeout) { _, _ in hasChanges = true }
            }
        }
    }

    // MARK: - Parallel Step

    private var parallelSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("PARALLEL EXECUTION")

            fieldRow("Step Keys (comma-separated)") {
                TextField("step_a, step_b, step_c", text: $parallelSteps)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: parallelSteps) { _, _ in hasChanges = true }
            }

            Text("All listed steps will execute simultaneously.")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.textTertiary)
        }
    }

    // MARK: - For Each Step

    private var forEachSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("FOR EACH")

            fieldRow("Items Expression") {
                TextField("steps.fetch.output.items", text: $forEachItems)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: forEachItems) { _, _ in hasChanges = true }
            }

            fieldRow("Execute Step") {
                TextField("process_item", text: $forEachStepKey)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: forEachStepKey) { _, _ in hasChanges = true }
            }
        }
    }

    // MARK: - Sub-Workflow Step

    private var subWorkflowSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("SUB-WORKFLOW")

            fieldRow("Workflow ID") {
                TextField("uuid-of-workflow", text: $subWorkflowId)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: subWorkflowId) { _, _ in hasChanges = true }
            }
        }
    }

    // MARK: - Transform Step

    private var transformSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("TRANSFORM")

            fieldRow("Mapping (JSON)") {
                TextEditor(text: $transformMapping)
                    .font(DS.Typography.monoCaption)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(DS.Spacing.xs)
                    .glassBackground(cornerRadius: DS.Radius.sm)
                    .onChange(of: transformMapping) { _, _ in hasChanges = true }
            }
        }
    }

    // MARK: - Custom Step

    private var customSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("CUSTOM")

            fieldRow("URL") {
                TextField("https://api.example.com/webhook", text: $customUrl)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoCaption)
                    .onChange(of: customUrl) { _, _ in hasChanges = true }
            }

            fieldRow("Payload (JSON)") {
                TextEditor(text: $customPayload)
                    .font(DS.Typography.monoCaption)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(DS.Spacing.xs)
                    .glassBackground(cornerRadius: DS.Radius.sm)
                    .onChange(of: customPayload) { _, _ in hasChanges = true }
            }
        }
    }

    // MARK: - Flow Section

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("FLOW")

            if stepType != "condition" {
                fieldRow("On Success → Step") {
                    TextField("next_step_key", text: $onSuccess)
                        .textFieldStyle(.plain)
                        .font(DS.Typography.monoBody)
                        .onChange(of: onSuccess) { _, _ in hasChanges = true }
                }

                fieldRow("On Failure → Step") {
                    TextField("error_handler_key", text: $onFailure)
                        .textFieldStyle(.plain)
                        .font(DS.Typography.monoBody)
                        .onChange(of: onFailure) { _, _ in hasChanges = true }
                }
            }
        }
    }

    // MARK: - Retry Section

    private var retrySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("RETRY & TIMEOUT")

            fieldRow("Max Retries") {
                Stepper("\(maxRetries)", value: $maxRetries, in: 0...10)
                    .font(DS.Typography.monoBody)
                    .onChange(of: maxRetries) { _, _ in hasChanges = true }
            }

            fieldRow("Timeout (seconds)") {
                Stepper("\(timeoutSeconds)s", value: $timeoutSeconds, in: 5...3600, step: 5)
                    .font(DS.Typography.monoBody)
                    .onChange(of: timeoutSeconds) { _, _ in hasChanges = true }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let error = service.error {
                Text(error)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.error)
                    .lineLimit(1)
            }

            Spacer()

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.escape, modifiers: [])

            Button("Save") { saveStep() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!hasChanges || isSaving || stepKey.isEmpty)
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Save

    private func saveStep() {
        isSaving = true

        var updates: [String: Any] = [
            "step_key": stepKey,
            "step_type": stepType,
            "is_entry_point": isEntryPoint,
            "timeout_seconds": timeoutSeconds,
            "max_retries": maxRetries,
        ]

        if !onSuccess.isEmpty { updates["on_success"] = onSuccess }
        if !onFailure.isEmpty { updates["on_failure"] = onFailure }

        // Build step_config based on type
        var config: [String: Any] = [:]
        switch stepType {
        case "tool":
            config["tool_name"] = toolName
            if !toolAction.isEmpty { config["action"] = toolAction }
            if let args = parseJSON(toolArgs) { config["args_template"] = args }
        case "condition":
            config["expression"] = conditionExpression
            if !conditionOnTrue.isEmpty { config["on_true"] = conditionOnTrue }
            if !conditionOnFalse.isEmpty { config["on_false"] = conditionOnFalse }
        case "delay":
            config["seconds"] = delaySeconds
        case "code":
            config["language"] = codeLanguage
            config["code"] = codeContent
        case "agent":
            config["agent_name"] = agentName
            config["prompt_template"] = agentPrompt
            config["max_turns"] = agentMaxTurns
        case "webhook_out":
            config["url"] = webhookUrl
            config["method"] = webhookMethod
            if let body = parseJSON(webhookBody) { config["body_template"] = body }
        case "approval":
            config["title"] = approvalTitle
            config["description"] = approvalDescription
            config["timeout_seconds"] = approvalTimeout
        case "waitpoint":
            config["label"] = waitpointLabel
            config["timeout_seconds"] = waitpointTimeout
        case "parallel":
            config["step_keys"] = parallelSteps.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        case "for_each":
            config["items_expression"] = forEachItems
            config["step_key"] = forEachStepKey
        case "sub_workflow":
            config["workflow_id"] = subWorkflowId
        case "transform":
            if let mapping = parseJSON(transformMapping) { config["mapping"] = mapping }
        case "custom":
            config["url"] = customUrl
            if let payload = parseJSON(customPayload) { config["payload"] = payload }
        default:
            break
        }

        updates["step_config"] = config

        Task {
            let success = await service.updateStep(stepId: node.id, updates: updates, storeId: storeId)
            isSaving = false
            if success {
                onSaved()
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DS.Typography.monoHeader)
            .foregroundStyle(DS.Colors.textTertiary)
    }

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.textSecondary)
            content()
                .padding(DS.Spacing.sm)
                .glassBackground(cornerRadius: DS.Radius.sm)
        }
    }

    private func parseJSON(_ string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private func applyWebhookPreset(_ preset: String) {
        selectedPreset = preset
        hasChanges = true
        switch preset {
        case "Slack":
            webhookUrl = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
            webhookMethod = "POST"
            webhookBody = """
            {
              "text": "{{steps.previous.output.message}}",
              "channel": "#alerts"
            }
            """
        case "Discord":
            webhookUrl = "https://discord.com/api/webhooks/YOUR/DISCORD/WEBHOOK"
            webhookMethod = "POST"
            webhookBody = """
            {
              "content": "{{steps.previous.output.message}}"
            }
            """
        case "Zapier":
            webhookUrl = "https://hooks.zapier.com/hooks/catch/YOUR/HOOK"
            webhookMethod = "POST"
            webhookBody = """
            {
              "data": "{{steps.previous.output}}"
            }
            """
        default:
            break
        }
    }
}
