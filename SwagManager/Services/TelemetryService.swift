import Foundation
import SwiftUI
import Supabase
import Realtime

// MARK: - Telemetry Service

@MainActor
@Observable
class TelemetryService {
    static let shared = TelemetryService()

    var recentTraces: [Trace] = []
    var recentSessions: [TelemetrySession] = []
    var currentTrace: Trace?
    var stats: TelemetryStats?
    var isLoading = false
    var error: String?
    var isLive = false  // Realtime connection status
    var updateCount = 0  // Incremented on realtime updates to trigger UI refresh

    // Filter state
    var sourceFilter: String?
    var agentFilter: String?  // Filter by agent name
    var onlyErrors: Bool = false
    var timeRange: TimeRange = .lastHour

    // Available agents (populated from store's configured agents + traces)
    var availableAgents: [String] = []

    // Configured agents for the store (fetched from ai_agents table)
    private var configuredAgents: [String] = []

    // Realtime
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var currentStoreId: UUID?

    // Persistent session map: conversationId -> [Trace]
    // Maintained incrementally on realtime inserts to avoid O(n*m) rebuilds
    private var sessionMap: [String: [Trace]] = [:]

    // Persistent parent-child map: childConversationId -> parentConversationId
    // Survives across rebuilds — once we learn a relationship, we never forget it
    private var parentChildMap: [String: String] = [:]

    // Track which team sessions have been auto-expanded (to avoid re-expanding collapsed ones)
    private var autoExpandedTeamIds: Set<String> = []

    // Memory limits
    private static let maxSessions = 200
    private static let maxParentChildEntries = 500

    // Service-managed lifecycle (independent of SwiftUI task cancellation)
    private var configuredStoreId: UUID?
    private var loadTask: Task<Void, Never>?
    // Track which conversation IDs we've already queried for parent links
    private var parentLookupInFlight: Set<String> = []

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

    private init() {
        #if DEBUG
        diagLog("TelemetryService.init() — waiting for configure()")
        #endif
    }

    #if DEBUG
    /// Log diagnostic info via NSLog (visible in Console.app and `log show`)
    private func diagLog(_ message: String) {
        NSLog("[TelDiag] %@", message)
    }
    #endif

    // MARK: - Service Lifecycle

