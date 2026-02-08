import Foundation

// MARK: - Telemetry Models

/// A single span in a trace (matches audit_logs structure)
struct TelemetrySpan: Identifiable, Codable {
    let id: UUID
    let parentId: UUID?
    let action: String
    let severity: String
    let durationMs: Int?
    let errorMessage: String?
    let details: [String: AnyCodable]?
    let createdAt: Date
    let requestId: String?
    let conversationId: String?
    let storeId: UUID?
    let resourceType: String?
    let userId: UUID?
    let userEmail: String?

    // Computed for tree view (not decoded)
    var depth: Int = 0
    var children: [TelemetrySpan] = []

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case action
        case severity
        case durationMs = "duration_ms"
        case errorMessage = "error_message"
        case details
        case createdAt = "created_at"
        case requestId = "request_id"
        case conversationId = "conversation_id"
        case storeId = "store_id"
        case resourceType = "resource_type"
        case userId = "user_id"
        case userEmail = "user_email"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        action = try container.decode(String.self, forKey: .action)
        severity = try container.decode(String.self, forKey: .severity)
        durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        details = try container.decodeIfPresent([String: AnyCodable].self, forKey: .details)
        requestId = try container.decodeIfPresent(String.self, forKey: .requestId)
        conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
        storeId = try container.decodeIfPresent(UUID.self, forKey: .storeId)
        resourceType = try container.decodeIfPresent(String.self, forKey: .resourceType)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        userEmail = try container.decodeIfPresent(String.self, forKey: .userEmail)
        depth = 0
        children = []

