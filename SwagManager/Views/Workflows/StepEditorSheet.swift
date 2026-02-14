import SwiftUI

// MARK: - Step Editor Sheet
// Polished step configuration form — fields change based on step_type
// Design System tokens, section cards, action pill picker, duration presets

struct StepEditorSheet: View {
    let node: GraphNode
    let workflowId: String
    let storeId: UUID?
    let existingStepKeys: Set<String>
    let onSaved: () -> Void
    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.workflowService) private var service
    @Environment(\.editorStore) private var store

    private func close() {
        if let onDismiss { onDismiss() } else { dismiss() }
    }

    // Common fields
    @State private var stepKey: String
    @State private var stepType: String
    @State private var isEntryPoint: Bool
    @State private var onSuccess: String = ""
    @State private var onFailure: String = ""
    @State private var maxRetries: Int = 0
    @State private var timeoutSeconds: Int = 30

    // Tool step
    @State private var toolName: String = ""
    @State private var toolAction: String = ""
    @State private var toolArgs: String = "{}"

    // Condition step
    @State private var conditionExpression: String = ""
    @State private var conditionOnTrue: String = ""
    @State private var conditionOnFalse: String = ""

    // Delay step
    @State private var delaySeconds: Int = 10

    // Code step
    @State private var codeLanguage: String = "javascript"
    @State private var codeContent: String = ""
    @State private var showCodeVariables: Bool = false

    // Agent step
    @State private var agentName: String = ""
    @State private var agentPrompt: String = ""
    @State private var agentMaxTurns: Int = 5
    @State private var agentModel: String = "claude-sonnet-4-5-20250929"
    @State private var agentTemperature: Double = 0.7

    // Webhook step
    @State private var webhookUrl: String = ""
    @State private var webhookMethod: String = "POST"
    @State private var webhookBody: String = "{}"
    @State private var webhookHeaders: String = "{}"
    @State private var webhookHeadersError: String?

    // Approval step
    @State private var approvalTitle: String = ""
    @State private var approvalDescription: String = ""
    @State private var approvalTimeout: Int = 3600
    @State private var approvalApprovers: String = ""
    @State private var approvalNotifyChannel: String = ""

    // Waitpoint step
    @State private var waitpointLabel: String = ""
    @State private var waitpointTimeout: Int = 86400

    // Parallel step
    @State private var parallelSteps: String = ""
    @State private var selectedParallelKeys: Set<String> = []
    @State private var parallelFailureStrategy: String = "fail_fast"
    @State private var parallelMaxConcurrency: Int = 0

    // For Each step
    @State private var forEachItems: String = ""
    @State private var forEachStepKey: String = ""
    @State private var forEachMaxConcurrency: Int = 0

    // Sub-workflow step
    @State private var subWorkflowId: String = ""

    // Transform step
    @State private var transformMapping: String = "{}"

    // Custom step
    @State private var customUrl: String = ""
    @State private var customPayload: String = "{}"

    // Webhook presets
    @State private var selectedPreset: String?

    // JSON validation errors
    @State private var toolArgsError: String?
    @State private var webhookBodyError: String?
    @State private var transformMappingError: String?
    @State private var customPayloadError: String?

    @State private var isSaving = false
    @State private var hasChanges = false

    // MARK: - Known Tools

    private static let knownTools: [(name: String, icon: String)] = [
        ("inventory", "archivebox.fill"),
        ("products", "cube.fill"),
        ("customers", "person.2.fill"),
        ("orders", "bag.fill"),
        ("analytics", "chart.xyaxis.line"),
        ("email", "paperplane.circle.fill"),
        ("documents", "doc.text.fill"),
        ("supply_chain", "shippingbox.and.arrow.backward.fill"),
        ("audit_trail", "clock.badge.checkmark.fill"),
        ("store", "building.2.fill"),
        ("collections", "square.stack.3d.up.fill"),
        ("workflows", "point.3.filled.connected.trianglepath.dotted"),
        ("web_search", "globe.americas.fill"),
        ("telemetry", "chart.line.flattrend.xyaxis"),
    ]

    // MARK: - Tool Actions Dictionary

    private static let toolActions: [String: [(action: String, label: String, icon: String)]] = [
        "inventory": [
            ("adjust", "Adjust Quantity", "plusminus.circle.fill"),
            ("set", "Set Stock Level", "number.circle.fill"),
            ("transfer", "Quick Transfer", "arrow.left.arrow.right.circle.fill"),
            ("summary", "Stock Summary", "list.bullet.clipboard.fill"),
            ("velocity", "Sales Velocity", "chart.line.uptrend.xyaxis"),
            ("by_location", "By Location", "mappin.circle.fill"),
            ("in_stock", "In Stock Items", "checkmark.circle.fill"),
        ],
        "products": [
            ("find", "Search Products", "magnifyingglass.circle.fill"),
            ("get", "Get Product", "cube"),
            ("create", "Create Product", "plus.rectangle.fill"),
            ("update", "Update Product", "pencil.circle.fill"),
            ("delete", "Delete Product", "trash.fill"),
            ("list_categories", "List Categories", "rectangle.stack.fill"),
        ],
        "customers": [
            ("find", "Search Customers", "magnifyingglass.circle.fill"),
            ("get", "Get Customer", "person.fill"),
            ("create", "Create Customer", "person.badge.plus"),
            ("update", "Update Customer", "pencil.circle.fill"),
            ("add_note", "Add Note", "text.bubble.fill"),
        ],
        "orders": [
            ("find", "Search Orders", "magnifyingglass.circle.fill"),
            ("get", "Get Order", "bag"),
        ],
        "analytics": [
            ("summary", "Sales Summary", "chart.bar.fill"),
            ("by_category", "By Category", "rectangle.stack.fill"),
            ("product_sales", "Product Sales", "cube"),
            ("detailed", "Detailed Report", "list.bullet.clipboard.fill"),
            ("by_location", "By Location", "mappin.circle.fill"),
        ],
        "email": [
            ("send", "Send Email", "paperplane.fill"),
            ("send_template", "Send Template", "doc.badge.gearshape.fill"),
            ("inbox", "List Inbox", "tray.full.fill"),
            ("inbox_get", "Get Thread", "envelope.open.fill"),
            ("inbox_reply", "Reply to Thread", "arrowshape.turn.up.left.fill"),
        ],
        "supply_chain": [
            ("po_create", "Create PO", "plus.rectangle.fill"),
            ("po_list", "List POs", "list.bullet.clipboard.fill"),
            ("po_get", "Get PO", "doc.text.fill"),
            ("po_approve", "Approve PO", "checkmark.seal.fill"),
            ("po_receive", "Receive PO", "shippingbox.fill"),
            ("transfer_create", "Create Transfer", "arrow.left.arrow.right.circle.fill"),
            ("transfer_list", "List Transfers", "list.bullet.clipboard.fill"),
        ],
        "documents": [
            ("create", "Create Document", "plus.rectangle.fill"),
            ("find", "Search Documents", "magnifyingglass.circle.fill"),
            ("list_templates", "List Templates", "doc.on.doc.fill"),
        ],
        "workflows": [
            ("list", "List Workflows", "list.bullet.clipboard.fill"),
            ("get", "Get Workflow", "doc.text.fill"),
            ("start", "Start Workflow", "play.fill"),
        ],
        "audit_trail": [
            ("list", "Activity Log", "list.bullet.clipboard.fill"),
            ("search", "Search Logs", "magnifyingglass.circle.fill"),
        ],
        "store": [
            ("get", "Get Store Info", "building.2"),
        ],
        "collections": [
            ("find", "Search Collections", "magnifyingglass.circle.fill"),
            ("create", "Create Collection", "plus.rectangle.fill"),
            ("get_theme", "Get Theme", "paintpalette"),
            ("set_theme", "Set Theme", "paintpalette.fill"),
        ],
        "telemetry": [
            ("conversations", "Conversations", "bubble.left.and.bubble.right.fill"),
            ("agent_performance", "Agent Performance", "chart.bar.fill"),
            ("tool_analytics", "Tool Analytics", "hammer.fill"),
            ("token_usage", "Token Usage", "dollarsign.circle.fill"),
        ],
    ]

    // MARK: - Step Type Category Color

    private var stepTypeColor: Color {
        let category = WorkflowStepType.allTypes.first { $0.key == stepType }?.category ?? ""
        switch category {
        case "Execution": return DS.Colors.blue
        case "Flow": return DS.Colors.purple
        case "Integration": return DS.Colors.orange
        case "Human": return DS.Colors.green
        case "Data": return DS.Colors.cyan
        default: return DS.Colors.accent
        }
    }

    // MARK: - JSON Validation

    private var hasJSONErrors: Bool {
        switch stepType {
        case "tool": return toolArgsError != nil
        case "webhook_out": return webhookBodyError != nil || webhookHeadersError != nil
        case "transform": return transformMappingError != nil
        case "custom": return customPayloadError != nil
        default: return false
        }
    }

    private func validateJSON(_ text: String) -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let data = text.data(using: .utf8) else { return "Invalid encoding" }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func prettyPrintJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: pretty, encoding: .utf8) else { return text }
        return result
    }

    // MARK: - Sorted Step Keys

    private var sortedStepKeys: [String] {
        existingStepKeys.sorted()
    }

    // MARK: - Init

    init(node: GraphNode, workflowId: String, storeId: UUID?, existingStepKeys: Set<String>, onSaved: @escaping () -> Void, onDismiss: (() -> Void)? = nil) {
        self.node = node
        self.workflowId = workflowId
        self.storeId = storeId
        self.existingStepKeys = existingStepKeys
        self.onSaved = onSaved
        self.onDismiss = onDismiss
        self._stepKey = State(initialValue: node.id)
        self._stepType = State(initialValue: node.type)
        self._isEntryPoint = State(initialValue: node.isEntryPoint)

        // Common fields from full step data
        self._onSuccess = State(initialValue: node.onSuccess ?? "")
        self._onFailure = State(initialValue: node.onFailure ?? "")
        self._maxRetries = State(initialValue: node.maxRetries ?? 0)
        self._timeoutSeconds = State(initialValue: node.timeoutSeconds ?? 30)

        // Populate type-specific fields from step_config
        let cfg = node.stepConfig ?? [:]
        func str(_ key: String) -> String { (cfg[key]?.value as? String) ?? "" }
        func integer(_ key: String, fallback: Int) -> Int { (cfg[key]?.value as? Int) ?? fallback }
        func jsonString(_ key: String) -> String {
            guard let val = cfg[key]?.value else { return "{}" }
            if let dict = val as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: data, encoding: .utf8) { return s }
            return "{}"
        }

        switch node.type {
        case "tool":
            self._toolName = State(initialValue: str("tool_name"))
            // action may be at top level (legacy) or inside args_template
            let actionVal = str("action").isEmpty
                ? ((node.stepConfig?["args_template"]?.value as? [String: Any])?["action"] as? String ?? "")
                : str("action")
            self._toolAction = State(initialValue: actionVal)
            self._toolArgs = State(initialValue: jsonString("args_template"))
        case "condition":
            self._conditionExpression = State(initialValue: str("expression"))
            self._conditionOnTrue = State(initialValue: str("on_true"))
            self._conditionOnFalse = State(initialValue: str("on_false"))
        case "delay":
            self._delaySeconds = State(initialValue: integer("seconds", fallback: 10))
        case "code":
            self._codeLanguage = State(initialValue: str("language").isEmpty ? "javascript" : str("language"))
            self._codeContent = State(initialValue: str("code"))
        case "agent":
            self._agentName = State(initialValue: str("agent_name"))
            self._agentPrompt = State(initialValue: str("prompt_template"))
            self._agentMaxTurns = State(initialValue: integer("max_turns", fallback: 5))
            self._agentModel = State(initialValue: str("model").isEmpty ? "claude-sonnet-4-5-20250929" : str("model"))
            self._agentTemperature = State(initialValue: (cfg["temperature"]?.value as? Double) ?? 0.7)
        case "webhook_out":
            self._webhookUrl = State(initialValue: str("url"))
            self._webhookMethod = State(initialValue: str("method").isEmpty ? "POST" : str("method"))
            self._webhookBody = State(initialValue: jsonString("body_template"))
            self._webhookHeaders = State(initialValue: jsonString("headers"))
        case "approval":
            self._approvalTitle = State(initialValue: str("title"))
            self._approvalDescription = State(initialValue: str("description"))
            self._approvalTimeout = State(initialValue: integer("timeout_seconds", fallback: 3600))
            self._approvalApprovers = State(initialValue: str("approvers"))
            self._approvalNotifyChannel = State(initialValue: str("notify_channel"))
        case "waitpoint":
            self._waitpointLabel = State(initialValue: str("label"))
            self._waitpointTimeout = State(initialValue: integer("timeout_seconds", fallback: 86400))
        case "parallel":
            if let arr = cfg["step_keys"]?.value as? [String] {
                self._parallelSteps = State(initialValue: arr.joined(separator: ", "))
                self._selectedParallelKeys = State(initialValue: Set(arr))
            }
            self._parallelFailureStrategy = State(initialValue: str("failure_strategy").isEmpty ? "fail_fast" : str("failure_strategy"))
            self._parallelMaxConcurrency = State(initialValue: integer("max_concurrency", fallback: 0))
        case "for_each":
            self._forEachItems = State(initialValue: str("items_expression"))
            self._forEachStepKey = State(initialValue: str("step_key"))
            self._forEachMaxConcurrency = State(initialValue: integer("max_concurrency", fallback: 0))
        case "sub_workflow":
            self._subWorkflowId = State(initialValue: str("workflow_id"))
        case "transform":
            self._transformMapping = State(initialValue: jsonString("mapping"))
        case "custom":
            self._customUrl = State(initialValue: str("url"))
            self._customPayload = State(initialValue: jsonString("payload"))
        default:
            break
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    identitySection
                    typeSpecificSection
                    flowSection
                    retrySection
                }
                .padding(DS.Spacing.lg)
            }

            Divider().opacity(0.3)

            footer
        }
        .frame(minWidth: 320, idealWidth: 420, maxWidth: .infinity)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            // Colored icon circle
            ZStack {
                Circle()
                    .fill(stepTypeColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: WorkflowStepType.icon(for: stepType))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(stepTypeColor)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(WorkflowStepType.label(for: stepType))
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("Configuration")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                Text(stepKey)
                    .font(DS.Typography.monoCaption)
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            Spacer()

            Button { close() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Identity Section

    private var identitySection: some View {
        sectionCard("IDENTITY", icon: "person.text.rectangle.fill") {
            fieldRow("Step Key") {
                TextField("e.g. check_inventory", text: $stepKey)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: stepKey) { _, _ in hasChanges = true }
            }

            HStack {
                Toggle("Entry Point", isOn: $isEntryPoint)
                    .font(DS.Typography.footnote)
                    .onChange(of: isEntryPoint) { _, _ in hasChanges = true }

                Spacer()

                if isEntryPoint {
                    Label("First step in workflow", systemImage: "arrow.right.circle.fill")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.success)
                }
            }
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
            sectionCard("NO-OP", icon: "circle.dotted") {
                Text("This step performs no action and simply passes through to the next step.")
                    .font(DS.Typography.caption1)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .italic()
            }
        }
    }

    // MARK: - Tool Step

    private var toolSection: some View {
        sectionCard("TOOL CONFIGURATION", icon: "hammer.fill") {
            Text("Execute a platform tool with a specific action and arguments.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

            fieldRow("Tool Name") {
                Picker("", selection: $toolName) {
                    Text("Select tool...").tag("")
                    ForEach(Self.knownTools, id: \.name) { tool in
                        Label(tool.name, systemImage: tool.icon)
                            .tag(tool.name)
                    }
                }
                .labelsHidden()
                .font(DS.Typography.monoBody)
                .onChange(of: toolName) { _, _ in
                    hasChanges = true
                    toolAction = ""
                }
            }

            // Action pill picker
            if !toolName.isEmpty, let actions = Self.toolActions[toolName] {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("ACTION")
                        .font(DS.Typography.monoHeader)
                        .foregroundStyle(DS.Colors.textTertiary)

                    FlowLayout(spacing: DS.Spacing.xs) {
                        ForEach(actions, id: \.action) { actionInfo in
                            Button {
                                toolAction = actionInfo.action
                                hasChanges = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: actionInfo.icon)
                                        .font(.system(size: 10))
                                    Text(actionInfo.label)
                                        .font(DS.Typography.caption2)
                                }
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(
                                    toolAction == actionInfo.action
                                        ? DS.Colors.accent.opacity(0.2)
                                        : DS.Colors.surfaceElevated,
                                    in: Capsule()
                                )
                                .foregroundStyle(
                                    toolAction == actionInfo.action
                                        ? DS.Colors.accent
                                        : DS.Colors.textSecondary
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(toolAction == actionInfo.action ? DS.Colors.accent.opacity(0.3) : DS.Colors.border, lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else if !toolName.isEmpty {
                // Fallback for tools not in the dictionary (e.g. web_search)
                fieldRow("Action") {
                    TextField("action", text: $toolAction)
                        .textFieldStyle(.plain)
                        .font(DS.Typography.monoBody)
                        .onChange(of: toolAction) { _, _ in hasChanges = true }
                }
            }

            jsonEditorField(
                label: "Arguments (JSON)",
                text: $toolArgs,
                error: $toolArgsError,
                minHeight: 80
            )
        }
    }

    // MARK: - Condition Step

    private var conditionSection: some View {
        sectionCard("CONDITION", icon: "point.3.filled.connected.trianglepath.dotted") {
            Text("Evaluate an expression and branch the workflow based on the result.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

            fieldRow("Expression") {
                TextField("steps.check.output.count > 0", text: $conditionExpression)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: conditionExpression) { _, _ in hasChanges = true }
            }

            fieldRow("On True \u{2192} Step") {
                stepKeyPicker(selection: $conditionOnTrue, label: "True branch target")
            }

            fieldRow("On False \u{2192} Step") {
                stepKeyPicker(selection: $conditionOnFalse, label: "False branch target")
            }

            // Inline help
            DisclosureGroup {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    expressionHelp("steps.<key>.output.<field>", desc: "Access output from a previous step")
                    expressionHelp("workflow.input.<field>", desc: "Access workflow trigger input")
                    expressionHelp("> < >= <= == !=", desc: "Comparison operators")
                    expressionHelp("&& || !", desc: "Logical operators")
                    expressionHelp("contains, startsWith", desc: "String functions")
                }
                .padding(.top, DS.Spacing.xs)
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 11))
                    Text("Expression Reference")
                        .font(DS.Typography.caption2)
                }
                .foregroundStyle(DS.Colors.textTertiary)
            }
        }
    }

    // MARK: - Delay Step

    private var delaySection: some View {
        sectionCard("DELAY", icon: "hourglass") {
            Text("Pause execution for a specified duration before continuing to the next step.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

            // Quick presets
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Quick Select")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textSecondary)

                HStack(spacing: DS.Spacing.xs) {
                    ForEach([(30, "30s"), (60, "1m"), (300, "5m"), (900, "15m"), (3600, "1h"), (21600, "6h"), (86400, "24h")], id: \.0) { (secs, label) in
                        Button {
                            delaySeconds = secs
                            hasChanges = true
                        } label: {
                            Text(label)
                                .font(DS.Typography.monoSmall)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(
                                    delaySeconds == secs ? DS.Colors.purple.opacity(0.2) : DS.Colors.surfaceElevated,
                                    in: RoundedRectangle(cornerRadius: DS.Radius.xs)
                                )
                                .foregroundStyle(delaySeconds == secs ? DS.Colors.purple : DS.Colors.textSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.xs)
                                        .stroke(delaySeconds == secs ? DS.Colors.purple.opacity(0.3) : DS.Colors.border, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Custom input
            fieldRow("Duration") {
                HStack {
                    Stepper("\(delaySeconds)s", value: $delaySeconds, in: 1...86400)
                        .font(DS.Typography.monoBody)
                        .onChange(of: delaySeconds) { _, _ in hasChanges = true }

                    Spacer()

                    Text(formatDuration(delaySeconds))
                        .font(DS.Typography.caption1)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }
        }
    }

    // MARK: - Code Step

    private var codeSection: some View {
        sectionCard("CODE", icon: "terminal.fill") {
            Text("Execute custom code to transform data, compute values, or implement custom logic.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

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

            // Available variables reference
            DisclosureGroup(isExpanded: $showCodeVariables) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    codeVarHelp("steps.<key>.output", desc: "Output from a completed step")
                    codeVarHelp("steps.<key>.status", desc: "Status of a step (success, failed)")
                    codeVarHelp("workflow.input", desc: "Trigger payload / workflow input")
                    codeVarHelp("workflow.id", desc: "Current workflow ID")
                    codeVarHelp("workflow.run_id", desc: "Current run ID")
                    codeVarHelp("context.store_id", desc: "Store UUID")
                    codeVarHelp("context.timestamp", desc: "Current ISO timestamp")
                }
                .padding(.top, DS.Spacing.xs)
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 11))
                    Text("Available Variables")
                        .font(DS.Typography.caption2)
                }
                .foregroundStyle(DS.Colors.textTertiary)
            }
        }
    }

    // MARK: - Agent Step

    private var agentSection: some View {
        sectionCard("AGENT", icon: "brain.fill") {
            Text("Invoke an AI agent to perform autonomous reasoning with tool access.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                fieldRow("Agent") {
                    if store.aiAgents.isEmpty {
                        TextField("e.g. support_agent", text: $agentName)
                            .textFieldStyle(.plain)
                            .font(DS.Typography.monoBody)
                            .onChange(of: agentName) { _, _ in hasChanges = true }
                    } else {
                        Picker("", selection: $agentName) {
                            Text("Select agent...").tag("")
                            ForEach(store.aiAgents, id: \.id) { agent in
                                Text(agent.name ?? "Unnamed")
                                    .tag(agent.name ?? "")
                            }
                        }
                        .labelsHidden()
                        .font(DS.Typography.monoBody)
                        .onChange(of: agentName) { _, _ in hasChanges = true }
                    }
                }
                if let agent = store.aiAgents.first(where: { ($0.name ?? "").lowercased() == agentName.lowercased() }) {
                    Text("ID: \(agent.id.uuidString.lowercased().prefix(8))...")
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(.leading, DS.Spacing.xxs)
                }
            }

            // Model picker
            fieldRow("Model") {
                Picker("", selection: $agentModel) {
                    Text("Sonnet 4.5").tag("claude-sonnet-4-5-20250929")
                    Text("Haiku 4.5").tag("claude-haiku-4-5-20251001")
                    Text("Opus 4.6").tag("claude-opus-4-6")
                }
                .labelsHidden()
                .font(DS.Typography.monoBody)
                .onChange(of: agentModel) { _, _ in hasChanges = true }
            }

            // Temperature slider
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    Text("Temperature")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    Text(String(format: "%.2f", agentTemperature))
                        .font(DS.Typography.monoCaption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                HStack(spacing: DS.Spacing.sm) {
                    Text("Precise")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.textQuaternary)
                    Slider(value: $agentTemperature, in: 0...1, step: 0.05)
                        .onChange(of: agentTemperature) { _, _ in hasChanges = true }
                    Text("Creative")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.textQuaternary)
                }
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
        sectionCard("WEBHOOK", icon: "paperplane.fill") {
            Text("Send an HTTP request to an external service or API endpoint.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

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
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.xs)
                                    .stroke(selectedPreset == preset ? DS.Colors.accent.opacity(0.3) : DS.Colors.border, lineWidth: 0.5)
                            )
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
                    Text("GET").tag("GET")
                    Text("POST").tag("POST")
                    Text("PUT").tag("PUT")
                    Text("PATCH").tag("PATCH")
                    Text("DELETE").tag("DELETE")
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                .onChange(of: webhookMethod) { _, _ in hasChanges = true }
            }

            // Headers
            jsonEditorField(
                label: "Headers (JSON)",
                text: $webhookHeaders,
                error: $webhookHeadersError,
                minHeight: 50
            )

            // Body
            if webhookMethod != "GET" && webhookMethod != "DELETE" {
                jsonEditorField(
                    label: "Body (JSON)",
                    text: $webhookBody,
                    error: $webhookBodyError,
                    minHeight: 80
                )
            }
        }
    }

    // MARK: - Approval Step

    private var approvalSection: some View {
        sectionCard("APPROVAL", icon: "checkmark.seal.fill") {
            Text("Pause the workflow and wait for a human to approve or reject before continuing.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

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

            fieldRow("Approvers") {
                TextField("admin@store.com, manager@store.com", text: $approvalApprovers)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoCaption)
                    .onChange(of: approvalApprovers) { _, _ in hasChanges = true }
            }
            Text("Comma-separated email addresses of authorized approvers")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.textQuaternary)

            fieldRow("Notification Channel") {
                Picker("", selection: $approvalNotifyChannel) {
                    Text("None").tag("")
                    Text("Email").tag("email")
                    Text("Slack").tag("slack")
                }
                .labelsHidden()
                .font(DS.Typography.monoBody)
                .onChange(of: approvalNotifyChannel) { _, _ in hasChanges = true }
            }

            fieldRow("Timeout") {
                HStack {
                    Stepper("\(approvalTimeout)s", value: $approvalTimeout, in: 60...604800, step: 300)
                        .font(DS.Typography.monoBody)
                        .onChange(of: approvalTimeout) { _, _ in hasChanges = true }

                    Spacer()

                    Text(formatDuration(approvalTimeout))
                        .font(DS.Typography.caption1)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }
        }
    }

    // MARK: - Waitpoint Step

    private var waitpointSection: some View {
        sectionCard("WAITPOINT", icon: "pause.circle.fill") {
            Text("Pause execution and wait for an external signal or user input before resuming.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

            fieldRow("Label") {
                TextField("Upload document", text: $waitpointLabel)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: waitpointLabel) { _, _ in hasChanges = true }
            }

            fieldRow("Timeout") {
                HStack {
                    Stepper("\(waitpointTimeout)s", value: $waitpointTimeout, in: 60...604800, step: 3600)
                        .font(DS.Typography.monoBody)
                        .onChange(of: waitpointTimeout) { _, _ in hasChanges = true }

                    Spacer()

                    Text(formatDuration(waitpointTimeout))
                        .font(DS.Typography.caption1)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }
        }
    }

    // MARK: - Parallel Step

    private var parallelSection: some View {
        sectionCard("PARALLEL EXECUTION", icon: "arrow.triangle.branch") {
            Text("Execute multiple steps simultaneously. All selected steps run at the same time.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Select steps to run in parallel")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textSecondary)

                if sortedStepKeys.isEmpty {
                    Text("No other steps defined yet.")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(DS.Spacing.sm)
                } else {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        ForEach(sortedStepKeys.filter { $0 != stepKey }, id: \.self) { key in
                            Toggle(isOn: Binding(
                                get: { selectedParallelKeys.contains(key) },
                                set: { isOn in
                                    if isOn {
                                        selectedParallelKeys.insert(key)
                                    } else {
                                        selectedParallelKeys.remove(key)
                                    }
                                    parallelSteps = selectedParallelKeys.sorted().joined(separator: ", ")
                                    hasChanges = true
                                }
                            )) {
                                Text(key)
                                    .font(DS.Typography.monoBody)
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(DS.Spacing.sm)
                    .glassBackground(cornerRadius: DS.Radius.sm)
                }
            }

            if !selectedParallelKeys.isEmpty {
                Text("\(selectedParallelKeys.count) step(s) will execute simultaneously.")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            // Failure strategy
            fieldRow("Failure Strategy") {
                Picker("", selection: $parallelFailureStrategy) {
                    Text("Fail Fast").tag("fail_fast")
                    Text("Continue All").tag("continue_all")
                    Text("Threshold").tag("threshold")
                }
                .labelsHidden()
                .font(DS.Typography.monoBody)
                .onChange(of: parallelFailureStrategy) { _, _ in hasChanges = true }
            }
            strategyDescription

            // Max concurrency
            fieldRow("Max Concurrency") {
                HStack {
                    Stepper(parallelMaxConcurrency == 0 ? "Unlimited" : "\(parallelMaxConcurrency)", value: $parallelMaxConcurrency, in: 0...50)
                        .font(DS.Typography.monoBody)
                        .onChange(of: parallelMaxConcurrency) { _, _ in hasChanges = true }
                }
            }
        }
    }

    @ViewBuilder
    private var strategyDescription: some View {
        let desc: String = {
            switch parallelFailureStrategy {
            case "fail_fast": return "Stop all branches immediately if any branch fails."
            case "continue_all": return "Let all branches finish even if some fail."
            case "threshold": return "Continue until a failure threshold is reached."
            default: return ""
            }
        }()
        Text(desc)
            .font(DS.Typography.caption2)
            .foregroundStyle(DS.Colors.textQuaternary)
    }

    // MARK: - For Each Step

    private var forEachSection: some View {
        sectionCard("FOR EACH", icon: "arrow.3.trianglepath") {
            Text("Iterate over a list and execute a step for each item in the collection.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

            fieldRow("Items Expression") {
                TextField("steps.fetch.output.items", text: $forEachItems)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoBody)
                    .onChange(of: forEachItems) { _, _ in hasChanges = true }
            }

            fieldRow("Execute Step") {
                stepKeyPicker(selection: $forEachStepKey, label: "Step to execute per item")
            }

            fieldRow("Max Concurrency") {
                HStack {
                    Stepper(forEachMaxConcurrency == 0 ? "Sequential" : "\(forEachMaxConcurrency)", value: $forEachMaxConcurrency, in: 0...50)
                        .font(DS.Typography.monoBody)
                        .onChange(of: forEachMaxConcurrency) { _, _ in hasChanges = true }

                    Spacer()

                    if forEachMaxConcurrency == 0 {
                        Text("Items processed one at a time")
                            .font(DS.Typography.caption2)
                            .foregroundStyle(DS.Colors.textQuaternary)
                    }
                }
            }
        }
    }

    // MARK: - Sub-Workflow Step

    private var subWorkflowSection: some View {
        sectionCard("SUB-WORKFLOW", icon: "arrow.triangle.capsulepath") {
            Text("Trigger another workflow as a child execution, passing data between parent and child.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

            fieldRow("Workflow") {
                if service.workflows.isEmpty {
                    TextField("workflow-uuid", text: $subWorkflowId)
                        .textFieldStyle(.plain)
                        .font(DS.Typography.monoBody)
                        .onChange(of: subWorkflowId) { _, _ in hasChanges = true }
                } else {
                    Picker("", selection: $subWorkflowId) {
                        Text("Select workflow...").tag("")
                        ForEach(service.workflows.filter { $0.id != workflowId }) { wf in
                            Text(wf.name)
                                .tag(wf.id)
                        }
                    }
                    .labelsHidden()
                    .font(DS.Typography.monoBody)
                    .onChange(of: subWorkflowId) { _, _ in hasChanges = true }
                }
            }
        }
    }

    // MARK: - Transform Step

    private var transformSection: some View {
        sectionCard("TRANSFORM", icon: "wand.and.rays") {
            Text("Reshape, filter, or map data between steps using a JSON mapping definition.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

            jsonEditorField(
                label: "Mapping (JSON)",
                text: $transformMapping,
                error: $transformMappingError,
                minHeight: 100
            )

            DisclosureGroup {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    codeVarHelp("\"output_key\": \"steps.<key>.output.<field>\"", desc: "Map a step output to a new key")
                    codeVarHelp("\"items\": \"steps.fetch.output.results\"", desc: "Extract nested array")
                    codeVarHelp("\"total\": \"steps.calc.output.sum\"", desc: "Rename output fields")
                }
                .padding(.top, DS.Spacing.xs)
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 11))
                    Text("Mapping Examples")
                        .font(DS.Typography.caption2)
                }
                .foregroundStyle(DS.Colors.textTertiary)
            }
        }
    }

    // MARK: - Custom Step

    private var customSection: some View {
        sectionCard("CUSTOM INTEGRATION", icon: "puzzlepiece.extension.fill") {
            Text("Call a custom external endpoint with a payload. Use for integrations not covered by built-in tools.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

            fieldRow("URL") {
                TextField("https://api.example.com/webhook", text: $customUrl)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.monoCaption)
                    .onChange(of: customUrl) { _, _ in hasChanges = true }
            }

            jsonEditorField(
                label: "Payload (JSON)",
                text: $customPayload,
                error: $customPayloadError,
                minHeight: 80
            )
        }
    }

    // MARK: - Flow Section

    private var flowSection: some View {
        sectionCard("FLOW", icon: "point.3.filled.connected.trianglepath.dotted") {
            Text("Define which step executes next after this step completes or fails.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

            if stepType != "condition" {
                fieldRow("On Success \u{2192} Step") {
                    stepKeyPicker(selection: $onSuccess, label: "Next step on success")
                }

                fieldRow("On Failure \u{2192} Step") {
                    stepKeyPicker(selection: $onFailure, label: "Next step on failure")
                }
            } else {
                Text("Condition steps use On True / On False branches defined above.")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textQuaternary)
            }
        }
    }

    // MARK: - Retry Section

    private var retrySection: some View {
        sectionCard("RETRY & TIMEOUT", icon: "arrow.counterclockwise.circle.fill") {
            Text("Configure automatic retry behavior and execution time limits.")
                .font(DS.Typography.caption1)
                .foregroundStyle(DS.Colors.textTertiary)
                .italic()

            fieldRow("Max Retries") {
                HStack {
                    Stepper("\(maxRetries)", value: $maxRetries, in: 0...10)
                        .font(DS.Typography.monoBody)
                        .onChange(of: maxRetries) { _, _ in hasChanges = true }

                    Spacer()

                    if maxRetries == 0 {
                        Text("No retries")
                            .font(DS.Typography.caption2)
                            .foregroundStyle(DS.Colors.textQuaternary)
                    }
                }
            }

            fieldRow("Timeout") {
                HStack {
                    Stepper("\(timeoutSeconds)s", value: $timeoutSeconds, in: 5...3600, step: 5)
                        .font(DS.Typography.monoBody)
                        .onChange(of: timeoutSeconds) { _, _ in hasChanges = true }

                    Spacer()

                    Text(formatDuration(timeoutSeconds))
                        .font(DS.Typography.caption1)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if hasJSONErrors {
                Label("Fix JSON errors before saving", systemImage: "exclamationmark.triangle.fill")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.warning)
                    .lineLimit(1)
            } else if let error = service.error {
                Text(error)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.error)
                    .lineLimit(1)
            }

            Spacer()

            Button("Cancel") { close() }
                .keyboardShortcut(.escape, modifiers: [])

            Button("Save") { saveStep() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!hasChanges || isSaving || stepKey.isEmpty || hasJSONErrors)
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
            // action must be inside args_template for the server executor
            var argsDict: [String: Any] = (parseJSON(toolArgs) as? [String: Any]) ?? [:]
            if !toolAction.isEmpty { argsDict["action"] = toolAction }
            config["args_template"] = argsDict
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
            // Resolve agent_id from name so the server can execute it
            if let agent = store.aiAgents.first(where: { ($0.name ?? "").lowercased() == agentName.lowercased() }) {
                config["agent_id"] = agent.id.uuidString.lowercased()
            }
            config["prompt_template"] = agentPrompt
            config["max_turns"] = agentMaxTurns
            config["model"] = agentModel
            config["temperature"] = agentTemperature
        case "webhook_out":
            config["url"] = webhookUrl
            config["method"] = webhookMethod
            if let body = parseJSON(webhookBody) { config["body_template"] = body }
            if let headers = parseJSON(webhookHeaders) { config["headers"] = headers }
        case "approval":
            config["title"] = approvalTitle
            config["description"] = approvalDescription
            config["timeout_seconds"] = approvalTimeout
            if !approvalApprovers.isEmpty { config["approvers"] = approvalApprovers }
            if !approvalNotifyChannel.isEmpty { config["notify_channel"] = approvalNotifyChannel }
        case "waitpoint":
            config["label"] = waitpointLabel
            config["timeout_seconds"] = waitpointTimeout
        case "parallel":
            config["step_keys"] = parallelSteps.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            config["failure_strategy"] = parallelFailureStrategy
            if parallelMaxConcurrency > 0 { config["max_concurrency"] = parallelMaxConcurrency }
        case "for_each":
            config["items_expression"] = forEachItems
            config["step_key"] = forEachStepKey
            if forEachMaxConcurrency > 0 { config["max_concurrency"] = forEachMaxConcurrency }
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
            let dbId = node.stepId ?? node.id
            let success = await service.updateStep(stepId: dbId, updates: updates, storeId: storeId)
            isSaving = false
            if success {
                onSaved()
                close()
            }
        }
    }

    // MARK: - Helpers

    /// Section card wrapper with title, icon, and bordered container
    private func sectionCard<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.Colors.textTertiary)
                Text(title)
                    .font(DS.Typography.monoHeader)
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                content()
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surfaceTertiary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.border, lineWidth: 0.5)
            )
        }
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

    /// Reusable step key picker
    private func stepKeyPicker(selection: Binding<String>, label: String) -> some View {
        Picker("", selection: Binding(
            get: { selection.wrappedValue },
            set: { newValue in
                selection.wrappedValue = newValue
                hasChanges = true
            }
        )) {
            Text("(none)").tag("")
            ForEach(sortedStepKeys.filter { $0 != stepKey }, id: \.self) { key in
                Text(key)
                    .font(DS.Typography.monoBody)
                    .tag(key)
            }
        }
        .labelsHidden()
        .font(DS.Typography.monoBody)
    }

    /// Reusable JSON editor field with validation, error display, and Format button
    private func jsonEditorField(
        label: String,
        text: Binding<String>,
        error: Binding<String?>,
        minHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(label)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textSecondary)

                Spacer()

                Button {
                    text.wrappedValue = prettyPrintJSON(text.wrappedValue)
                } label: {
                    Label("Format", systemImage: "text.alignleft")
                        .font(DS.Typography.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.accent)
                .disabled(error.wrappedValue != nil)
            }

            TextEditor(text: text)
                .font(DS.Typography.monoCaption)
                .frame(minHeight: minHeight)
                .scrollContentBackground(.hidden)
                .padding(DS.Spacing.xs)
                .glassBackground(cornerRadius: DS.Radius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(error.wrappedValue != nil ? DS.Colors.error : .clear, lineWidth: 1)
                )
                .onChange(of: text.wrappedValue) { _, newValue in
                    hasChanges = true
                    error.wrappedValue = validateJSON(newValue)
                }

            if let errorMsg = error.wrappedValue {
                Text(errorMsg)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.error)
                    .lineLimit(2)
            }
        }
    }

    /// Expression reference help row
    private func expressionHelp(_ expr: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text(expr)
                .font(DS.Typography.monoCaption)
                .foregroundStyle(DS.Colors.accent)
                .frame(minWidth: 180, alignment: .leading)
            Text(desc)
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.textQuaternary)
        }
    }

    /// Code variable help row
    private func codeVarHelp(_ variable: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text(variable)
                .font(DS.Typography.monoCaption)
                .foregroundStyle(DS.Colors.cyan)
                .frame(minWidth: 200, alignment: .leading)
            Text(desc)
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.textQuaternary)
        }
    }

    /// Format seconds into human-readable duration
    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 {
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h >= 24 {
            let d = h / 24
            let remainH = h % 24
            return remainH > 0 ? "\(d)d \(remainH)h" : "\(d)d"
        }
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private func applyWebhookPreset(_ preset: String) {
        selectedPreset = preset
        hasChanges = true
        switch preset {
        case "Slack":
            webhookUrl = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
            webhookMethod = "POST"
            webhookHeaders = """
            {
              "Content-Type": "application/json"
            }
            """
            webhookHeadersError = nil
            webhookBody = """
            {
              "text": "{{steps.previous.output.message}}",
              "channel": "#alerts"
            }
            """
            webhookBodyError = nil
        case "Discord":
            webhookUrl = "https://discord.com/api/webhooks/YOUR/DISCORD/WEBHOOK"
            webhookMethod = "POST"
            webhookHeaders = """
            {
              "Content-Type": "application/json"
            }
            """
            webhookHeadersError = nil
            webhookBody = """
            {
              "content": "{{steps.previous.output.message}}"
            }
            """
            webhookBodyError = nil
        case "Zapier":
            webhookUrl = "https://hooks.zapier.com/hooks/catch/YOUR/HOOK"
            webhookMethod = "POST"
            webhookHeaders = """
            {
              "Content-Type": "application/json"
            }
            """
            webhookHeadersError = nil
            webhookBody = """
            {
              "data": "{{steps.previous.output}}"
            }
            """
            webhookBodyError = nil
        default:
            break
        }
    }
}

