import SwiftUI

// MARK: - Step Test Panel
// Test a single workflow step in isolation with mock input data.
// Inspired by Make.com per-module testing. Shows input editor, run button,
// output viewer, and keeps a short history of recent test results.

struct StepTestPanel: View {
    let node: GraphNode
    let workflowId: String
    let storeId: UUID?
    var onDismiss: (() -> Void)? = nil

    @Environment(\.workflowService) private var service
    @Environment(\.dismiss) private var dismiss

    private func close() {
        if let onDismiss { onDismiss() } else { dismiss() }
    }

    // Input editor
    @State private var inputJSON: String
    @State private var inputError: String?

    // Execution state
    @State private var isRunning = false
    @State private var latestResult: TestResult?
    @State private var history: [TestResult] = []

    // MARK: - Test Result Model

    private struct TestResult: Identifiable {
        let id = UUID()
        let status: String
        let durationMs: Int?
        let output: String?
        let error: String?
        let timestamp: Date
    }

    // MARK: - Init

    init(node: GraphNode, workflowId: String, storeId: UUID?, onDismiss: (() -> Void)? = nil) {
        self.node = node
        self.workflowId = workflowId
        self.storeId = storeId
        self.onDismiss = onDismiss
        self._inputJSON = State(initialValue: Self.defaultInput(for: node))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    inputSection
                    runSection
                    if let result = latestResult {
                        outputSection(result)
                    }
                    if !history.isEmpty {
                        historySection
                    }
                }
                .padding(DS.Spacing.lg)
            }
        }
        .frame(minWidth: 320, idealWidth: 420, maxWidth: .infinity)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: WorkflowStepType.icon(for: node.type))
                .font(DesignSystem.font(16))
                .foregroundStyle(DS.Colors.accent)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Test Step")
                    .font(DS.Typography.headline)
                Text("\(node.displayName) \u{2022} \(WorkflowStepType.label(for: node.type))")
                    .font(DS.Typography.caption1)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button { close() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text("MOCK INPUT")
                    .font(DS.Typography.monoHeader)
                    .foregroundStyle(DS.Colors.textTertiary)

                Spacer()

                Button {
                    inputJSON = prettyPrintJSON(inputJSON)
                } label: {
                    Label("Format", systemImage: "text.alignleft")
                        .font(DS.Typography.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.accent)
                .disabled(inputError != nil)
            }

            TextEditor(text: $inputJSON)
                .font(DS.Typography.monoCaption)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(DS.Spacing.xs)
                .glassBackground(cornerRadius: DS.Radius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(inputError != nil ? DS.Colors.error : .clear, lineWidth: 1)
                )
                .onChange(of: inputJSON) { _, newValue in
                    inputError = validateJSON(newValue)
                }

            if let errorMsg = inputError {
                Text(errorMsg)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.error)
                    .lineLimit(2)
            }

            Text("Provide the JSON payload this step would receive from the previous step in the workflow.")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.textTertiary)
        }
    }

    // MARK: - Run Section

    private var runSection: some View {
        HStack {
            Button {
                runTest()
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "play.fill")
                            .font(DesignSystem.font(12))
                    }
                    Text(isRunning ? "Running..." : "Run Test")
                        .font(DS.Typography.button)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    isRunning ? DS.Colors.warning.opacity(0.15) : DS.Colors.accent.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: DS.Radius.md)
                )
                .foregroundStyle(isRunning ? DS.Colors.warning : DS.Colors.accent)
            }
            .buttonStyle(.plain)
            .disabled(isRunning || inputError != nil)

            Spacer()

            if !history.isEmpty {
                Text("\(history.count) previous run\(history.count == 1 ? "" : "s")")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
    }

    // MARK: - Output Section

    private func outputSection(_ result: TestResult) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("RESULT")
                    .font(DS.Typography.monoHeader)
                    .foregroundStyle(DS.Colors.textTertiary)

                Spacer()

                statusBadge(result.status)

                if let ms = result.durationMs {
                    Text(formatDuration(ms))
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

            // Error message
            if let error = result.error {
                HStack(alignment: .top, spacing: DS.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DesignSystem.font(11))
                        .foregroundStyle(DS.Colors.error)
                    Text(error)
                        .font(DS.Typography.monoCaption)
                        .foregroundStyle(DS.Colors.error)
                        .textSelection(.enabled)
                }
                .padding(DS.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.error.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }

            // Output JSON viewer
            if let output = result.output {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text("OUTPUT")
                            .font(DS.Typography.monoHeader)
                            .foregroundStyle(DS.Colors.textTertiary)

                        Spacer()

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(output, forType: .string)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(DS.Typography.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DS.Colors.accent)
                        .help("Copy output to clipboard")
                    }

                    ScrollView([.horizontal, .vertical]) {
                        Text(output)
                            .font(DS.Typography.monoCaption)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .padding(DS.Spacing.sm)
                    .glassBackground(cornerRadius: DS.Radius.sm)
                }
            }
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("HISTORY")
                .font(DS.Typography.monoHeader)
                .foregroundStyle(DS.Colors.textTertiary)

            ForEach(history) { entry in
                HStack(spacing: DS.Spacing.sm) {
                    statusBadge(entry.status)

                    if let ms = entry.durationMs {
                        Text(formatDuration(ms))
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }

                    Spacer()

                    Text(formatTimestamp(entry.timestamp))
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textQuaternary)

                    Button {
                        latestResult = entry
                    } label: {
                        Image(systemName: "arrow.up.left.circle")
                            .font(DesignSystem.font(12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("View this result")
                }
                .padding(DS.Spacing.sm)
                .glassBackground(cornerRadius: DS.Radius.sm)
            }
        }
    }

    // MARK: - Run Test

    private func runTest() {
        guard let parsed = parseJSON(inputJSON) else { return }

        isRunning = true

        Task {
            let startTime = Date()
            let stepRun = await service.testStep(
                workflowId: workflowId,
                stepKey: node.id,
                mockInput: parsed,
                storeId: storeId
            )

            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)

            let result: TestResult
            if let stepRun {
                let outputString: String? = {
                    guard let output = stepRun.output else { return nil }
                    let raw = output.mapValues(\.value)
                    guard let data = try? JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted, .sortedKeys]),
                          let str = String(data: data, encoding: .utf8) else {
                        return String(describing: raw)
                    }
                    return str
                }()

                result = TestResult(
                    status: stepRun.status,
                    durationMs: stepRun.durationMs ?? elapsed,
                    output: outputString,
                    error: stepRun.error,
                    timestamp: Date()
                )
            } else {
                // Service returned nil — check service.error
                let errorMessage = service.error ?? "Step testing unavailable -- requires backend endpoint"
                result = TestResult(
                    status: "failed",
                    durationMs: elapsed,
                    output: nil,
                    error: errorMessage,
                    timestamp: Date()
                )
            }

            // Push previous latest into history (keep max 3)
            if let previous = latestResult {
                history.insert(previous, at: 0)
                if history.count > 3 {
                    history = Array(history.prefix(3))
                }
            }

            latestResult = result
            isRunning = false
        }
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: String) -> some View {
        let (color, icon) = statusAppearance(status)
        return HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(DesignSystem.font(9))
            Text(status.uppercased())
                .font(DS.Typography.monoSmall)
        }
        .foregroundStyle(color)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.xs))
    }

    private func statusAppearance(_ status: String) -> (Color, String) {
        switch status {
        case "success", "completed":
            return (DS.Colors.success, "checkmark.diamond.fill")
        case "failed", "error":
            return (DS.Colors.error, "exclamationmark.octagon.fill")
        case "running":
            return (DS.Colors.warning, "rays")
        case "pending":
            return (DS.Colors.textQuaternary, "circle.dotted.circle")
        default:
            return (DS.Colors.textTertiary, "questionmark.diamond")
        }
    }

    // MARK: - JSON Helpers

    private func validateJSON(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let data = trimmed.data(using: .utf8) else { return "Invalid encoding" }
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

    private func parseJSON(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    // MARK: - Formatting Helpers

    private func formatDuration(_ ms: Int) -> String {
        if ms < 1000 { return "\(ms)ms" }
        let seconds = Double(ms) / 1000.0
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let minutes = Int(seconds / 60)
        let secs = Int(seconds) % 60
        return "\(minutes)m\(secs)s"
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    // MARK: - Default Input Templates

    private static func defaultInput(for node: GraphNode) -> String {
        let cfg = node.stepConfig ?? [:]

        switch node.type {
        case "tool":
            let toolName = cfg["tool_name"]?.stringValue ?? "tool_name"
            let action = cfg["action"]?.stringValue ?? "action"
            return """
            {
              "tool_name": "\(toolName)",
              "action": "\(action)",
              "args": {}
            }
            """

        case "condition":
            let expression = cfg["expression"]?.stringValue ?? "steps.previous.output.count > 0"
            return """
            {
              "expression_context": {
                "steps": {
                  "previous": {
                    "output": {
                      "count": 5
                    }
                  }
                }
              },
              "expression": "\(expression)"
            }
            """

        case "code":
            let language = cfg["language"]?.stringValue ?? "javascript"
            return """
            {
              "language": "\(language)",
              "variables": {
                "input_data": "sample_value"
              }
            }
            """

        case "agent":
            let agentName = cfg["agent_name"]?.stringValue ?? "agent"
            return """
            {
              "agent_name": "\(agentName)",
              "prompt_context": "Test this step with sample data.",
              "variables": {}
            }
            """

        case "transform":
            return """
            {
              "source": {
                "field_a": "value_a",
                "field_b": 42
              }
            }
            """

        case "webhook_out":
            return """
            {
              "url": "\(cfg["url"]?.stringValue ?? "https://example.com/hook")",
              "headers": {},
              "body": {}
            }
            """

        case "delay":
            let seconds = (cfg["seconds"]?.value as? Int) ?? 10
            return """
            {
              "seconds": \(seconds)
            }
            """

        case "parallel":
            return """
            {
              "step_results": {}
            }
            """

        case "for_each":
            return """
            {
              "items": [
                { "id": 1, "name": "item_1" },
                { "id": 2, "name": "item_2" }
              ]
            }
            """

        case "sub_workflow":
            return """
            {
              "trigger_payload": {}
            }
            """

        case "approval":
            return """
            {
              "title": "\(cfg["title"]?.stringValue ?? "Approval Request")",
              "context": {}
            }
            """

        default:
            return """
            {
              "input": {}
            }
            """
        }
    }
}