        // Parse date with timezone - Supabase returns ISO8601 with offset like "2026-02-03T23:53:30.639075-05:00"
        // The SDK's default decoder loses the timezone, so we parse manually
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                createdAt = date
            } else {
                // Fallback: try without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                createdAt = formatter.date(from: dateString) ?? Date()
            }
        } else {
            // Fallback to SDK's date decoding
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encode(action, forKey: .action)
        try container.encode(severity, forKey: .severity)
        try container.encodeIfPresent(durationMs, forKey: .durationMs)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(details, forKey: .details)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(requestId, forKey: .requestId)
        try container.encodeIfPresent(conversationId, forKey: .conversationId)
        try container.encodeIfPresent(storeId, forKey: .storeId)
        try container.encodeIfPresent(resourceType, forKey: .resourceType)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(userEmail, forKey: .userEmail)
    }

    var isError: Bool {
        severity == "error" || severity == "critical"
    }

    var toolName: String? {
        if action.hasPrefix("tool.") {
            return String(action.dropFirst(5))
        }
        return nil
    }

    var source: String {
        (details?["source"]?.value as? String) ?? "unknown"
    }

    var agentName: String? {
        // First check for explicit agent_name in details
        if let name = details?["agent_name"]?.value as? String, !name.isEmpty {
            return name
        }
        // Fall back to source as agent identifier (e.g., "claude_code" -> "Claude Code")
        let src = source
        if src != "unknown" {
            return src.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return nil
    }

    var agentId: String? {
        details?["agent_id"]?.value as? String
    }

    // MARK: - AI Telemetry Fields (gen_ai.* OTEL conventions)

    /// Is this a Claude API request span?
    var isApiRequest: Bool {
        action == "claude_api_request"
    }

    /// Model used for this API call (e.g., "claude-sonnet-4-20250514")
    var model: String? {
        details?["gen_ai.request.model"]?.value as? String
    }

    /// Input tokens consumed
    var inputTokens: Int? {
        details?["gen_ai.usage.input_tokens"]?.value as? Int
    }

    /// Output tokens generated
    var outputTokens: Int? {
        details?["gen_ai.usage.output_tokens"]?.value as? Int
    }

    /// Cache read tokens (prompt caching)
    var cacheReadTokens: Int? {
        details?["gen_ai.usage.cache_read_tokens"]?.value as? Int
    }

    /// Cache creation tokens (prompt caching)
    var cacheCreationTokens: Int? {
        details?["gen_ai.usage.cache_creation_tokens"]?.value as? Int
    }

    /// Total cost in USD
    var cost: Double? {
        details?["gen_ai.usage.cost"]?.value as? Double
    }

    /// Turn number in the conversation
    var turnNumber: Int? {
        details?["turn_number"]?.value as? Int
    }

    /// Stop reason (end_turn, tool_use, max_tokens, etc.)
    var stopReason: String? {
        details?["stop_reason"]?.value as? String
    }

    /// Formatted token usage string
    var formattedTokens: String? {
        guard let input = inputTokens, let output = outputTokens else { return nil }
        return "\(input) → \(output)"
    }

    /// Formatted cost string
    var formattedCost: String? {
        guard let cost = cost else { return nil }
        return String(format: "$%.4f", cost)
    }

    /// Short model name (e.g., "sonnet-4" from "claude-sonnet-4-20250514")
    var shortModelName: String? {
        guard let model = model else { return nil }
        // Extract model family and version: claude-sonnet-4-20250514 -> sonnet-4
        let parts = model.replacingOccurrences(of: "claude-", with: "").components(separatedBy: "-")
        if parts.count >= 2 {
            return "\(parts[0])-\(parts[1])"
        }
        return model
    }

    var formattedDuration: String {
        guard let ms = durationMs else { return "-" }
        if ms < 1000 {
            return "\(ms)ms"
        }
        return String(format: "%.2fs", Double(ms) / 1000.0)
    }

    // MARK: - Tool Execution Detail Fields (for span inspector)

    /// Tool input arguments (sanitized, from details.tool_input)
    var toolInput: [String: Any]? {
        details?["tool_input"]?.value as? [String: Any]
    }

    /// Tool result data (from details.tool_result)
    var toolResult: Any? {
        details?["tool_result"]?.value
    }

    /// Tool error message (from details.tool_error)
    var toolError: String? {
        details?["tool_error"]?.value as? String
    }

    /// Whether this tool call timed out
    var timedOut: Bool {
        (details?["timed_out"]?.value as? Bool) ?? false
    }

    /// Error type classification (rate_limit, validation, auth, etc.)
    var errorType: String? {
        details?["error_type"]?.value as? String
    }

    /// Whether the error is retryable
    var retryable: Bool {
        (details?["retryable"]?.value as? Bool) ?? false
    }

    /// Marginal cost of the API turn that triggered this tool
    var marginalCost: Double? {
        details?["marginal_cost"]?.value as? Double
    }

    /// Input payload size in bytes
    var inputBytes: Int? {
        details?["input_bytes"]?.value as? Int
    }

    /// Output payload size in bytes
    var outputBytes: Int? {
        details?["output_bytes"]?.value as? Int
    }

    /// OTEL trace ID (W3C 32 hex chars)
    var otelTraceId: String? {
        (details?["otel"]?.value as? [String: Any])?["trace_id"] as? String
    }

    /// OTEL span ID (W3C 16 hex chars)
    var otelSpanId: String? {
        (details?["otel"]?.value as? [String: Any])?["span_id"] as? String
    }

    /// OTEL span kind
    var otelSpanKind: String? {
        (details?["otel"]?.value as? [String: Any])?["span_kind"] as? String
    }

    /// OTEL service name
    var otelServiceName: String? {
        (details?["otel"]?.value as? [String: Any])?["service_name"] as? String
    }

    /// OTEL service version
    var otelServiceVersion: String? {
        (details?["otel"]?.value as? [String: Any])?["service_version"] as? String
    }

    /// Whether this is a tool execution span (not an API request)
    var isToolSpan: Bool {
        action.hasPrefix("tool.")
    }

    /// Tool action (e.g., "adjust" from "tool.inventory.adjust")
    var toolAction: String? {
        let parts = action.components(separatedBy: ".")
        return parts.count >= 3 ? parts[2] : nil
    }

    /// Formatted marginal cost
    var formattedMarginalCost: String? {
        guard let cost = marginalCost, cost > 0 else { return nil }
        return String(format: "$%.6f", cost)
    }

    // MARK: - Human-Readable Activity Description

    /// Generate a human-readable description of what this span did
    var activityDescription: String? {
        // Show error message for failures
        if isError, let error = errorMessage ?? toolError {
            return "Error: \(error.prefix(100))"
        }

        // For API requests, show cache info
        if isApiRequest {
            if let cacheRead = cacheReadTokens, let input = inputTokens, cacheRead > 0 {
                let cachePercent = Int((Double(cacheRead) / Double(input)) * 100)
                return "💾 \(cachePercent)% cached"
            }
            return nil
        }

        // For tool executions, parse input/output for meaningful info
        guard isToolSpan, let toolName = toolName else { return nil }

        let parts = toolName.components(separatedBy: ".")
        let baseTool = parts.first ?? toolName
        let action = parts.count >= 2 ? parts[1] : nil

        // Parse based on tool type
        switch baseTool {
        case "inventory":
            return formatInventoryActivity(action: action)
        case "transfers":
            return formatTransferActivity(action: action)
        case "products":
            return formatProductActivity(action: action)
        case "orders":
            return formatOrderActivity(action: action)
        case "customers":
            return formatCustomerActivity(action: action)
        case "purchase_orders":
            return formatPurchaseOrderActivity(action: action)
        case "analytics":
            return formatAnalyticsActivity(action: action)
        default:
            // Generic fallback: show first line of result
            return formatGenericActivity()
        }
    }

    private func formatInventoryActivity(action: String?) -> String? {
        guard let input = toolInput else { return nil }

        switch action {
        case "adjust":
            let productId = input["product_id"] as? String ?? "?"
            let adjustment = input["adjustment"] as? Int ?? 0
            let sign = adjustment >= 0 ? "+" : ""
            return "Product #\(productId.prefix(8)): \(sign)\(adjustment) units"

        case "set":
            let productId = input["product_id"] as? String ?? "?"
            let quantity = input["quantity"] as? Int ?? 0
            return "Set Product #\(productId.prefix(8)) → \(quantity) units"

        case "transfer":
            let productId = input["product_id"] as? String ?? "?"
            let qty = input["quantity"] as? Int ?? 0
            return "Transferred \(qty) units of #\(productId.prefix(8))"

        default:
            return nil
        }
    }

    private func formatTransferActivity(action: String?) -> String? {
        guard let input = toolInput else { return nil }

        switch action {
        case "create":
            if let items = input["items"] as? [[String: Any]] {
                let count = items.count
                return "Created transfer: \(count) item\(count == 1 ? "" : "s")"
            }
            return "Created transfer"

        case "receive":
            if let result = toolResult as? [String: Any],
               let id = result["id"] as? String {
                return "Received transfer #\(id.prefix(8))"
            }
            return "Received transfer"

        case "cancel":
            return "Cancelled transfer"

        default:
            return nil
        }
    }

    private func formatProductActivity(action: String?) -> String? {
        guard let input = toolInput else { return nil }

        switch action {
        case "create":
            let name = input["name"] as? String ?? "New product"
            return "Created: \(name)"

        case "update":
            if let result = toolResult as? [String: Any],
               let name = result["name"] as? String {
                return "Updated: \(name)"
            }
            return "Updated product"

        case "find":
            if let result = toolResult as? [[String: Any]] {
                return "Found \(result.count) product\(result.count == 1 ? "" : "s")"
            }
            return nil

        default:
            return nil
        }
    }

    private func formatOrderActivity(action: String?) -> String? {
        guard let input = toolInput else { return nil }

        switch action {
        case "find":
            if let result = toolResult as? [[String: Any]] {
                return "Found \(result.count) order\(result.count == 1 ? "" : "s")"
            }
            return nil

        case "get":
            if let result = toolResult as? [String: Any],
               let orderNum = result["order_number"] as? String {
                return "Order #\(orderNum)"
            }
            return nil

        default:
            return nil
        }
    }

    private func formatCustomerActivity(action: String?) -> String? {
        guard let input = toolInput else { return nil }

        switch action {
        case "create":
            let name = [input["first_name"] as? String, input["last_name"] as? String]
                .compactMap { $0 }
                .joined(separator: " ")
            return "Created customer: \(name)"

        case "find":
            if let result = toolResult as? [[String: Any]] {
                return "Found \(result.count) customer\(result.count == 1 ? "" : "s")"
            }
            return nil

        default:
            return nil
        }
    }

    private func formatPurchaseOrderActivity(action: String?) -> String? {
        guard let input = toolInput else { return nil }

        switch action {
        case "create":
            return "Created purchase order"

        case "approve":
            return "Approved purchase order"

        case "receive":
            return "Received purchase order"

        default:
            return nil
        }
    }

    private func formatAnalyticsActivity(action: String?) -> String? {
        guard let result = toolResult as? [String: Any] else { return nil }

        switch action {
        case "summary":
            if let revenue = result["total_revenue"] as? Double,
               let orders = result["order_count"] as? Int {
                return "\(orders) orders, $\(String(format: "%.0f", revenue)) revenue"
            }
            return nil

        default:
            if let data = result["data"] as? [[String: Any]] {
                return "Analyzed \(data.count) record\(data.count == 1 ? "" : "s")"
            }
            return nil
        }
    }

    private func formatGenericActivity() -> String? {
        // For unknown tools, show first line of result
        if let result = toolResult as? String {
            let firstLine = result.components(separatedBy: .newlines).first ?? result
            return String(firstLine.prefix(60))
        } else if let result = toolResult as? [String: Any],
                  let message = result["message"] as? String {
            return String(message.prefix(60))
        }
        return nil
    }

    /// Formatted payload sizes
    var formattedPayloadSize: String? {
        guard let inBytes = inputBytes, let outBytes = outputBytes else { return nil }
        return "\(formatBytes(inBytes)) in / \(formatBytes(outBytes)) out"
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return String(format: "%.1fKB", Double(bytes) / 1024.0) }
        return String(format: "%.1fMB", Double(bytes) / (1024.0 * 1024.0))
    }
}

