import Foundation
import SwiftUI
import Supabase
import Realtime

// MARK: - Workflow Telemetry Service
// Fetches and subscribes to audit_log spans for a single workflow run via traceId.
// Provides real-time waterfall data, step-grouped spans, and aggregated metrics.

@MainActor
@Observable
class WorkflowTelemetryService {

    // MARK: - Published State

    var traces: [Trace] = []
    var allSpans: [TelemetrySpan] = []
    var spansByStep: [String: [TelemetrySpan]] = [:]
    var isLive = false
    var selectedSpan: TelemetrySpan?
    var spanComparison: SpanComparison?

    // Aggregates (computed from allSpans)
    var totalTokens: Int { allSpans.reduce(0) { $0 + ($1.inputTokens ?? 0) + ($1.outputTokens ?? 0) } }
    var totalCost: Double { allSpans.compactMap(\.cost).reduce(0, +) }
    var errorCount: Int { allSpans.filter(\.isError).count }
    var spanCount: Int { allSpans.count }

    // MARK: - Private

    private var traceId: String?
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var stepRuns: [StepRun] = []

    // MARK: - Lifecycle

    /// Start tracking telemetry for a workflow run.
    /// Fetches existing spans, then subscribes to Realtime for live updates.
    func startTracking(traceId: String, stepRuns: [StepRun] = []) {
        guard self.traceId != traceId else { return }
        stopTracking()

        self.traceId = traceId
        self.stepRuns = stepRuns

        Task { @MainActor in
            // 1. Bulk-fetch existing spans
            await fetchExistingSpans(traceId: traceId)

            // 2. Start Realtime subscription with polling fallback
            startRealtime(traceId: traceId)
        }
    }

    /// Update step runs (called when WorkflowRunPanel refreshes)
    func updateStepRuns(_ runs: [StepRun]) {
        stepRuns = runs
        rebuildStepMapping()
    }

    /// Stop tracking — unsubscribe and clean up
    func stopTracking() {
        traceId = nil
        realtimeTask?.cancel()
        realtimeTask = nil
        pollTask?.cancel()
        pollTask = nil

        if let channel = realtimeChannel {
            let ch = channel
            realtimeChannel = nil
            Task.detached { await ch.unsubscribe() }
        }
        isLive = false
    }

    /// Fetch span comparison data for the selected span
    func fetchSpanComparison(spanId: UUID) async {
        do {
            let supabase = SupabaseService.shared.adminClient
            struct Params: Encodable { let p_span_id: String }

            let response = try await supabase.rpc(
                "get_tool_trace_detail",
                params: Params(p_span_id: spanId.uuidString)
            ).execute()

            struct DetailResponse: Codable { let comparison: SpanComparison }
            spanComparison = try JSONDecoder().decode(DetailResponse.self, from: response.data).comparison
        } catch {
            spanComparison = nil
        }
    }

    // MARK: - Data Fetching

    private func fetchExistingSpans(traceId: String) async {
        do {
            let supabase = SupabaseService.shared.adminClient

            let response: [TelemetrySpan] = try await supabase
                .from("audit_logs")
                .select()
                .eq("request_id", value: traceId)
                .order("created_at", ascending: true)
                .limit(500)
                .execute()
                .value

            allSpans = response
            rebuildTraces()
            rebuildStepMapping()
        } catch {
            #if DEBUG
            print("[WFTelemetry] Fetch error: \(error)")
            #endif
        }
    }

    // MARK: - Realtime Subscription

    private func startRealtime(traceId: String) {
        realtimeTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let client = SupabaseService.shared.client
            let channel = client.realtimeV2.channel("wf-trace-\(traceId.prefix(8))")
            self.realtimeChannel = channel

            let inserts = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "audit_logs"
            )

