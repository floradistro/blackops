import Foundation

// MARK: - Workflow Models
// Data types for the visual workflow builder (v6.0)

struct Workflow: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var icon: String?
    var status: String              // "draft", "active", "archived"
    var isActive: Bool
    var triggerType: String
    var maxConcurrentRuns: Int?
    var maxRunDurationSeconds: Int?
    var cronExpression: String?
    var nextRunAt: String?
    var lastRunAt: String?
    var runCount: Int?
    var storeId: String?
    var createdAt: String
    var updatedAt: String?
    var errorWebhookUrl: String?
    var errorEmail: String?
    var circuitBreakerThreshold: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, status
        case isActive = "is_active"
        case triggerType = "trigger_type"
        case maxConcurrentRuns = "max_concurrent_runs"
        case maxRunDurationSeconds = "max_run_duration_seconds"
        case cronExpression = "cron_expression"
        case nextRunAt = "next_run_at"
        case lastRunAt = "last_run_at"
        case runCount = "run_count"
        case storeId = "store_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case errorWebhookUrl = "error_webhook_url"
        case errorEmail = "error_email"
        case circuitBreakerThreshold = "circuit_breaker_threshold"
    }

    var displayName: String { name }

    var statusColor: String {
        switch status {
        case "active": return "success"
        case "draft": return "warning"
        case "archived": return "secondary"
        default: return "secondary"
        }
    }

    var triggerIcon: String {
        switch triggerType {
        case "manual": return "hand.point.up.fill"
        case "webhook": return "antenna.radiowaves.left.and.right"
        case "schedule", "cron": return "calendar.badge.clock"
        case "event": return "bolt.horizontal.fill"
        default: return "play.circle.fill"
        }
    }
}

// MARK: - Workflow Step

struct WorkflowStep: Codable, Identifiable, Hashable {
    let id: String
    var workflowId: String
    var stepKey: String
    var stepType: String
    var isEntryPoint: Bool
    var onSuccess: String?
    var onFailure: String?
    var stepConfig: [String: AnyCodable]?
    var timeoutSeconds: Int
    var maxRetries: Int
    var positionX: Double?
    var positionY: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case workflowId = "workflow_id"
        case stepKey = "step_key"
        case stepType = "step_type"
        case isEntryPoint = "is_entry_point"
        case onSuccess = "on_success"
        case onFailure = "on_failure"
        case stepConfig = "step_config"
        case timeoutSeconds = "timeout_seconds"
        case maxRetries = "max_retries"
        case positionX = "position_x"
        case positionY = "position_y"
    }

    static func == (lhs: WorkflowStep, rhs: WorkflowStep) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var typeIcon: String {
        WorkflowStepType.icon(for: stepType)
    }

    var configSummary: String {
        guard let config = stepConfig else { return "" }
        switch stepType {
        case "tool":
            let tool = config["tool_name"]?.stringValue ?? ""
            let action = config["action"]?.stringValue ?? ""
            return action.isEmpty ? tool : "\(tool) \u{2022} \(action)"
        case "condition":
            return config["expression"]?.stringValue ?? "if/else"
        case "delay":
            if let secs = config["seconds"]?.intValue {
                return "\(secs)s"
            }
            return "wait"
        case "code":
            return config["language"]?.stringValue ?? "js"
        case "agent":
            return config["agent_name"]?.stringValue ?? "AI agent"
        case "webhook_out":
            return config["url"]?.stringValue?.prefix(30).description ?? "webhook"
        case "approval":
            return config["title"]?.stringValue ?? "approval"
        case "sub_workflow":
            return config["workflow_name"]?.stringValue ?? "sub-workflow"
        case "for_each":
            return "iterate"
        case "parallel":
            return "parallel"
        case "transform":
            return "transform"
        case "waitpoint":
            return config["label"]?.stringValue ?? "wait"
        default:
            return stepType
        }
    }
}

// MARK: - Step Type Enum

