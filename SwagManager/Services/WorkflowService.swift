import Foundation
import SwiftUI

// MARK: - Workflow Service
// API client for workflow CRUD via Fly.io server (whale-agent.fly.dev)
// Pattern: POST /chat with mode:"tool", tool_name:"workflows"

@MainActor
@Observable
class WorkflowService {
    static let shared = WorkflowService()

    // MARK: - State

    var workflows: [Workflow] = []
    var selectedWorkflow: Workflow?
    var currentGraph: WorkflowGraph?
    var currentRuns: [WorkflowRun] = []
    var isLoading = false
    var error: String?

    private var serverURL: URL { SupabaseConfig.agentServerURL }
    private var authToken: String { SupabaseConfig.serviceRoleKey }

    private init() {}

    // MARK: - Workflow CRUD

    func listWorkflows(storeId: UUID?) async {
        isLoading = true
        defer { isLoading = false }

        let result = await callTool(action: "list", args: [:], storeId: storeId)
        if let items = result as? [[String: Any]] {
            workflows = items.compactMap { decodeWorkflow($0) }
        } else if let wrapper = result as? [String: Any], let items = wrapper["workflows"] as? [[String: Any]] {
            workflows = items.compactMap { decodeWorkflow($0) }
        }
    }

    func getWorkflow(id: String, storeId: UUID?) async -> Workflow? {
        let result = await callTool(action: "get", args: ["workflow_id": id], storeId: storeId)
        if let dict = result as? [String: Any] {
            return decodeWorkflow(dict)
        }
        return nil
    }

    func createWorkflow(name: String, description: String?, triggerType: String, storeId: UUID?) async -> Workflow? {
        var args: [String: Any] = ["name": name, "trigger_type": triggerType]
        if let desc = description { args["description"] = desc }

        let result = await callTool(action: "create", args: args, storeId: storeId)
        if let dict = result as? [String: Any] {
            let wf = decodeWorkflow(dict)
            if let wf { workflows.insert(wf, at: 0) }
            return wf
        }
        return nil
    }

    func updateWorkflow(id: String, updates: [String: Any], storeId: UUID?) async -> Workflow? {
        var args = updates
        args["workflow_id"] = id

        let result = await callTool(action: "update", args: args, storeId: storeId)
        if let dict = result as? [String: Any] {
            let updated = decodeWorkflow(dict)
            if let updated, let idx = workflows.firstIndex(where: { $0.id == id }) {
                workflows[idx] = updated
            }
            return updated
        }
        return nil
    }

    func deleteWorkflow(id: String, storeId: UUID?) async -> Bool {
        let result = await callTool(action: "delete", args: ["workflow_id": id], storeId: storeId)
        if result != nil {
            workflows.removeAll { $0.id == id }
            if selectedWorkflow?.id == id { selectedWorkflow = nil }
            return true
        }
        return false
    }

    // MARK: - Step Management

    func addStep(workflowId: String, stepKey: String, stepType: String, config: [String: Any], positionX: Double?, positionY: Double?, storeId: UUID?) async -> WorkflowStep? {
        var args: [String: Any] = [
            "workflow_id": workflowId,
            "step_key": stepKey,
            "step_type": stepType,
            "step_config": config
        ]
        if let x = positionX { args["position_x"] = x }
        if let y = positionY { args["position_y"] = y }

        let result = await callTool(action: "add_step", args: args, storeId: storeId)
        if let dict = result as? [String: Any] {
            return decodeStep(dict)
        }
        return nil
    }

    func updateStep(stepId: String, updates: [String: Any], storeId: UUID?) async -> Bool {
        var args = updates
        args["step_id"] = stepId

        let result = await callTool(action: "update_step", args: args, storeId: storeId)
        return result != nil
    }

    func deleteStep(stepId: String, storeId: UUID?) async -> Bool {
        let result = await callTool(action: "delete_step", args: ["step_id": stepId], storeId: storeId)
        return result != nil
    }