/// A complete trace (group of spans with same request_id)
struct Trace: Identifiable, Hashable {
    let id: String  // request_id
    let spans: [TelemetrySpan]
    let rootSpan: TelemetrySpan?
    let startTime: Date
    let endTime: Date?

    static func == (lhs: Trace, rhs: Trace) -> Bool {
        lhs.id == rhs.id && lhs.spans.count == rhs.spans.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(spans.count)
    }

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        guard let dur = duration else { return "-" }
        if dur < 1 {
            return String(format: "%.0fms", dur * 1000)
        }
        return String(format: "%.2fs", dur)
    }

    var toolCount: Int {
        spans.filter { $0.action.hasPrefix("tool.") }.count
    }

    var errorCount: Int {
        spans.filter { $0.isError }.count
    }

    var hasErrors: Bool {
        errorCount > 0
    }

    var source: String {
        rootSpan?.source ?? spans.first?.source ?? "unknown"
    }

    // MARK: - Aggregated AI Telemetry

    /// All API request spans in this trace
    var apiRequestSpans: [TelemetrySpan] {
        spans.filter { $0.isApiRequest }
    }

    /// Total input tokens across all API calls
    var totalInputTokens: Int {
        apiRequestSpans.compactMap { $0.inputTokens }.reduce(0, +)
    }

    /// Total output tokens across all API calls
    var totalOutputTokens: Int {
        apiRequestSpans.compactMap { $0.outputTokens }.reduce(0, +)
    }

    /// Total cache read tokens across all API calls
    var totalCacheReadTokens: Int {
        apiRequestSpans.compactMap { $0.cacheReadTokens }.reduce(0, +)
    }

    /// Total cost across all API calls
    var totalCost: Double {
        apiRequestSpans.compactMap { $0.cost }.reduce(0, +)
    }

    /// Number of API turns in this trace
    var turnCount: Int {
        apiRequestSpans.count
    }

    /// Model used (from first API request)
    var model: String? {
        apiRequestSpans.first?.model
    }

    /// Short model name (e.g., "sonnet-4")
    var shortModelName: String? {
        apiRequestSpans.first?.shortModelName
    }

    /// Formatted token usage for trace
    var formattedTokens: String? {
        guard totalInputTokens > 0 || totalOutputTokens > 0 else { return nil }
        return "\(totalInputTokens) → \(totalOutputTokens)"
    }

    /// Formatted total cost
    var formattedCost: String? {
        guard totalCost > 0 else { return nil }
        return String(format: "$%.4f", totalCost)
    }

    /// Has AI telemetry data?
    var hasAITelemetry: Bool {
        !apiRequestSpans.isEmpty
    }
}