            do {
                try await channel.subscribeWithError()
                self.isLive = true

                // Cancel polling fallback since Realtime connected
                self.pollTask?.cancel()
                self.pollTask = nil

                for await insert in inserts {
                    self.handleInsert(insert, traceId: traceId)
                }

                self.isLive = false
            } catch {
                #if DEBUG
                print("[WFTelemetry] Realtime error: \(error), falling back to polling")
                #endif
                self.isLive = false
                self.startPolling(traceId: traceId)
            }
        }

        // Start polling fallback — cancelled if Realtime connects within 3s
        pollTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, !self.isLive else { return }
            self.startPolling(traceId: traceId)
        }
    }

    private func startPolling(traceId: String) {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { break }
                await self.fetchExistingSpans(traceId: traceId)
            }
        }
    }

    private func handleInsert(_ insert: InsertAction, traceId: String) {
        let record = insert.record

        // Client-side filter: only spans for our trace
        guard let reqId = record["request_id"]?.stringValue, reqId == traceId else { return }

        do {
            let jsonData = try JSONEncoder().encode(record)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let span = try decoder.decode(TelemetrySpan.self, from: jsonData)

            // Avoid duplicates
            guard !allSpans.contains(where: { $0.id == span.id }) else { return }

            allSpans.append(span)
            allSpans.sort { $0.createdAt < $1.createdAt }
            rebuildTraces()
            rebuildStepMapping()
        } catch {
            #if DEBUG
            print("[WFTelemetry] Decode error: \(error)")
            #endif
        }
    }

    // MARK: - Trace & Step Mapping

    private func rebuildTraces() {
        // Group spans by conversation_id to form traces
        var traceMap: [String: [TelemetrySpan]] = [:]
        for span in allSpans {
            let tId = span.requestId ?? span.id.uuidString
            traceMap[tId, default: []].append(span)
        }

        traces = traceMap.map { (reqId, spans) in
            let sorted = spans.sorted { $0.createdAt < $1.createdAt }
            return Trace(
                id: reqId,
                spans: sorted,
                rootSpan: sorted.first { $0.parentId == nil },
                startTime: sorted.first?.createdAt ?? Date(),
                endTime: sorted.last?.createdAt
            )
        }.sorted { $0.startTime < $1.startTime }
    }

    private func rebuildStepMapping() {
        var mapping: [String: [TelemetrySpan]] = [:]

        for span in allSpans {
            // Strategy 1: Check span details for step_key
            if let stepKey = span.details?["step_key"]?.stringValue {
                mapping[stepKey, default: []].append(span)
                continue
            }

            // Strategy 2: Correlate by timestamp windows with step runs
            if !stepRuns.isEmpty {
                if let matchedStep = matchSpanToStep(span) {
                    mapping[matchedStep, default: []].append(span)
                    continue
                }
            }

            // Strategy 3: Unmatched spans go under "_unassigned"
            mapping["_unassigned", default: []].append(span)
        }

        spansByStep = mapping
    }

    /// Match a span to a step run by checking if the span's timestamp falls within the step's execution window
    private func matchSpanToStep(_ span: TelemetrySpan) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()

        for step in stepRuns {
            guard let startStr = step.startedAt,
                  let startDate = formatter.date(from: startStr) ?? fallback.date(from: startStr) else { continue }

            // Use completedAt if available, otherwise extend window by duration or use a generous buffer
            let endDate: Date
            if let endStr = step.completedAt,
               let end = formatter.date(from: endStr) ?? fallback.date(from: endStr) {
                endDate = end.addingTimeInterval(0.5) // 500ms buffer
            } else if let durationMs = step.durationMs {
                endDate = startDate.addingTimeInterval(Double(durationMs) / 1000.0 + 0.5)
            } else {
                // Step still running — use current time as end bound
                endDate = Date()
            }

            if span.createdAt >= startDate.addingTimeInterval(-0.5) && span.createdAt <= endDate {
                return step.stepKey
            }
        }
        return nil
    }

    // MARK: - Convenience

    /// Spans for a specific step, sorted by time
    func spans(for stepKey: String) -> [TelemetrySpan] {
        spansByStep[stepKey]?.sorted { $0.createdAt < $1.createdAt } ?? []
    }

    /// Token count for a specific step
    func tokenCount(for stepKey: String) -> Int {
        spans(for: stepKey).reduce(0) { $0 + ($1.inputTokens ?? 0) + ($1.outputTokens ?? 0) }
    }

    /// Cost for a specific step
    func cost(for stepKey: String) -> Double {
        spans(for: stepKey).compactMap(\.cost).reduce(0, +)
    }

    /// Currently executing tool for a step (latest running tool.* span)
    func activeTool(for stepKey: String) -> String? {
        spans(for: stepKey)
            .last { $0.isToolSpan && $0.durationMs == nil }?
            .toolName
    }

    /// The earliest span time across all spans (for waterfall rendering)
    var waterfallStart: Date {
        allSpans.first?.createdAt ?? Date()
    }

    /// Total duration from first to last span
    var waterfallDuration: TimeInterval {
        guard let first = allSpans.first?.createdAt,
              let last = allSpans.last?.createdAt else { return 1 }
        return max(last.timeIntervalSince(first), 0.001)
    }
}
