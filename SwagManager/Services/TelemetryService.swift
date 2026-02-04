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

    var formattedDuration: String {
        guard let ms = durationMs else { return "-" }
        if ms < 1000 {
            return "\(ms)ms"
        }
        return String(format: "%.2fs", Double(ms) / 1000.0)
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
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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

// MARK: - Telemetry Service

@MainActor
class TelemetryService: ObservableObject {
    static let shared = TelemetryService()

    @Published var recentTraces: [Trace] = []
    @Published var currentTrace: Trace?
    @Published var stats: TelemetryStats?
    @Published var isLoading = false
    @Published var error: String?
    @Published var isLive = false  // Realtime connection status
    @Published var updateCount = 0  // Incremented on realtime updates to trigger UI refresh

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

        // Check if it's a tool action
        guard let action = record["action"]?.stringValue,
              action.hasPrefix("tool.") else {
            print("[Telemetry] Skipping non-tool action")
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

        // Increment update counter to ensure SwiftUI observes the change
        updateCount += 1
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
            var baseQuery = supabase
                .from("audit_logs")
                .select()
                .like("action", pattern: "tool.%")
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