/// A conversation session (group of traces with same conversation_id)
/// One entry in the sidebar = one conversation session
struct TelemetrySession: Identifiable, Hashable {
    let id: String  // conversation_id
    let traces: [Trace]
    let startTime: Date
    let endTime: Date?

    /// Include trace count + span count so SwiftUI detects realtime updates
    static func == (lhs: TelemetrySession, rhs: TelemetrySession) -> Bool {
        lhs.id == rhs.id
            && lhs.traces.count == rhs.traces.count
            && lhs.allSpans.count == rhs.allSpans.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(traces.count)
    }

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        guard let dur = duration else { return "-" }
        if dur < 1 {
            return String(format: "%.0fms", dur * 1000)
        }
        if dur < 60 {
            return String(format: "%.1fs", dur)
        }
        let mins = Int(dur / 60)
        let secs = Int(dur) % 60
        return "\(mins)m \(secs)s"
    }

    /// All spans across all traces in this session
    var allSpans: [TelemetrySpan] {
        traces.flatMap { $0.spans }
    }

    var toolCount: Int {
        allSpans.filter { $0.action.hasPrefix("tool.") }.count
    }

    var errorCount: Int {
        allSpans.filter { $0.isError }.count
    }

    var hasErrors: Bool {
        errorCount > 0
    }

    var source: String {
        traces.first?.source ?? "unknown"
    }

    /// Number of user turns (each trace = one user prompt/turn)
    var turnCount: Int {
        traces.count
    }

    // MARK: - Aggregated AI Telemetry

    var totalInputTokens: Int {
        traces.map { $0.totalInputTokens }.reduce(0, +)
    }

    var totalOutputTokens: Int {
        traces.map { $0.totalOutputTokens }.reduce(0, +)
    }

    var totalCost: Double {
        traces.map { $0.totalCost }.reduce(0, +)
    }

    var model: String? {
        traces.first?.model
    }

    var shortModelName: String? {
        traces.first?.shortModelName
    }

    var formattedCost: String? {
        guard totalCost > 0 else { return nil }
        return String(format: "$%.4f", totalCost)
    }

    var hasAITelemetry: Bool {
        traces.contains { $0.hasAITelemetry }
    }

    var agentName: String? {
        allSpans.first(where: { $0.agentName != nil })?.agentName
    }

    var userEmail: String? {
        allSpans.first(where: { $0.userEmail != nil })?.userEmail
    }

    var userName: String? {
        guard let email = userEmail else { return nil }
        // Extract name from email (e.g., "john.doe@example.com" -> "John Doe")
        let localPart = email.components(separatedBy: "@").first ?? email
        return localPart
            .components(separatedBy: ".")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    var userInitials: String {
        guard let name = userName else { return "U" }
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.prefix(2)
        return String(initials).uppercased()
    }
}