    // MARK: - Graph

    func getGraph(workflowId: String, runId: String? = nil, storeId: UUID?) async -> WorkflowGraph? {
        var args: [String: Any] = ["workflow_id": workflowId]
        if let runId { args["run_id"] = runId }

        let result = await callTool(action: "graph", args: args, storeId: storeId)
        if let dict = result as? [String: Any] {
            let graph = decodeGraph(dict)
            currentGraph = graph
            return graph
        }
        return nil
    }

    // MARK: - Run Control

    func startRun(workflowId: String, triggerPayload: [String: Any]? = nil, storeId: UUID?) async -> WorkflowRun? {
        var args: [String: Any] = ["workflow_id": workflowId]
        if let payload = triggerPayload { args["trigger_payload"] = payload }
        args["idempotency_key"] = UUID().uuidString

        let result = await callTool(action: "start", args: args, storeId: storeId)
        if let dict = result as? [String: Any] {
            return decodeRun(dict)
        }
        return nil
    }

    func pauseRun(runId: String, storeId: UUID?) async -> Bool {
        await callTool(action: "pause", args: ["run_id": runId], storeId: storeId) != nil
    }

    func resumeRun(runId: String, storeId: UUID?) async -> Bool {
        await callTool(action: "resume", args: ["run_id": runId], storeId: storeId) != nil
    }

    func cancelRun(runId: String, storeId: UUID?) async -> Bool {
        await callTool(action: "cancel", args: ["run_id": runId], storeId: storeId) != nil
    }

    func getRuns(workflowId: String?, status: String? = nil, limit: Int = 20, storeId: UUID?) async -> [WorkflowRun] {
        var args: [String: Any] = ["limit": limit]
        if let wid = workflowId { args["workflow_id"] = wid }
        if let s = status { args["status"] = s }

        let result = await callTool(action: "runs", args: args, storeId: storeId)
        if let items = result as? [[String: Any]] {
            let runs = items.compactMap { decodeRun($0) }
            currentRuns = runs
            return runs
        } else if let wrapper = result as? [String: Any], let items = wrapper["runs"] as? [[String: Any]] {
            let runs = items.compactMap { decodeRun($0) }
            currentRuns = runs
            return runs
        }
        return []
    }

    func getStepRuns(runId: String, storeId: UUID?) async -> [StepRun] {
        let result = await callTool(action: "step_runs", args: ["run_id": runId], storeId: storeId)
        if let items = result as? [[String: Any]] {
            return items.compactMap { decodeStepRun($0) }
        } else if let wrapper = result as? [String: Any], let items = wrapper["step_runs"] as? [[String: Any]] {
            return items.compactMap { decodeStepRun($0) }
        }
        return []
    }

    // MARK: - Templates

    func listTemplates(storeId: UUID?) async -> [Workflow] {
        let result = await callTool(action: "list_templates", args: [:], storeId: storeId)
        if let items = result as? [[String: Any]] {
            return items.compactMap { decodeWorkflow($0) }
        } else if let wrapper = result as? [String: Any], let items = wrapper["templates"] as? [[String: Any]] {
            return items.compactMap { decodeWorkflow($0) }
        }
        return []
    }

    func cloneTemplate(templateId: String, name: String, storeId: UUID?) async -> Workflow? {
        let result = await callTool(action: "clone_template", args: ["template_id": templateId, "name": name], storeId: storeId)
        if let dict = result as? [String: Any] {
            return decodeWorkflow(dict)
        }
        return nil
    }

    // MARK: - Publishing

    func publish(workflowId: String, changelog: String?, storeId: UUID?) async -> Bool {
        var args: [String: Any] = ["workflow_id": workflowId]
        if let log = changelog { args["changelog"] = log }
        return await callTool(action: "publish", args: args, storeId: storeId) != nil
    }