enum WorkflowStepType {
    static let allTypes: [(key: String, label: String, icon: String, category: String)] = [
        ("tool", "Tool", "hammer.fill", "Execution"),
        ("code", "Code", "terminal.fill", "Execution"),
        ("agent", "Agent", "brain.fill", "Execution"),
        ("sub_workflow", "Sub-Workflow", "arrow.triangle.capsulepath", "Execution"),
        ("condition", "Condition", "point.3.filled.connected.trianglepath.dotted", "Flow"),
        ("parallel", "Parallel", "arrow.triangle.branch", "Flow"),
        ("for_each", "For Each", "arrow.3.trianglepath", "Flow"),
        ("delay", "Delay", "hourglass", "Flow"),
        ("noop", "No-Op", "circle.dotted", "Flow"),
        ("webhook_out", "Webhook", "paperplane.fill", "Integration"),
        ("custom", "Custom", "puzzlepiece.extension.fill", "Integration"),
        ("approval", "Approval", "checkmark.seal.fill", "Human"),
        ("waitpoint", "Waitpoint", "pause.circle.fill", "Human"),
        ("transform", "Transform", "wand.and.rays", "Data"),
    ]

    static let categories = ["Execution", "Flow", "Integration", "Human", "Data"]

    static func icon(for stepType: String) -> String {
        allTypes.first { $0.key == stepType }?.icon ?? "questionmark.circle"
    }

    static func label(for stepType: String) -> String {
        allTypes.first { $0.key == stepType }?.label ?? stepType
    }

    static func types(in category: String) -> [(key: String, label: String, icon: String, category: String)] {
        allTypes.filter { $0.category == category }
    }
}

// MARK: - Graph Models

struct WorkflowGraph: Codable {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
    let nodeStatus: [String: NodeStatus]?
    /// The workflow's owning store_id (from get response, used for step operations)
    var ownerStoreId: String?

    enum CodingKeys: String, CodingKey {
        case nodes, edges
        case nodeStatus = "node_status"
        case ownerStoreId = "owner_store_id"
    }
}

struct GraphNode: Codable, Identifiable, Hashable {
    static func == (lhs: GraphNode, rhs: GraphNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: String          // step_key (used for display + graph identity)
    let stepId: String?     // database UUID (used for update_step/delete_step)
    let type: String
    let label: String
    let isEntryPoint: Bool
    let position: GraphPosition?
    let configSummary: GraphConfigSummary?

    // Full step data for editing
    let onSuccess: String?
    let onFailure: String?
    let stepConfig: [String: AnyCodable]?
    let maxRetries: Int?
    let timeoutSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case id, type, label
        case stepId = "step_id"
        case isEntryPoint = "is_entry_point"
        case position
        case configSummary = "config_summary"
        case onSuccess = "on_success"
        case onFailure = "on_failure"
        case stepConfig = "step_config"
        case maxRetries = "max_retries"
        case timeoutSeconds = "timeout_seconds"
    }

    /// Friendly display name derived from step type + config
    var displayName: String {
        // If label was explicitly set (not auto-generated), use it
        let looksAutoGenerated = label.range(of: #"^[a-z_]+_\d{1,}$"#, options: .regularExpression) != nil
        if !looksAutoGenerated && label != id {
            return label
        }

        switch type {
        case "tool":
            let tool = configSummary?.toolName ?? stepConfig?["tool_name"]?.stringValue
            let action = configSummary?.action ?? stepConfig?["action"]?.stringValue
            if let tool, !tool.isEmpty {
                let name = tool.replacingOccurrences(of: "_", with: " ").capitalized
                if let action, !action.isEmpty { return "\(name) \u{2022} \(action)" }
                return name
            }
            return "Tool Step"
        case "condition":
            return "Condition"
        case "code":
            let lang = stepConfig?["language"]?.stringValue ?? "js"
            return "Code (\(lang))"
        case "agent":
            if let name = stepConfig?["agent_name"]?.stringValue, !name.isEmpty {
                return name.replacingOccurrences(of: "_", with: " ").capitalized
            }
            return "Agent"
        case "delay":
            if let secs = stepConfig?["seconds"]?.intValue { return "Delay \(secs)s" }
            return "Delay"
        case "webhook_out": return "Webhook"
        case "approval":
            if let title = stepConfig?["title"]?.stringValue, !title.isEmpty { return title }
            return "Approval"
        case "parallel": return "Parallel"
        case "for_each": return "For Each"
        case "sub_workflow": return "Sub-Workflow"
        case "transform": return "Transform"
        case "waitpoint":
            if let l = stepConfig?["label"]?.stringValue, !l.isEmpty { return l }
            return "Waitpoint"
        default:
            return WorkflowStepType.label(for: type)
        }
    }
}

struct GraphPosition: Codable {
    let x: Double
    let y: Double
}

struct GraphConfigSummary: Codable {
    let toolName: String?
    let action: String?
    let expression: String?

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case action, expression
    }
}

