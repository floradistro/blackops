import Foundation
import Supabase
import Realtime

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

// MARK: - Telemetry Service

@MainActor
class TelemetryService: ObservableObject {
    static let shared = TelemetryService()

    @Published var recentTraces: [Trace] = []
    @Published var recentSessions: [TelemetrySession] = []
    @Published var currentTrace: Trace?
    @Published var stats: TelemetryStats?
    @Published var isLoading = false
    @Published var error: String?
    @Published var isLive = false  // Realtime connection status
    @Published var updateCount = 0  // Incremented on realtime updates to trigger UI refresh

    // Active conversation tracking — set by AIChatStore, consumed by TelemetryPanel
    @Published var activeConversationId: String?

    // Filter state
    @Published var sourceFilter: String?
    @Published var agentFilter: String?  // Filter by agent name
    @Published var onlyErrors: Bool = false
    @Published var timeRange: TimeRange = .lastHour

    // Available agents (populated from store's configured agents + traces)
    @Published var availableAgents: [String] = []

    // Configured agents for the store (fetched from ai_agents table)
    private var configuredAgents: [String] = []

    // Realtime
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var currentStoreId: UUID?

    enum TimeRange: String, CaseIterable {
        case last15m = "15m"
        case lastHour = "1h"
        case last6h = "6h"
        case last24h = "24h"
        case last7d = "7d"

        var hours: Int {
            switch self {
            case .last15m: return 1
            case .lastHour: return 1
            case .last6h: return 6
            case .last24h: return 24
            case .last7d: return 168
            }
        }

        var minutes: Int {
            switch self {
            case .last15m: return 15
            default: return hours * 60
            }
        }
    }

    private init() {}

    // MARK: - Realtime Subscription

    /// Start realtime subscription for instant log updates
    func startRealtime(storeId: UUID?) {
        // Don't restart if already running
        if realtimeTask != nil && isLive { return }

        stopRealtime()
        currentStoreId = storeId

        realtimeTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            print("[Telemetry] Starting realtime subscription...")

            // Use main client for realtime (adminClient may not have realtime configured)
            // RLS shouldn't matter for realtime - we filter client-side anyway
            let client = SupabaseService.shared.client

            // Subscribe to audit_logs inserts
            let channel = client.realtimeV2.channel("telemetry-live")
            self.realtimeChannel = channel

            // Listen for new tool executions
            let inserts = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "audit_logs"
            )