/// Aggregated stats for a time period
struct TelemetryStats: Codable {
    let totalTraces: Int
    let totalSpans: Int
    let toolCalls: Int
    let errors: Int
    let avgDurationMs: Double?
    let byAction: [String: Int]?
    let bySource: [String: Int]?
    let p50Ms: Double?
    let p95Ms: Double?
    let p99Ms: Double?

    enum CodingKeys: String, CodingKey {
        case totalTraces = "total_traces"
        case totalSpans = "total_spans"
        case toolCalls = "tool_calls"
        case errors
        case avgDurationMs = "avg_duration_ms"
        case byAction = "by_action"
        case bySource = "by_source"
        case p50Ms = "p50_ms"
        case p95Ms = "p95_ms"
        case p99Ms = "p99_ms"
    }

    var successRate: Double {
        guard toolCalls > 0 else { return 1.0 }
        return Double(toolCalls - errors) / Double(toolCalls)
    }
}

// MARK: - Tool Analytics Models

/// Per-tool performance metrics from get_tool_analytics() RPC
struct ToolPerformance: Identifiable, Codable {
    var id: String { toolName }
    let toolName: String
    let totalCalls: Int
    let successCount: Int
    let errorCount: Int
    let timeoutCount: Int
    let errorRate: Double
    let avgMs: Double
    let p50Ms: Double
    let p90Ms: Double
    let p95Ms: Double
    let p99Ms: Double
    let minMs: Int
    let maxMs: Int
    let avgInputBytes: Int
    let avgOutputBytes: Int
    let totalMarginalCost: Double
    let callsPerMinute: Double
    let reliabilityScore: Double
    let actions: [String: ToolActionMetrics]
    let errorTypes: [String: Int]

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case totalCalls = "total_calls"
        case successCount = "success_count"
        case errorCount = "error_count"
        case timeoutCount = "timeout_count"
        case errorRate = "error_rate"
        case avgMs = "avg_ms"
        case p50Ms = "p50_ms"
        case p90Ms = "p90_ms"
        case p95Ms = "p95_ms"
        case p99Ms = "p99_ms"
        case minMs = "min_ms"
        case maxMs = "max_ms"
        case avgInputBytes = "avg_input_bytes"
        case avgOutputBytes = "avg_output_bytes"
        case totalMarginalCost = "total_marginal_cost"
        case callsPerMinute = "calls_per_minute"
        case reliabilityScore = "reliability_score"
        case actions, errorTypes = "error_types"
    }

    var formattedReliability: String {
        String(format: "%.1f%%", reliabilityScore)
    }

    var formattedCost: String {
        totalMarginalCost > 0 ? String(format: "$%.4f", totalMarginalCost) : "-"
    }

    var latencyCategory: String {
        if p95Ms < 200 { return "fast" }
        if p95Ms < 1000 { return "normal" }
        return "slow"
    }
}