struct GraphEdge: Codable, Identifiable {
    var id: String { "\(from)-\(to)-\(type)" }
    let from: String
    let to: String
    let type: String
    let label: String?

    enum CodingKeys: String, CodingKey {
        case from, to, type, label
    }

    init(from: String, to: String, type: String, label: String? = nil) {
        self.from = from
        self.to = to
        self.type = type
        self.label = label
    }
}

struct NodeStatus: Codable {
    let status: String
    let durationMs: Int?
    let error: String?
    let startedAt: String?

    // Telemetry enrichment (not decoded from server — set locally)
    var activeTool: String?
    var totalTokens: Int?
    var totalCost: Double?
    var spanCount: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case durationMs = "duration_ms"
        case error
        case startedAt = "started_at"
        // Telemetry fields excluded from Codable — local only
    }
}

// MARK: - Run Models

struct WorkflowRun: Codable, Identifiable {
    let id: String
    let workflowId: String
    let status: String
    let triggerType: String?
    let triggerPayload: [String: AnyCodable]?
    let startedAt: String?
    let completedAt: String?
    let error: String?
    let traceId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case workflowId = "workflow_id"
        case status
        case triggerType = "trigger_type"
        case triggerPayload = "trigger_payload"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case error
        case traceId = "trace_id"
    }

    var statusColor: String {
        switch status {
        case "success", "completed": return "success"
        case "running", "pending": return "warning"
        case "failed", "error": return "error"
        case "cancelled": return "secondary"
        default: return "secondary"
        }
    }

    var statusIcon: String {
        switch status {
        case "success", "completed": return "checkmark.diamond.fill"
        case "running": return "rays"
        case "pending": return "circle.dotted.circle"
        case "failed", "error": return "exclamationmark.octagon.fill"
        case "cancelled": return "xmark.seal.fill"
        case "paused": return "pause.circle.fill"
        default: return "questionmark.diamond"
        }
    }
}

struct StepRun: Codable, Identifiable {
    let id: String
    let runId: String
    let stepKey: String
    let stepType: String
    let status: String
    let input: [String: AnyCodable]?
    let output: [String: AnyCodable]?
    let error: String?
    let durationMs: Int?
    let startedAt: String?
    let completedAt: String?
    let retryCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case runId = "run_id"
        case stepKey = "step_key"
        case stepType = "step_type"
        case status, input, output, error
        case durationMs = "duration_ms"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case retryCount = "retry_count"
    }
}

// MARK: - Approval & DLQ

struct ApprovalRequest: Codable, Identifiable {
    let id: String
    let runId: String
    let stepKey: String
    let title: String?
    let description: String?
    let options: [String]?
    let status: String
    let respondedBy: String?
    let responseData: [String: AnyCodable]?
    let expiresAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case runId = "run_id"
        case stepKey = "step_key"
        case title, description, options, status
        case respondedBy = "responded_by"
        case responseData = "response_data"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

struct DLQEntry: Codable, Identifiable {
    let id: String
    let runId: String
    let stepKey: String
    let error: String
    let status: String
    let retryCount: Int?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case runId = "run_id"
        case stepKey = "step_key"
        case error, status
        case retryCount = "retry_count"
        case createdAt = "created_at"
    }
}

// MARK: - Metrics

struct WorkflowMetrics: Codable {
    let totalRuns: Int?
    let successRate: Double?
    let avgDurationMs: Double?
    let p50Ms: Double?
    let p95Ms: Double?
    let p99Ms: Double?
    let dlqCount: Int?
    let topErrors: [[String: AnyCodable]]?
    let stepStats: [[String: AnyCodable]]?

    enum CodingKeys: String, CodingKey {
        case totalRuns = "total_runs"
        case successRate = "success_rate"
        case avgDurationMs = "avg_duration_ms"
        case p50Ms = "p50_ms"
        case p95Ms = "p95_ms"
        case p99Ms = "p99_ms"
        case dlqCount = "dlq_count"
        case topErrors = "top_errors"
        case stepStats = "step_stats"
    }
}

// MARK: - Versioning

struct WorkflowVersion: Codable, Identifiable {
    let id: String
    let workflowId: String
    let version: Int
    let changelog: String?
    let publishedAt: String
    let publishedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case workflowId = "workflow_id"
        case version, changelog
        case publishedAt = "published_at"
        case publishedBy = "published_by"
    }
}

// MARK: - SSE Events

