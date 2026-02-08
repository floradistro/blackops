import Foundation
import Supabase
import Realtime

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

    // Persistent session map: conversationId -> [Trace]
    // Maintained incrementally on realtime inserts to avoid O(n*m) rebuilds
    private var sessionMap: [String: [Trace]] = [:]

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
                // Defer state change to avoid layout recursion
                DispatchQueue.main.async { self.isLive = true }

                print("[Telemetry] Entering insert loop...")
                for await insert in inserts {
                    print("[Telemetry] >>> INSERT EVENT RECEIVED <<<")
                    self.handleNewSpan(insert)
                }
                print("[Telemetry] Insert loop ended")
            } catch {
                print("[Telemetry] Realtime error: \(error)")
                // Defer state change to avoid layout recursion
                DispatchQueue.main.async { self.isLive = false }
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
        // Defer state change to avoid layout recursion when called from view lifecycle
        DispatchQueue.main.async { self.isLive = false }
    }

    /// Handle new span from realtime - decodes in background to avoid blocking main thread
    private func handleNewSpan(_ insert: InsertAction) {
        let record = insert.record
        let storeId = currentStoreId

        // Decode in background to avoid main thread blocking
        Task.detached { [weak self] in
            // Check if it's a tool action or API request (for AI telemetry)
            guard let action = record["action"]?.stringValue,
                  (action.hasPrefix("tool.") || action == "claude_api_request") else {
                return
            }

            // Filter by store only if a specific store is selected
            if let storeId = storeId {
                let spanStoreId = record["store_id"]?.stringValue
                if let spanStoreId = spanStoreId,
                   spanStoreId.lowercased() != storeId.uuidString.lowercased() {
                    return
                }
            }

            // Decode in background
            do {
                let jsonData = try JSONEncoder().encode(record)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let span = try decoder.decode(TelemetrySpan.self, from: jsonData)

                // Only update UI on main thread
                await MainActor.run { [weak self] in
                    self?.insertSpanIntoTraces(span)
                }
            } catch {
                print("[Telemetry] Decode error: \(error)")
            }
        }
    }

    /// Insert a new span into existing traces or create new trace
    /// Incrementally updates only the affected session instead of rebuilding all sessions
    private func insertSpanIntoTraces(_ span: TelemetrySpan) {
        let traceId = span.requestId ?? span.id.uuidString

        // Determine the conversation ID for this span's session
        let conversationId = span.conversationId ?? traceId

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

            // Incrementally update only the affected session in sessionMap
            // Find and replace the old trace with the updated one in the session's trace list
            if var sessionTraces = sessionMap[conversationId] {
                if let traceIdx = sessionTraces.firstIndex(where: { $0.id == traceId }) {
                    sessionTraces[traceIdx] = updatedTrace
                } else {
                    sessionTraces.append(updatedTrace)
                }
                sessionMap[conversationId] = sessionTraces
            } else {
                sessionMap[conversationId] = [updatedTrace]
            }
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

            // Incrementally add the new trace to the session map
            sessionMap[conversationId, default: []].append(newTrace)
        }

        // Rebuild only the affected session and update the published array
        updateSessionFromMap(conversationId: conversationId)

        // Increment update counter to ensure SwiftUI observes the change
        updateCount += 1
    }

    /// Update recentSessions for a single conversation that changed
    /// Avoids O(n*m) full rebuild by only recomputing the affected session
    private func updateSessionFromMap(conversationId: String) {
        guard let sessionTraces = sessionMap[conversationId] else { return }
        let sorted = sessionTraces.sorted { $0.startTime < $1.startTime }
        let updatedSession = TelemetrySession(
            id: conversationId,
            traces: sorted,
            startTime: sorted.first?.startTime ?? Date(),
            endTime: sorted.last?.endTime
        )

        // Find and replace existing session, or insert at the correct position
        if let idx = recentSessions.firstIndex(where: { $0.id == conversationId }) {
            recentSessions[idx] = updatedSession
        } else {
            // Insert new session in sorted order (most recent first)
            let insertIdx = recentSessions.firstIndex(where: { $0.startTime < updatedSession.startTime }) ?? recentSessions.endIndex
            recentSessions.insert(updatedSession, at: insertIdx)
        }
    }

    /// Full rebuild of sessions from current recentTraces
    /// Used only on initial load; realtime inserts use incremental updateSessionFromMap()
    private func rebuildSessions() {
        // Rebuild the persistent sessionMap from scratch
        var newSessionMap: [String: [Trace]] = [:]
        for trace in recentTraces {
            let convId = trace.spans.compactMap({ $0.conversationId }).first ?? trace.id
            newSessionMap[convId, default: []].append(trace)
        }
        sessionMap = newSessionMap

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
        FreezeDebugger.logStateChange("telemetry.isLoading", old: isLoading, new: true)
        isLoading = true
        FreezeDebugger.logStateChange("telemetry.error", old: error, new: nil as String?)
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
            // Populate persistent sessionMap for incremental updates during realtime
            var newSessionMap: [String: [Trace]] = [:]
            for trace in recentTraces {
                // Get conversation_id from any span in the trace
                let convId = trace.spans.compactMap({ $0.conversationId }).first ?? trace.id
                newSessionMap[convId, default: []].append(trace)
            }
            sessionMap = newSessionMap

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
            let errMsg = error.localizedDescription
            FreezeDebugger.logStateChange("telemetry.error", old: self.error, new: errMsg)
            self.error = errMsg
            FreezeDebugger.asyncError("TelemetryService.fetchRecentTraces", error: error)
        }

        FreezeDebugger.logStateChange("telemetry.isLoading", old: isLoading, new: false)
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
            let traceCount = recentTraces.count

            // Move heavy array operations to background thread
            let computedStats = await Task.detached { @Sendable () -> TelemetryStats in
                let totalSpans = response.count
                let errors = response.filter { $0.isError }.count
                let durations = response.compactMap { $0.durationMs }.sorted()

                let avgDuration = durations.isEmpty ? nil : Double(durations.reduce(0, +)) / Double(durations.count)
                let p50 = durations.isEmpty ? nil : Double(durations[durations.count / 2])
                let p95 = durations.isEmpty ? nil : Double(durations[Int(Double(durations.count) * 0.95)])
                let p99 = durations.isEmpty ? nil : Double(durations[Int(Double(durations.count) * 0.99)])

                return TelemetryStats(
                    totalTraces: traceCount,
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
            }.value

            stats = computedStats

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