    func getVersions(workflowId: String, storeId: UUID?) async -> [WorkflowVersion] {
        let result = await callTool(action: "versions", args: ["workflow_id": workflowId], storeId: storeId)
        if let items = result as? [[String: Any]] {
            return items.compactMap { decodeVersion($0) }
        }
        return []
    }

    // MARK: - Approvals

    func respondToApproval(approvalId: String, status: String, responseData: [String: Any]?, storeId: UUID?) async -> Bool {
        var args: [String: Any] = ["approval_id": approvalId, "status": status]
        if let data = responseData { args["response_data"] = data }
        return await callTool(action: "respond_approval", args: args, storeId: storeId) != nil
    }

    func listApprovals(status: String? = nil, storeId: UUID?) async -> [ApprovalRequest] {
        var args: [String: Any] = [:]
        if let s = status { args["status"] = s }
        let result = await callTool(action: "list_approvals", args: args, storeId: storeId)
        if let items = result as? [[String: Any]] {
            return items.compactMap { decodeApproval($0) }
        }
        return []
    }

    // MARK: - DLQ

    func getDLQ(status: String? = nil, storeId: UUID?) async -> [DLQEntry] {
        var args: [String: Any] = [:]
        if let s = status { args["status"] = s }
        let result = await callTool(action: "dlq", args: args, storeId: storeId)
        if let items = result as? [[String: Any]] {
            return items.compactMap { decodeDLQ($0) }
        }
        return []
    }

    func retryDLQ(dlqId: String, storeId: UUID?) async -> Bool {
        await callTool(action: "dlq_retry", args: ["dlq_id": dlqId], storeId: storeId) != nil
    }

    func dismissDLQ(dlqId: String, storeId: UUID?) async -> Bool {
        await callTool(action: "dlq_dismiss", args: ["dlq_id": dlqId], storeId: storeId) != nil
    }

    // MARK: - Metrics

    func getMetrics(days: Int = 30, storeId: UUID?) async -> WorkflowMetrics? {
        let result = await callTool(action: "metrics", args: ["days": days], storeId: storeId)
        if let dict = result as? [String: Any] {
            return decodeMetrics(dict)
        }
        return nil
    }

    // MARK: - Schedule

    func setSchedule(workflowId: String, cronExpression: String?, storeId: UUID?) async -> Bool {
        var args: [String: Any] = ["workflow_id": workflowId]
        if let cron = cronExpression { args["cron_expression"] = cron }
        return await callTool(action: "set_schedule", args: args, storeId: storeId) != nil
    }

    // MARK: - SSE Streaming

    func streamRun(runId: String) -> AsyncStream<WorkflowSSEEvent> {
        AsyncStream { continuation in
            let task = Task {
                let url = serverURL.appendingPathComponent("workflows/runs/\(runId)/stream")
                var request = URLRequest(url: url)
                request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.finish()
                        return
                    }

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }

                        // Skip heartbeat comments
                        if line.hasPrefix(":") { continue }

                        guard line.hasPrefix("data: "),
                              let jsonData = String(line.dropFirst(6)).data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                            continue
                        }