enum WorkflowSSEEvent {
    case snapshot(run: WorkflowRun, steps: [StepRun])
    case stepUpdate(stepKey: String, status: String, durationMs: Int?, error: String?)
    case runUpdate(status: String, currentStepKey: String?)
    case agentToken(stepKey: String, token: String)
    case stepProgress(stepKey: String, progress: Double, message: String?)
    case event(eventType: String, data: [String: Any])
    case heartbeat

    static func parse(json: [String: Any]) -> WorkflowSSEEvent? {
        guard let type = json["type"] as? String else { return nil }
        switch type {
        case "snapshot":
            // Parse inline — we get raw dicts from SSE
            return .snapshot(run: WorkflowRun.fromDict(json["run"] as? [String: Any] ?? [:]),
                           steps: (json["steps"] as? [[String: Any]] ?? []).compactMap { StepRun.fromDict($0) })
        case "step_update":
            return .stepUpdate(
                stepKey: json["step_key"] as? String ?? "",
                status: json["status"] as? String ?? "",
                durationMs: json["duration_ms"] as? Int,
                error: json["error"] as? String
            )
        case "run_update":
            return .runUpdate(
                status: json["status"] as? String ?? "",
                currentStepKey: json["current_step_key"] as? String
            )
        case "agent_token":
            return .agentToken(
                stepKey: json["step_key"] as? String ?? "",
                token: json["token"] as? String ?? ""
            )
        case "step_progress":
            return .stepProgress(
                stepKey: json["step_key"] as? String ?? "",
                progress: json["progress"] as? Double ?? 0,
                message: json["message"] as? String
            )
        case "event":
            return .event(
                eventType: json["event_type"] as? String ?? "",
                data: json
            )
        default:
            return nil
        }
    }
}

// MARK: - Dict Parsing Helpers (for SSE raw JSON)

extension WorkflowRun {
    static func fromDict(_ d: [String: Any]) -> WorkflowRun {
        WorkflowRun(
            id: d["id"] as? String ?? "",
            workflowId: d["workflow_id"] as? String ?? "",
            status: d["status"] as? String ?? "unknown",
            triggerType: d["trigger_type"] as? String,
            triggerPayload: nil,
            startedAt: d["started_at"] as? String,
            completedAt: d["completed_at"] as? String,
            error: d["error"] as? String,
            traceId: d["trace_id"] as? String
        )
    }
}

extension StepRun {
    static func fromDict(_ d: [String: Any]) -> StepRun? {
        guard let id = d["id"] as? String else { return nil }
        var inputMap: [String: AnyCodable]?
        if let input = d["input"] as? [String: Any] {
            inputMap = input.mapValues { AnyCodable($0) }
        }
        var outputMap: [String: AnyCodable]?
        if let output = d["output"] as? [String: Any] {
            outputMap = output.mapValues { AnyCodable($0) }
        }
        return StepRun(
            id: id,
            runId: d["run_id"] as? String ?? "",
            stepKey: d["step_key"] as? String ?? "",
            stepType: d["step_type"] as? String ?? "",
            status: d["status"] as? String ?? "",
            input: inputMap,
            output: outputMap,
            error: d["error"] as? String,
            durationMs: d["duration_ms"] as? Int,
            startedAt: d["started_at"] as? String,
            completedAt: d["completed_at"] as? String,
            retryCount: d["retry_count"] as? Int
        )
    }
}

// MARK: - Webhook Endpoint

struct WebhookEndpoint: Codable, Identifiable {
    let id: String
    let workflowId: String
    let name: String
    let slug: String
    let url: String?
    let isActive: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case workflowId = "workflow_id"
        case name, slug, url
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

// MARK: - Checkpoint

struct WorkflowCheckpoint: Codable, Identifiable {
    let id: String
    let runId: String
    let stepKey: String
    let state: [String: AnyCodable]?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case runId = "run_id"
        case stepKey = "step_key"
        case state
        case createdAt = "created_at"
    }
}

// MARK: - Workflow Event

struct WorkflowEvent: Codable, Identifiable {
    let id: String
    let runId: String
    let eventType: String
    let stepKey: String?
    let data: [String: AnyCodable]?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case runId = "run_id"
        case eventType = "event_type"
        case stepKey = "step_key"
        case data
        case createdAt = "created_at"
    }
}

// MARK: - Waitpoint

struct WorkflowWaitpoint: Codable, Identifiable {
    let id: String
    let runId: String
    let stepKey: String
    let label: String?
    let status: String
    let data: [String: AnyCodable]?
    let expiresAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case runId = "run_id"
        case stepKey = "step_key"
        case label, status, data
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}