            do {
                try await channel.subscribeWithError()
                print("[Telemetry] Realtime subscribed successfully!")
                self.isLive = true

                print("[Telemetry] Entering insert loop...")
                for await insert in inserts {
                    print("[Telemetry] >>> INSERT EVENT RECEIVED <<<")
                    self.handleNewSpan(insert)
                }
                print("[Telemetry] Insert loop ended")
            } catch {
                print("[Telemetry] Realtime error: \(error)")
                self.isLive = false
            }
        }
    }

    /// Stop realtime subscription
    func stopRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil

        if let channel = realtimeChannel {
            let channelToCleanup = channel
            realtimeChannel = nil
            Task.detached {
                await channelToCleanup.unsubscribe()
            }
        }
        isLive = false
    }

    /// Handle new span from realtime (called on MainActor)
    private func handleNewSpan(_ insert: InsertAction) {
        let record = insert.record
        print("[Telemetry] Realtime INSERT received: \(record["action"]?.stringValue ?? "unknown")")

        // Check if it's a tool action or API request (for AI telemetry)
        guard let action = record["action"]?.stringValue,
              (action.hasPrefix("tool.") || action == "claude_api_request") else {
            print("[Telemetry] Skipping non-telemetry action")
            return
        }

        // Filter by store only if a specific store is selected
        // If currentStoreId is nil, show all events (global telemetry view)
        if let storeId = currentStoreId {
            let spanStoreId = record["store_id"]?.stringValue
            // Case-insensitive comparison - Postgres returns lowercase, Swift UUID uses uppercase
            if let spanStoreId = spanStoreId,
               spanStoreId.lowercased() != storeId.uuidString.lowercased() {
                // Skip - different store
                return
            }
            // Note: If spanStoreId is nil, we still show it (global events)
        }

        // Decode and insert
        do {
            let jsonData = try JSONEncoder().encode(record)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let span = try decoder.decode(TelemetrySpan.self, from: jsonData)

            print("[Telemetry] Decoded span: \(span.action), inserting into traces")
            // Direct call since we're already on MainActor
            insertSpanIntoTraces(span)
            print("[Telemetry] After insert - trace count: \(recentTraces.count), updateCount: \(updateCount)")
        } catch {
            print("[Telemetry] Decode error: \(error)")
        }
    }

    /// Insert a new span into existing traces or create new trace
    private func insertSpanIntoTraces(_ span: TelemetrySpan) {
        let traceId = span.requestId ?? span.id.uuidString

        // Check if trace exists
        if let index = recentTraces.firstIndex(where: { $0.id == traceId }) {
            // Update existing trace with new span
            let existingTrace = recentTraces[index]
            var updatedSpans = existingTrace.spans
            updatedSpans.append(span)
            updatedSpans.sort { $0.createdAt < $1.createdAt }

            let updatedTrace = Trace(
                id: traceId,
                spans: updatedSpans,
                rootSpan: updatedSpans.first { $0.parentId == nil },
                startTime: existingTrace.startTime,
                endTime: updatedSpans.last?.createdAt
            )

            // Force SwiftUI to detect the change by removing and re-inserting
            recentTraces.remove(at: index)
            recentTraces.insert(updatedTrace, at: index)
        } else {
            // Create new trace at beginning (most recent)
            let newTrace = Trace(
                id: traceId,
                spans: [span],
                rootSpan: span.parentId == nil ? span : nil,
                startTime: span.createdAt,
                endTime: span.createdAt
            )
            recentTraces.insert(newTrace, at: 0)

            // Keep max 100 traces
            if recentTraces.count > 100 {
                recentTraces = Array(recentTraces.prefix(100))
            }
        }

        // Rebuild sessions from updated traces
        rebuildSessions()

        // Increment update counter to ensure SwiftUI observes the change
        updateCount += 1
    }

    /// Rebuild sessions from current recentTraces
    private func rebuildSessions() {
        var sessionMap: [String: [Trace]] = [:]
        for trace in recentTraces {
            let convId = trace.spans.compactMap({ $0.conversationId }).first ?? trace.id
            sessionMap[convId, default: []].append(trace)
        }

        var sessions: [TelemetrySession] = []
        for (convId, sessionTraces) in sessionMap {
            let sorted = sessionTraces.sorted { $0.startTime < $1.startTime }
            sessions.append(TelemetrySession(
                id: convId,
                traces: sorted,
                startTime: sorted.first?.startTime ?? Date(),
                endTime: sorted.last?.endTime
            ))
        }
        recentSessions = sessions.sorted { $0.startTime > $1.startTime }
    }

    // MARK: - Fetch Recent Traces

    func fetchRecentTraces(storeId: UUID?) async {
        isLoading = true
        error = nil

        do {
            // Use adminClient to bypass RLS for telemetry reads
            let supabase = SupabaseService.shared.adminClient
            let cutoff = Date().addingTimeInterval(-Double(timeRange.minutes * 60))

            // Format with timezone for proper comparison
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let cutoffString = formatter.string(from: cutoff)

            // Silent fetch - no logging spam

            // Build query with all filters first, then order/limit
            // Fetch both tool.* actions AND claude_api_request for AI telemetry
            var baseQuery = supabase
                .from("audit_logs")
                .select()
                .or("action.like.tool.%,action.eq.claude_api_request")
                .gte("created_at", value: cutoffString)

            if let storeId = storeId {
                baseQuery = baseQuery.eq("store_id", value: storeId.uuidString)
            }

            if onlyErrors {
                baseQuery = baseQuery.eq("severity", value: "error")
            }

            // Apply order and limit after all filters
            let response: [TelemetrySpan] = try await baseQuery
                .order("created_at", ascending: false)
                .limit(500)
                .execute()
                .value


            // Group by request_id to form traces
            // Spans without request_id get their own trace using span ID
            var traceMap: [String: [TelemetrySpan]] = [:]
            for span in response {
                let traceId = span.requestId ?? span.id.uuidString
                traceMap[traceId, default: []].append(span)
            }

            // Build Trace objects and collect unique agents
            var traces: [Trace] = []
            var agentSet: Set<String> = []

            for (reqId, spans) in traceMap {
                let sorted = spans.sorted { $0.createdAt < $1.createdAt }
                let trace = Trace(
                    id: reqId,
                    spans: sorted,
                    rootSpan: sorted.first { $0.parentId == nil },
                    startTime: sorted.first?.createdAt ?? Date(),
                    endTime: sorted.last?.createdAt
                )

                // Collect agent names from spans
                for span in sorted {
                    if let agentName = span.agentName, !agentName.isEmpty {
                        agentSet.insert(agentName)
                    }
                }

                // Apply source filter
                if let filter = sourceFilter, !filter.isEmpty {
                    if trace.source != filter { continue }
                }

                // Apply agent filter
                if let agentFilterValue = agentFilter, !agentFilterValue.isEmpty {
                    let traceAgentName = sorted.first?.agentName ?? ""
                    if traceAgentName != agentFilterValue { continue }
                }

                traces.append(trace)
            }

            // Sort by most recent first
            recentTraces = traces.sorted { $0.startTime > $1.startTime }

            // Build sessions by grouping traces by conversation_id
            var sessionMap: [String: [Trace]] = [:]
            for trace in recentTraces {
                // Get conversation_id from any span in the trace
                let convId = trace.spans.compactMap({ $0.conversationId }).first ?? trace.id
                sessionMap[convId, default: []].append(trace)
            }

            var sessions: [TelemetrySession] = []
            for (convId, sessionTraces) in sessionMap {
                let sorted = sessionTraces.sorted { $0.startTime < $1.startTime }
                sessions.append(TelemetrySession(
                    id: convId,
                    traces: sorted,
                    startTime: sorted.first?.startTime ?? Date(),
                    endTime: sorted.last?.endTime
                ))
            }
            recentSessions = sessions.sorted { $0.startTime > $1.startTime }

            // Merge agents from traces with configured agents
            let allAgents = agentSet.union(Set(configuredAgents))
            availableAgents = allAgents.sorted()

        } catch {
            self.error = error.localizedDescription
            print("[Telemetry] Error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Fetch Configured Agents

    /// Fetch agents configured for this store from ai_agents table
    func fetchConfiguredAgents(storeId: UUID?) async {
        guard let storeId = storeId else {
            configuredAgents = []
            return
        }

        do {
            let supabase = SupabaseService.shared.adminClient

            struct AgentName: Decodable {
                let name: String
            }

            let response: [AgentName] = try await supabase
                .from("ai_agent_config")
                .select("name")
                .eq("store_id", value: storeId.uuidString)
                .execute()
                .value

            configuredAgents = response.map { $0.name }

            // Merge with existing available agents
            let allAgents = Set(availableAgents).union(Set(configuredAgents))
            availableAgents = allAgents.sorted()

        } catch {
            print("[Telemetry] Error fetching configured agents: \(error)")
        }
    }

    // MARK: - Fetch Single Trace

    func fetchTrace(requestId: String) async {
        isLoading = true
        error = nil

        do {
            let supabase = SupabaseService.shared.adminClient

            // Fetch all spans with this request_id
            let response: [TelemetrySpan] = try await supabase
                .from("audit_logs")
                .select()
                .eq("request_id", value: requestId)
                .order("created_at", ascending: true)
                .execute()
                .value

            if response.isEmpty {
                self.error = "Trace not found"
                currentTrace = nil
            } else {
                currentTrace = Trace(
                    id: requestId,
                    spans: response,
                    rootSpan: response.first { $0.parentId == nil },
                    startTime: response.first?.createdAt ?? Date(),
                    endTime: response.last?.createdAt
                )
            }

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Fetch Stats

    func fetchStats(storeId: UUID?) async {
        do {
            let supabase = SupabaseService.shared.adminClient
            let cutoff = Date().addingTimeInterval(-Double(timeRange.hours * 3600))

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let cutoffString = formatter.string(from: cutoff)

            // Build query with all filters first
            var baseQuery = supabase
                .from("audit_logs")
                .select("id, severity, duration_ms", head: false, count: .exact)
                .like("action", pattern: "tool.%")
                .gte("created_at", value: cutoffString)

            if let storeId = storeId {
                baseQuery = baseQuery.eq("store_id", value: storeId.uuidString)
            }

            let response: [TelemetrySpan] = try await baseQuery.execute().value

            let totalSpans = response.count
            let errors = response.filter { $0.isError }.count
            let durations = response.compactMap { $0.durationMs }.sorted()

            let avgDuration = durations.isEmpty ? nil : Double(durations.reduce(0, +)) / Double(durations.count)
            let p50 = durations.isEmpty ? nil : Double(durations[durations.count / 2])
            let p95 = durations.isEmpty ? nil : Double(durations[Int(Double(durations.count) * 0.95)])
            let p99 = durations.isEmpty ? nil : Double(durations[Int(Double(durations.count) * 0.99)])

            stats = TelemetryStats(
                totalTraces: recentTraces.count,
                totalSpans: totalSpans,
                toolCalls: totalSpans,
                errors: errors,
                avgDurationMs: avgDuration,
                byAction: nil,
                bySource: nil,
                p50Ms: p50,
                p95Ms: p95,
                p99Ms: p99
            )

        } catch {
            // Stats are optional, don't show error
            print("[Telemetry] Stats error: \(error)")
        }
    }

    // MARK: - Tool Analytics

    @Published var toolAnalytics: ToolAnalyticsResponse?
    @Published var toolTimeline: [ToolTimelineBucket] = []
    @Published var selectedSpanComparison: SpanComparison?
    @Published var isLoadingToolAnalytics = false

    // RPC param structs (Supabase Swift SDK requires Encodable)
    private struct ToolAnalyticsParams: Encodable {
        let p_store_id: String?
        let p_hours_back: Int
    }

    private struct ToolTimelineParams: Encodable {
        let p_store_id: String?
        let p_hours_back: Int
        let p_bucket_minutes: Int
    }

    private struct SpanDetailParams: Encodable {
        let p_span_id: String
    }

    /// Fetch comprehensive tool analytics via RPC
    func fetchToolAnalytics(storeId: UUID?, hoursBack: Int? = nil) async {
        isLoadingToolAnalytics = true
        defer { isLoadingToolAnalytics = false }

        do {
            let supabase = SupabaseService.shared.adminClient
            let hours = hoursBack ?? timeRange.hours

            let response = try await supabase.rpc(
                "get_tool_analytics",
                params: ToolAnalyticsParams(
                    p_store_id: storeId?.uuidString,
                    p_hours_back: hours
                )
            ).execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            toolAnalytics = try decoder.decode(ToolAnalyticsResponse.self, from: response.data)

        } catch {
            print("[Telemetry] Tool analytics error: \(error)")
        }
    }

    /// Fetch tool performance timeline for charts
    func fetchToolTimeline(storeId: UUID?, hoursBack: Int? = nil, bucketMinutes: Int = 15) async {
        do {
            let supabase = SupabaseService.shared.adminClient
            let hours = hoursBack ?? timeRange.hours

            let response = try await supabase.rpc(
                "get_tool_timeline",
                params: ToolTimelineParams(
                    p_store_id: storeId?.uuidString,
                    p_hours_back: hours,
                    p_bucket_minutes: bucketMinutes
                )
            ).execute()

            struct TimelineResponse: Codable {
                let buckets: [ToolTimelineBucket]
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let result = try decoder.decode(TimelineResponse.self, from: response.data)
            toolTimeline = result.buckets

        } catch {
            print("[Telemetry] Tool timeline error: \(error)")
        }
    }

    /// Fetch span comparison data (how this span compares to average)
    func fetchSpanComparison(spanId: UUID) async {
        do {
            let supabase = SupabaseService.shared.adminClient

            let response = try await supabase.rpc(
                "get_tool_trace_detail",
                params: SpanDetailParams(p_span_id: spanId.uuidString)
            ).execute()

            struct DetailResponse: Codable {
                let comparison: SpanComparison
            }
            let decoder = JSONDecoder()
            let result = try decoder.decode(DetailResponse.self, from: response.data)
            selectedSpanComparison = result.comparison

        } catch {
            print("[Telemetry] Span comparison error: \(error)")
            selectedSpanComparison = nil
        }
    }

    // MARK: - Build Span Tree

    func buildSpanTree(from spans: [TelemetrySpan]) -> [TelemetrySpan] {
        var spanMap: [UUID: TelemetrySpan] = [:]
        var rootSpans: [TelemetrySpan] = []

        // First pass: index all spans
        for span in spans {
            spanMap[span.id] = span
        }

        // Second pass: build tree
        for span in spans {
            if let parentId = span.parentId, var parent = spanMap[parentId] {
                var child = span
                child.depth = parent.depth + 1
                parent.children.append(child)
                spanMap[parentId] = parent
            } else {
                var root = span
                root.depth = 0
                rootSpans.append(root)
            }
        }

        return rootSpans
    }
}