                        if let event = WorkflowSSEEvent.parse(json: json) {
                            continuation.yield(event)
                        }
                    }
                } catch {
                    if !Task.isCancelled {
                        print("[WorkflowService] SSE error: \(error.localizedDescription)")
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Core API Call

    @discardableResult
    private func callTool(action: String, args: [String: Any], storeId: UUID?) async -> Any? {
        var fullArgs = args
        fullArgs["action"] = action
        if let storeId { fullArgs["store_id"] = storeId.uuidString }

        var body: [String: Any] = [
            "mode": "tool",
            "tool_name": "workflows",
            "args": fullArgs,
        ]
        if let storeId { body["store_id"] = storeId.uuidString }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            self.error = "Failed to encode request"
            return nil
        }

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                self.error = "Server error \(statusCode)"
                return nil
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                if success {
                    self.error = nil
                    return json["data"]
                } else {
                    self.error = json["error"] as? String ?? "Unknown error"
                    return nil
                }
            }
            return nil
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    // MARK: - Decoders

    private func decodeWorkflow(_ dict: [String: Any]) -> Workflow? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String else { return nil }
        return Workflow(
            id: id,
            name: name,
            description: dict["description"] as? String,
            icon: dict["icon"] as? String,
            status: dict["status"] as? String ?? "draft",
            isActive: dict["is_active"] as? Bool ?? false,
            triggerType: dict["trigger_type"] as? String ?? "manual",
            maxConcurrentRuns: dict["max_concurrent_runs"] as? Int,
            maxRunDurationSeconds: dict["max_run_duration_seconds"] as? Int,
            cronExpression: dict["cron_expression"] as? String,
            nextRunAt: dict["next_run_at"] as? String,
            lastRunAt: dict["last_run_at"] as? String,
            runCount: dict["run_count"] as? Int,
            storeId: dict["store_id"] as? String,
            createdAt: dict["created_at"] as? String ?? "",
            updatedAt: dict["updated_at"] as? String
        )
    }

    private func decodeStep(_ dict: [String: Any]) -> WorkflowStep? {
        guard let id = dict["id"] as? String else { return nil }
        var configMap: [String: AnyCodable]?
        if let config = dict["step_config"] as? [String: Any] {
            configMap = config.mapValues { AnyCodable($0) }
        }
        return WorkflowStep(
            id: id,
            workflowId: dict["workflow_id"] as? String ?? "",
            stepKey: dict["step_key"] as? String ?? "",
            stepType: dict["step_type"] as? String ?? "noop",
            isEntryPoint: dict["is_entry_point"] as? Bool ?? false,
            onSuccess: dict["on_success"] as? String,
            onFailure: dict["on_failure"] as? String,
            stepConfig: configMap,
            timeoutSeconds: dict["timeout_seconds"] as? Int ?? 30,
            maxRetries: dict["max_retries"] as? Int ?? 0,
            positionX: dict["position_x"] as? Double,
            positionY: dict["position_y"] as? Double
        )
    }

    private func decodeGraph(_ dict: [String: Any]) -> WorkflowGraph? {
        guard let nodesArr = dict["nodes"] as? [[String: Any]],
              let edgesArr = dict["edges"] as? [[String: Any]] else { return nil }

        let nodes = nodesArr.compactMap { n -> GraphNode? in
            guard let id = n["id"] as? String else { return nil }
            var pos: GraphPosition?
            if let p = n["position"] as? [String: Any], let x = p["x"] as? Double, let y = p["y"] as? Double {
                pos = GraphPosition(x: x, y: y)
            }
            var summary: GraphConfigSummary?
            if let s = n["config_summary"] as? [String: Any] {
                summary = GraphConfigSummary(
                    toolName: s["tool_name"] as? String,
                    action: s["action"] as? String,
                    expression: s["expression"] as? String
                )
            }
            return GraphNode(
                id: id,
                type: n["type"] as? String ?? "noop",
                label: n["label"] as? String ?? id,
                isEntryPoint: n["is_entry_point"] as? Bool ?? false,
                position: pos,
                configSummary: summary
            )
        }

        let edges = edgesArr.compactMap { e -> GraphEdge? in
            guard let from = e["from"] as? String, let to = e["to"] as? String else { return nil }
            return GraphEdge(from: from, to: to, type: e["type"] as? String ?? "success")
        }

        var nodeStatus: [String: NodeStatus]?
        if let ns = dict["node_status"] as? [String: [String: Any]] {
            nodeStatus = ns.mapValues { s in
                NodeStatus(
                    status: s["status"] as? String ?? "pending",
                    durationMs: s["duration_ms"] as? Int,
                    error: s["error"] as? String,
                    startedAt: s["started_at"] as? String
                )
            }
        }

        return WorkflowGraph(nodes: nodes, edges: edges, nodeStatus: nodeStatus)
    }

    private func decodeRun(_ dict: [String: Any]) -> WorkflowRun? {
        guard let id = dict["id"] as? String else { return nil }
        return WorkflowRun(
            id: id,
            workflowId: dict["workflow_id"] as? String ?? "",
            status: dict["status"] as? String ?? "unknown",
            triggerType: dict["trigger_type"] as? String,
            triggerPayload: nil,
            startedAt: dict["started_at"] as? String,
            completedAt: dict["completed_at"] as? String,
            error: dict["error"] as? String,
            traceId: dict["trace_id"] as? String
        )
    }

    private func decodeStepRun(_ dict: [String: Any]) -> StepRun? {
        guard let id = dict["id"] as? String else { return nil }
        return StepRun(
            id: id,
            runId: dict["run_id"] as? String ?? "",
            stepKey: dict["step_key"] as? String ?? "",
            stepType: dict["step_type"] as? String ?? "",
            status: dict["status"] as? String ?? "",
            input: nil,
            output: nil,
            error: dict["error"] as? String,
            durationMs: dict["duration_ms"] as? Int,
            startedAt: dict["started_at"] as? String,
            completedAt: dict["completed_at"] as? String,
            retryCount: dict["retry_count"] as? Int
        )
    }

    private func decodeVersion(_ dict: [String: Any]) -> WorkflowVersion? {
        guard let id = dict["id"] as? String else { return nil }
        return WorkflowVersion(
            id: id,
            workflowId: dict["workflow_id"] as? String ?? "",
            version: dict["version"] as? Int ?? 0,
            changelog: dict["changelog"] as? String,
            publishedAt: dict["published_at"] as? String ?? "",
            publishedBy: dict["published_by"] as? String
        )
    }

    private func decodeApproval(_ dict: [String: Any]) -> ApprovalRequest? {
        guard let id = dict["id"] as? String else { return nil }
        return ApprovalRequest(
            id: id,
            runId: dict["run_id"] as? String ?? "",
            stepKey: dict["step_key"] as? String ?? "",
            title: dict["title"] as? String,
            description: dict["description"] as? String,
            options: dict["options"] as? [String],
            status: dict["status"] as? String ?? "pending",
            respondedBy: dict["responded_by"] as? String,
            responseData: nil,
            expiresAt: dict["expires_at"] as? String,
            createdAt: dict["created_at"] as? String ?? ""
        )
    }

    private func decodeDLQ(_ dict: [String: Any]) -> DLQEntry? {
        guard let id = dict["id"] as? String else { return nil }
        return DLQEntry(
            id: id,
            runId: dict["run_id"] as? String ?? "",
            stepKey: dict["step_key"] as? String ?? "",
            error: dict["error"] as? String ?? "",
            status: dict["status"] as? String ?? "pending",
            retryCount: dict["retry_count"] as? Int,
            createdAt: dict["created_at"] as? String ?? ""
        )
    }

    private func decodeMetrics(_ dict: [String: Any]) -> WorkflowMetrics? {
        WorkflowMetrics(
            totalRuns: dict["total_runs"] as? Int,
            successRate: dict["success_rate"] as? Double,
            avgDurationMs: dict["avg_duration_ms"] as? Double,
            p50Ms: dict["p50_ms"] as? Double,
            p95Ms: dict["p95_ms"] as? Double,
            p99Ms: dict["p99_ms"] as? Double,
            dlqCount: dict["dlq_count"] as? Int,
            topErrors: nil,
            stepStats: nil
        )
    }
}

// MARK: - Environment Key

private struct WorkflowServiceKey: EnvironmentKey {
    static let defaultValue = WorkflowService.shared
}

extension EnvironmentValues {
    var workflowService: WorkflowService {
        get { self[WorkflowServiceKey.self] }
        set { self[WorkflowServiceKey.self] = newValue }
    }
}