    /// Configure the service for a store — loads data and starts realtime.
    /// Idempotent: skips if already loaded/loading for same store.
    /// Survives SwiftUI view lifecycle (standalone task, not child of .task modifier).
    func configure(storeId: UUID?) {
        // Skip if already loading or loaded for this store
        if configuredStoreId == storeId && loadTask != nil {
            #if DEBUG
            diagLog("configure: SKIP (already configured for \(storeId?.uuidString.prefix(8) ?? "nil"))")
            #endif
            return
        }

        #if DEBUG
        diagLog("configure: START for storeId=\(storeId?.uuidString.prefix(8) ?? "nil")")
        #endif

        configuredStoreId = storeId
        loadTask?.cancel()
        stopRealtime()

        // Start load in a standalone task (not cancelled by SwiftUI lifecycle)
        loadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            #if DEBUG
            self.diagLog("configure task: fetching agents...")
            #endif
            await self.fetchConfiguredAgents(storeId: storeId)
            #if DEBUG
            self.diagLog("configure task: fetching traces...")
            #endif
            await self.fetchRecentTraces(storeId: storeId)
            #if DEBUG
            self.diagLog("configure task: starting realtime...")
            #endif
            self.startRealtime(storeId: storeId)
            #if DEBUG
            self.diagLog("configure task: DONE. sessions=\(self.recentSessions.count)")
            #endif
        }
    }

    // MARK: - Realtime Subscription

    /// Start realtime subscription for instant log updates
    func startRealtime(storeId: UUID?) {
        // Don't restart if already running
        if realtimeTask != nil && isLive { return }

        stopRealtime()
        currentStoreId = storeId

        realtimeTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            #if DEBUG
            print("[Telemetry] Starting realtime subscription...")
            #endif

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
                self.isLive = true

                for await insert in inserts {
                    self.handleNewSpan(insert)
                }

                // If we reach here, the async sequence ended (Realtime disconnected)
                #if DEBUG
                print("[Telemetry] Realtime stream ended — sequence completed")
                #endif
                self.isLive = false
            } catch {
                #if DEBUG
                print("[Telemetry] Realtime error: \(error)")
                #endif
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
        self.isLive = false
    }

    /// Handle new span from realtime — runs synchronously on main actor
    /// (JSON work for a single record is microseconds, no need for Task.detached)
    private func handleNewSpan(_ insert: InsertAction) {
        let record = insert.record

        // 1. Filter: only AI telemetry actions
        guard let action = record["action"]?.stringValue,
              (action.hasPrefix("tool.") || action == "claude_api_request" || action.hasPrefix("chat.") || action.hasPrefix("subagent.") || action.hasPrefix("team.")) else {
            return
        }

        // 2. Filter by store
        if let storeId = currentStoreId {
            if let spanStoreId = record["store_id"]?.stringValue,
               spanStoreId.lowercased() != storeId.uuidString.lowercased() {
                return
            }
        }

        // 3. Extract conversation IDs directly from AnyJSON
        let conversationId = record["conversation_id"]?.stringValue
        var parentConversationId: String?

        if let details = record["details"] {
            // Path A: JSONB delivered as AnyJSON .object
            if let obj = details.objectValue {
                parentConversationId = obj["parent_conversation_id"]?.stringValue
            }

            // Path B: JSONB delivered as serialized JSON string
            if parentConversationId == nil, let str = details.stringValue,
               let data = str.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                parentConversationId = dict["parent_conversation_id"] as? String
            }

            // Path C: Encode AnyJSON to JSON bytes, parse with Foundation
            if parentConversationId == nil,
               let encoded = try? JSONEncoder().encode(details),
               let dict = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any] {
                parentConversationId = dict["parent_conversation_id"] as? String
                #if DEBUG
                if parentConversationId != nil {
                    print("[RT-FIX] Path C found parent for \(action) (A/B missed it)")
                }
                #endif
            }
        }

        #if DEBUG
        print("[RT] \(action) | conv=\(conversationId?.prefix(15) ?? "nil") | parent=\(parentConversationId?.prefix(15) ?? "nil")")
        #endif

        // 4. Store parent-child link BEFORE decoding span
        if let convId = conversationId, let parentId = parentConversationId, !parentId.isEmpty {
            parentChildMap[convId] = parentId
        }

        // 5. Decode full TelemetrySpan and insert
        do {
            let jsonData = try JSONEncoder().encode(record)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let span = try decoder.decode(TelemetrySpan.self, from: jsonData)
            insertSpanIntoTraces(span)
        } catch {
            #if DEBUG
            print("[Telemetry] Decode error for \(action): \(error)")
            #endif
        }

        // 6. If parent unknown for this conversation, query DB (Realtime truncates large JSONB)
        if let convId = conversationId, parentConversationId == nil, parentChildMap[convId] == nil {
            lookupParentFromDB(conversationId: convId)
        }
    }

    /// Query DB for parent_conversation_id when Realtime payload was truncated.
    /// Runs once per unknown conversation_id, ~10ms indexed query.
    private func lookupParentFromDB(conversationId: String) {
        // Already queried or already known?
        guard !parentLookupInFlight.contains(conversationId),
              parentChildMap[conversationId] == nil else { return }
        parentLookupInFlight.insert(conversationId)

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let supabase = SupabaseService.shared.adminClient

                // Fetch one span from this conversation that has parent_conversation_id
                let response = try await supabase
                    .from("audit_logs")
                    .select("details")
                    .eq("conversation_id", value: conversationId)
                    .like("action", pattern: "team.%")
                    .limit(1)
                    .execute()

                // Parse raw JSON to extract parent_conversation_id reliably
                if let rows = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]],
                   let details = rows.first?["details"] as? [String: Any],
                   let parentId = details["parent_conversation_id"] as? String,
                   !parentId.isEmpty {
                    self.parentChildMap[conversationId] = parentId
                    #if DEBUG
                    print("[RT-DB] Found parent for \(conversationId.prefix(15)): \(parentId.prefix(15))")
                    #endif
                    self.rebuildSessions()
                }
            } catch {
                #if DEBUG
                print("[RT-DB] Lookup error for \(conversationId.prefix(15)): \(error)")
                #endif
            }
        }
    }

    /// Insert a new span into existing traces or create new trace
    private func insertSpanIntoTraces(_ span: TelemetrySpan) {
        let traceId = span.requestId ?? span.id.uuidString
        let conversationId = span.conversationId ?? traceId

        // Also extract parent link from decoded span's details (backup path)
        if let parentConvId = span.parentConversationId, !parentConvId.isEmpty {
            parentChildMap[conversationId] = parentConvId
        }

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
    /// Rebuilds the full tree to maintain parent-child relationships
    private func updateSessionFromMap(conversationId: String) {
        // Rebuild full tree to maintain parent-child relationships correctly
        rebuildSessions()
    }

    /// IDs of sessions that just became team coordinators (for UI auto-expand)
    var newTeamCoordinatorIds: Set<String> = []

    /// Full rebuild of sessions from current recentTraces
    /// Used on initial load AND realtime updates for proper tree linking
    private func rebuildSessions() {
        // Rebuild the persistent sessionMap from scratch
        var newSessionMap: [String: [Trace]] = [:]
        for trace in recentTraces {
            let convId = trace.spans.compactMap({ $0.conversationId }).first ?? trace.id
            newSessionMap[convId, default: []].append(trace)
        }
        sessionMap = newSessionMap

        // First pass: create all sessions
        var allSessions: [String: TelemetrySession] = [:]
        for (convId, sessionTraces) in sessionMap {
            let sorted = sessionTraces.sorted { $0.startTime < $1.startTime }
            allSessions[convId] = TelemetrySession(
                id: convId,
                traces: sorted,
                startTime: sorted.first?.startTime ?? Date(),
                endTime: sorted.last?.endTime
            )
        }

        // Build reverse lookup: parentId -> [childIds]
        // Source 1: Scan span details for parent_conversation_id
        var childrenByParent: [String: Set<String>] = [:]
        for (convId, session) in allSessions {
            // Check spans for parent_conversation_id
            if let parentId = session.parentConversationId, !parentId.isEmpty {
                childrenByParent[parentId, default: []].insert(convId)
                // Also persist in the durable map
                parentChildMap[convId] = parentId
            }
        }

        // Source 2: Persistent parent-child map (catches relationships from spans
        // whose details may not have decoded this time, e.g. realtime edge cases)
        for (childId, parentId) in parentChildMap {
            if allSessions[childId] != nil {
                childrenByParent[parentId, default: []].insert(childId)
            }
        }

        // Track which sessions are about to become team coordinators
        let previousCoordinatorIds = Set(recentSessions.filter { $0.isTeamCoordinator }.map { $0.id })

        // Link children to parents
        for (parentId, childIds) in childrenByParent {
            guard var parent = allSessions[parentId] else { continue }

            for childId in childIds {
                if let child = allSessions[childId] {
                    // Avoid duplicates
                    if !parent.childSessions.contains(where: { $0.id == childId }) {
                        parent.childSessions.append(child)
                    }
                }
            }
            parent.childSessions.sort { $0.startTime < $1.startTime }
            allSessions[parentId] = parent
        }

        // Build root sessions list (sessions without parents, or orphans)
        var rootSessions: [TelemetrySession] = []
        let allParentedIds = Set(childrenByParent.values.flatMap { $0 })

        for (convId, _) in allSessions {
            if allParentedIds.contains(convId) {
                // This session is a child — skip it from roots
                continue
            }
            // Re-fetch from allSessions to get the version with children attached
            if let session = allSessions[convId] {
                rootSessions.append(session)
            }
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            recentSessions = rootSessions.sorted { $0.startTime > $1.startTime }
        }

        #if DEBUG
        diagLog("rebuildSessions: \(allSessions.count) sessions, \(childrenByParent.count) parents with children, \(allParentedIds.count) child sessions, \(rootSessions.count) roots, parentChildMap=\(parentChildMap.count)")
        if !childrenByParent.isEmpty {
            for (parentId, childIds) in childrenByParent {
                let parentExists = allSessions[parentId] != nil
                let parentChildren = allSessions[parentId]?.childSessions.count ?? -1
                diagLog("  parent \(parentId.prefix(15))... (exists=\(parentExists), children=\(parentChildren)) -> \(childIds.count) children: \(childIds.map { String($0.prefix(10)) })")
            }
        } else {
            diagLog("  NO parent-child links found!")
            // Log all sessions for investigation
            for (convId, session) in allSessions.prefix(5) {
                let parentVal = session.parentConversationId ?? "nil"
                let spanCount = session.allSpans.count
                let teamSpans = session.allSpans.filter { $0.action.hasPrefix("team.") }
                diagLog("  session \(convId.prefix(15)): \(spanCount) spans, \(teamSpans.count) team spans, parentConvId=\(parentVal)")
                // Check raw parentConversationId extraction
                for span in teamSpans.prefix(2) {
                    let rawParent = span.details?["parent_conversation_id"]
                    diagLog("    span \(span.action): details[parent_conversation_id] raw=\(String(describing: rawParent)), .stringValue=\(rawParent?.stringValue ?? "nil")")
                }
            }
        }
        #endif

        // Prune memory if maps grow too large
        pruneMemoryIfNeeded()

        // Detect newly-created team coordinators for auto-expand
        let currentCoordinatorIds = Set(recentSessions.filter { $0.isTeamCoordinator }.map { $0.id })
        let justBecameCoordinators = currentCoordinatorIds.subtracting(previousCoordinatorIds)
        if !justBecameCoordinators.isEmpty {
            newTeamCoordinatorIds = justBecameCoordinators
        }
    }

    // MARK: - Memory Pruning

    /// Prune sessionMap and parentChildMap when they exceed limits
    private func pruneMemoryIfNeeded() {
        if sessionMap.count > Self.maxSessions {
            // Keep the most recent sessions by sorting keys by latest trace time
            let sorted = sessionMap.sorted { lhs, rhs in
                let lhsTime = lhs.value.last?.endTime ?? lhs.value.last?.startTime ?? .distantPast
                let rhsTime = rhs.value.last?.endTime ?? rhs.value.last?.startTime ?? .distantPast
                return lhsTime > rhsTime
            }
            let keysToKeep = Set(sorted.prefix(Self.maxSessions).map { $0.key })
            sessionMap = sessionMap.filter { keysToKeep.contains($0.key) }
        }

        if parentChildMap.count > Self.maxParentChildEntries {
            // Keep entries whose child or parent is still in sessionMap
            let activeIds = Set(sessionMap.keys)
            parentChildMap = parentChildMap.filter { activeIds.contains($0.key) || activeIds.contains($0.value) }
        }
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
            // Fetch tool.* actions, claude_api_request, chat.*, subagent.*, AND team.* for full AI telemetry
            var baseQuery = supabase
                .from("audit_logs")
                .select()
                .or("action.like.tool.%,action.eq.claude_api_request,action.like.chat.%,action.like.subagent.%,action.like.team.%")
                .gte("created_at", value: cutoffString)

            if let storeId = storeId {
                // Include both store-specific AND global (NULL store_id) telemetry (e.g., CLI chats)
                baseQuery = baseQuery.or("store_id.eq.\(storeId.uuidString),store_id.is.null")
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

            // Seed the persistent parent-child map from all fetched spans
            // This ensures relationships are known before tree building
            var seededCount = 0
            for span in response {
                if let convId = span.conversationId,
                   let parentConvId = span.parentConversationId,
                   !parentConvId.isEmpty {
                    parentChildMap[convId] = parentConvId
                    seededCount += 1
                }
            }

            #if DEBUG
            let teamSpans = response.filter { $0.action.hasPrefix("team.") }
            let spansWithParent = response.filter { $0.parentConversationId != nil }
            diagLog("REST fetch: \(response.count) spans, \(teamSpans.count) team.* spans, \(spansWithParent.count) with parentConvId")
            diagLog("Seeded \(seededCount) parent-child links, parentChildMap now has \(parentChildMap.count) entries")
            // Log first few team spans for debugging
            for span in teamSpans.prefix(5) {
                let detailKeys = span.details?.keys.sorted().joined(separator: ", ") ?? "nil"
                let parentVal = span.parentConversationId ?? "nil"
                let detailsNil = span.details == nil ? "YES" : "NO"
                diagLog("  team span: \(span.action) conv=\(span.conversationId?.prefix(15) ?? "nil") parent=\(parentVal) detailsNil=\(detailsNil) keys=[\(detailKeys)]")
            }
            #endif

            // Use shared tree-building logic (same code path as realtime)
            rebuildSessions()

            // Merge agents from traces with configured agents
            let allAgents = agentSet.union(Set(configuredAgents))
            availableAgents = allAgents.sorted()

        } catch is CancellationError {
            // Expected during view lifecycle — ignore silently
        } catch let urlError as URLError where urlError.code == .cancelled {
            // HTTP request cancelled by new configure() call — ignore
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
            #if DEBUG
            print("[Telemetry] Error fetching configured agents: \(error)")
            #endif
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
                // Include both store-specific AND global (NULL store_id) telemetry
                baseQuery = baseQuery.or("store_id.eq.\(storeId.uuidString),store_id.is.null")
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

            withAnimation(.easeInOut(duration: 0.3)) {
                stats = computedStats
            }

        } catch {
            self.error = "Stats error: \(error.localizedDescription)"
        }
    }

    // MARK: - Tool Analytics

    var toolAnalytics: ToolAnalyticsResponse?
    var toolTimeline: [ToolTimelineBucket] = []
    var selectedSpanComparison: SpanComparison?
    var isLoadingToolAnalytics = false

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
            self.error = "Tool analytics error: \(error.localizedDescription)"
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
            self.error = "Tool timeline error: \(error.localizedDescription)"
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
            self.error = "Span comparison error: \(error.localizedDescription)"
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

// MARK: - Environment Support

private struct TelemetryServiceKey: EnvironmentKey {
    static var defaultValue: TelemetryService {
        MainActor.assumeIsolated {
            TelemetryService.shared
        }
    }
}

extension EnvironmentValues {
    var telemetryService: TelemetryService {
        get { self[TelemetryServiceKey.self] }
        set { self[TelemetryServiceKey.self] = newValue }
    }
}