/// Metrics for a specific tool action (e.g., inventory.adjust)
struct ToolActionMetrics: Codable {
    let count: Int
    let avgMs: Double
    let p50Ms: Double
    let p95Ms: Double
    let errorCount: Int
    let errorRate: Double

    enum CodingKeys: String, CodingKey {
        case count
        case avgMs = "avg_ms"
        case p50Ms = "p50_ms"
        case p95Ms = "p95_ms"
        case errorCount = "error_count"
        case errorRate = "error_rate"
    }
}

/// Summary from get_tool_analytics()
struct ToolAnalyticsSummary: Codable {
    let totalCalls: Int
    let totalErrors: Int
    let totalTimeouts: Int
    let overallErrorRate: Double
    let overallAvgMs: Double
    let overallP50Ms: Double
    let overallP95Ms: Double
    let uniqueTools: Int
    let totalMarginalCost: Double
    let slowestTool: String?
    let mostUsedTool: String?
    let mostErrorsTool: String?
    let hoursAnalyzed: Int

    enum CodingKeys: String, CodingKey {
        case totalCalls = "total_calls"
        case totalErrors = "total_errors"
        case totalTimeouts = "total_timeouts"
        case overallErrorRate = "overall_error_rate"
        case overallAvgMs = "overall_avg_ms"
        case overallP50Ms = "overall_p50_ms"
        case overallP95Ms = "overall_p95_ms"
        case uniqueTools = "unique_tools"
        case totalMarginalCost = "total_marginal_cost"
        case slowestTool = "slowest_tool"
        case mostUsedTool = "most_used_tool"
        case mostErrorsTool = "most_errors_tool"
        case hoursAnalyzed = "hours_analyzed"
    }

    var formattedErrorRate: String {
        String(format: "%.1f%%", overallErrorRate)
    }

    var formattedCost: String {
        totalMarginalCost > 0 ? String(format: "$%.4f", totalMarginalCost) : "$0"
    }
}

/// Full response from get_tool_analytics()
struct ToolAnalyticsResponse: Codable {
    let tools: [ToolPerformance]
    let summary: ToolAnalyticsSummary
}

/// Span comparison data from get_tool_trace_detail()
struct SpanComparison: Codable {
    let avgMs: Double
    let p95Ms: Double
    let errorRate: Double
    let totalCalls24h: Int
    let isSlow: Bool
    let percentileRank: Double

    enum CodingKeys: String, CodingKey {
        case avgMs = "avg_ms"
        case p95Ms = "p95_ms"
        case errorRate = "error_rate"
        case totalCalls24h = "total_calls_24h"
        case isSlow = "is_slow"
        case percentileRank = "percentile_rank"
    }
}

/// Timeline bucket for tool performance charts
struct ToolTimelineBucket: Codable, Identifiable {
    var id: String { "\(time)-\(tool)" }
    let time: Date
    let tool: String
    let calls: Int
    let errors: Int
    let timeouts: Int
    let avgMs: Double
    let p95Ms: Double
    let maxMs: Int

    enum CodingKeys: String, CodingKey {
        case time, tool, calls, errors, timeouts
        case avgMs = "avg_ms"
        case p95Ms = "p95_ms"
        case maxMs = "max_ms"
    }
}
