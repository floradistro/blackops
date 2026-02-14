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
        // The server has no separate "graph" action — use "get" which returns workflow_steps embedded
        let result = await callTool(action: "get", args: ["workflow_id": workflowId], storeId: storeId)
        guard let dict = result as? [String: Any] else { return nil }

        // Try standard graph format first (nodes/edges)
        if let _ = dict["nodes"] as? [[String: Any]] {
            let graph = decodeGraph(dict)
            currentGraph = graph
            return graph
        }

        // Construct graph from workflow_steps
        guard let steps = dict["workflow_steps"] as? [[String: Any]] else { return nil }

        var nodes: [GraphNode] = []
        var edges: [GraphEdge] = []

        for step in steps {
            guard let stepKey = step["step_key"] as? String else { continue }

            var pos: GraphPosition?
            if let x = step["position_x"] as? Double, let y = step["position_y"] as? Double,
               !(x == 0 && y == 0) {
                pos = GraphPosition(x: x, y: y)
            }

            var stepConfig: [String: AnyCodable]?
            if let sc = step["step_config"] as? [String: Any] {
                stepConfig = sc.mapValues { AnyCodable($0) }
            }

            let node = GraphNode(
                id: stepKey,
                stepId: step["id"] as? String,
                type: step["step_type"] as? String ?? "noop",
                label: stepKey,
                isEntryPoint: step["is_entry_point"] as? Bool ?? false,
                position: pos,
                configSummary: nil,
                onSuccess: step["on_success"] as? String,
                onFailure: step["on_failure"] as? String,
                stepConfig: stepConfig,
                maxRetries: step["max_retries"] as? Int,
                timeoutSeconds: step["timeout_seconds"] as? Int
            )
            nodes.append(node)

            // Derive edges from on_success / on_failure
            if let target = step["on_success"] as? String, !target.isEmpty {
                edges.append(GraphEdge(from: stepKey, to: target, type: "success", label: nil))
            }
            if let target = step["on_failure"] as? String, !target.isEmpty {
                edges.append(GraphEdge(from: stepKey, to: target, type: "failure", label: nil))
            }
        }

        // Overlay run status if a runId was requested
        var nodeStatus: [String: NodeStatus]?
        if let runId {
            let stepRuns = await getStepRuns(runId: runId, storeId: storeId)
            if !stepRuns.isEmpty {
                var statuses: [String: NodeStatus] = [:]
                for sr in stepRuns {
                    statuses[sr.stepKey] = NodeStatus(
                        status: sr.status,
                        durationMs: sr.durationMs,
                        error: sr.error,
                        startedAt: sr.startedAt
                    )
                }
                nodeStatus = statuses
            }
        }

        var graph = WorkflowGraph(nodes: nodes, edges: edges, nodeStatus: nodeStatus)
        // Extract the workflow's owning store_id from the get response
        graph.ownerStoreId = dict["store_id"] as? String
        currentGraph = graph
        return graph
    }

    // MARK: - Run Control

    func startRun(workflowId: String, triggerPayload: [String: Any]? = nil, storeId: UUID?) async -> WorkflowRun? {
        var args: [String: Any] = ["workflow_id": workflowId]
        if let payload = triggerPayload { args["trigger_payload"] = payload }
        args["idempotency_key"] = UUID().uuidString

        let result = await callTool(action: "start", args: args, storeId: storeId)
        if let dict = result as? [String: Any] {
            // Try direct decode first, then check common wrappers
            if let run = decodeRun(dict) { return run }
            // Server may wrap: { run: {...} }
            if let nested = dict["run"] as? [String: Any], let run = decodeRun(nested) { return run }
            print("[WorkflowService] startRun: decodeRun failed — keys: \(dict.keys.sorted())")
        } else if result != nil {
            print("[WorkflowService] startRun: unexpected result type: \(type(of: result))")
        } else {
            print("[WorkflowService] startRun: callTool returned nil — error: \(self.error ?? "none")")
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
        // DLQ not yet implemented server-side — derive from failed runs
        let runs = await getRuns(workflowId: nil, status: "failed", limit: 50, storeId: storeId)
        return runs.map { run in
            DLQEntry(
                id: run.id,
                runId: run.id,
                stepKey: "",
                error: run.error ?? "Unknown error",
                status: "pending",
                retryCount: nil,
                createdAt: run.startedAt ?? ""
            )
        }
    }

    func retryDLQ(dlqId: String, storeId: UUID?) async -> Bool {
        // DLQ retry not yet implemented — no-op
        self.error = "DLQ retry not available"
        return false
    }

    func dismissDLQ(dlqId: String, storeId: UUID?) async -> Bool {
        // DLQ dismiss not yet implemented — no-op
        self.error = "DLQ dismiss not available"
        return false
    }

    // MARK: - Metrics

    func getMetrics(days: Int = 30, storeId: UUID?) async -> WorkflowMetrics? {
        let result = await callTool(action: "analytics", args: ["days": days], storeId: storeId)
        if let dict = result as? [String: Any] {
            return decodeMetrics(dict)
        }
        return nil
    }

    // MARK: - Schedule

    func setSchedule(workflowId: String, cronExpression: String?, storeId: UUID?) async -> Bool {
        var args: [String: Any] = ["workflow_id": workflowId]
        if let cron = cronExpression {
            args["trigger_type"] = "schedule"
            args["trigger_config"] = ["cron_expression": cron]
        }
        return await callTool(action: "update", args: args, storeId: storeId) != nil
    }

    // MARK: - Webhooks

    func createWebhook(workflowId: String, name: String, slug: String, storeId: UUID?) async -> WebhookEndpoint? {
        let result = await callTool(action: "create_webhook", args: [
            "workflow_id": workflowId, "name": name, "slug": slug
        ], storeId: storeId)
        if let dict = result as? [String: Any] { return decodeWebhook(dict) }
        return nil
    }

    func listWebhooks(workflowId: String, storeId: UUID?) async -> [WebhookEndpoint] {
        let result = await callTool(action: "list_webhooks", args: ["workflow_id": workflowId], storeId: storeId)
        if let items = result as? [[String: Any]] {
            return items.compactMap { decodeWebhook($0) }
        } else if let wrapper = result as? [String: Any], let items = wrapper["webhooks"] as? [[String: Any]] {
            return items.compactMap { decodeWebhook($0) }
        }
        return []
    }

    func deleteWebhook(webhookId: String, storeId: UUID?) async -> Bool {
        await callTool(action: "delete_webhook", args: ["webhook_id": webhookId], storeId: storeId) != nil
    }

    // MARK: - Rollback

    func rollback(workflowId: String, version: Int, storeId: UUID?) async -> Bool {
        await callTool(action: "rollback", args: ["workflow_id": workflowId, "version": version], storeId: storeId) != nil
    }

    // MARK: - Checkpoints

    func getCheckpoints(runId: String, storeId: UUID?) async -> [WorkflowCheckpoint] {
        // Checkpoints not yet implemented server-side
        return []
    }

    func replayFromCheckpoint(checkpointId: String, storeId: UUID?) async -> WorkflowRun? {
        // Replay not yet implemented server-side
        self.error = "Replay not available"
        return nil
    }

    // MARK: - Waitpoints

    func listWaitpoints(runId: String, storeId: UUID?) async -> [WorkflowWaitpoint] {
        // Waitpoints not yet implemented server-side
        return []
    }

    func completeWaitpoint(waitpointId: String, data: [String: Any]?, storeId: UUID?) async -> Bool {
        // Waitpoints not yet implemented server-side
        self.error = "Waitpoints not available"
        return false
    }

    // MARK: - Events

    func getEvents(runId: String, storeId: UUID?) async -> [WorkflowEvent] {
        // Events not yet implemented server-side
        return []
    }

    // MARK: - Step Testing

    /// Test a single step in isolation with mock input data.
    /// Sends action "test_step" to the backend with the step key and mock input.
    func testStep(workflowId: String, stepKey: String, mockInput: [String: Any], storeId: UUID?) async -> StepRun? {
        // test_step not yet implemented server-side — start a full run instead
        self.error = "Step testing not available"
        return nil
    }

    // MARK: - SSE Streaming

    func streamRun(runId: String) -> AsyncStream<WorkflowSSEEvent> {
        AsyncStream { continuation in
            let task = Task {
                var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
                components.path = "/workflows/runs/\(runId)/stream"
                let url = components.url ?? serverURL.appendingPathComponent("workflows/runs/\(runId)/stream")
                var request = URLRequest(url: url)
                request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

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

        var body: [String: Any] = [
            "mode": "tool",
            "tool_name": "workflows",
            "args": fullArgs,
        ]
        if let storeId { body["store_id"] = storeId.uuidString.lowercased() }

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
                // Try to extract error message from response body
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMsg = errorJson["error"] as? String {
                    self.error = "[\(statusCode)] \(errorMsg)"
                } else {
                    self.error = "Server error \(statusCode)"
                }
                print("[WorkflowService] \(action) failed: \(self.error ?? "") — body: \(String(data: data, encoding: .utf8) ?? "")")
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
            updatedAt: dict["updated_at"] as? String,
            errorWebhookUrl: dict["on_error_webhook_url"] as? String ?? dict["error_webhook_url"] as? String,
            errorEmail: dict["on_error_email"] as? String ?? dict["error_email"] as? String,
            circuitBreakerThreshold: dict["circuit_breaker_threshold"] as? Int
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
            // Parse step_config into AnyCodable dict
            var stepConfig: [String: AnyCodable]?
            if let sc = n["step_config"] as? [String: Any] {
                stepConfig = sc.mapValues { AnyCodable($0) }
            }

            return GraphNode(
                id: id,
                stepId: n["step_id"] as? String,
                type: n["type"] as? String ?? "noop",
                label: n["label"] as? String ?? id,
                isEntryPoint: n["is_entry_point"] as? Bool ?? false,
                position: pos,
                configSummary: summary,
                onSuccess: n["on_success"] as? String,
                onFailure: n["on_failure"] as? String,
                stepConfig: stepConfig,
                maxRetries: n["max_retries"] as? Int,
                timeoutSeconds: n["timeout_seconds"] as? Int
            )
        }

        let edges = edgesArr.compactMap { e -> GraphEdge? in
            guard let from = e["from"] as? String, let to = e["to"] as? String else { return nil }
            return GraphEdge(from: from, to: to, type: e["type"] as? String ?? "success", label: e["label"] as? String)
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
        guard let id = (dict["id"] as? String) ?? (dict["run_id"] as? String) else { return nil }
        return WorkflowRun(
            id: id,
            workflowId: dict["workflow_id"] as? String ?? "",
            status: dict["status"] as? String ?? "unknown",
            triggerType: dict["trigger_type"] as? String,
            triggerPayload: nil,
            startedAt: dict["started_at"] as? String ?? dict["created_at"] as? String,
            completedAt: dict["completed_at"] as? String,
            error: (dict["error"] as? String) ?? (dict["error_message"] as? String),
            traceId: dict["trace_id"] as? String
        )
    }

    private func decodeStepRun(_ dict: [String: Any]) -> StepRun? {
        guard let id = dict["id"] as? String else { return nil }
        var inputMap: [String: AnyCodable]?
        if let input = dict["input"] as? [String: Any] {
            inputMap = input.mapValues { AnyCodable($0) }
        }
        var outputMap: [String: AnyCodable]?
        if let output = dict["output"] as? [String: Any] {
            outputMap = output.mapValues { AnyCodable($0) }
        }
        return StepRun(
            id: id,
            runId: dict["run_id"] as? String ?? "",
            stepKey: dict["step_key"] as? String ?? "",
            stepType: dict["step_type"] as? String ?? "",
            status: dict["status"] as? String ?? "",
            input: inputMap,
            output: outputMap,
            error: (dict["error"] as? String) ?? (dict["error_message"] as? String),
            durationMs: dict["duration_ms"] as? Int,
            startedAt: dict["started_at"] as? String,
            completedAt: dict["completed_at"] as? String,
            retryCount: (dict["retry_count"] as? Int) ?? (dict["attempt_count"] as? Int)
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
        // Analytics response has: total_runs, success_rate, avg_duration_ms,
        // success_count, failed_count, running_count, by_workflow, by_trigger_type
        var topErrors: [[String: AnyCodable]]?
        if let errArr = dict["top_errors"] as? [[String: Any]] {
            topErrors = errArr.map { $0.mapValues { AnyCodable($0) } }
        }

        var stepStats: [[String: AnyCodable]]?
        if let statsArr = dict["step_stats"] as? [[String: Any]] {
            stepStats = statsArr.map { $0.mapValues { AnyCodable($0) } }
        }
        // Also try by_workflow as step-level stats
        if stepStats == nil, let byWf = dict["by_workflow"] as? [[String: Any]], !byWf.isEmpty {
            stepStats = byWf.map { $0.mapValues { AnyCodable($0) } }
        }

        // success_rate may come as 0-1 or 0-100 or nil
        var successRate = dict["success_rate"] as? Double
        if successRate == nil {
            let total = dict["total_runs"] as? Int ?? 0
            let success = dict["success_count"] as? Int ?? 0
            if total > 0 { successRate = Double(success) / Double(total) * 100.0 }
        }

        return WorkflowMetrics(
            totalRuns: dict["total_runs"] as? Int,
            successRate: successRate,
            avgDurationMs: dict["avg_duration_ms"] as? Double,
            p50Ms: dict["p50_ms"] as? Double,
            p95Ms: dict["p95_ms"] as? Double,
            p99Ms: dict["p99_ms"] as? Double,
            dlqCount: dict["dlq_count"] as? Int ?? (dict["failed_count"] as? Int),
            topErrors: topErrors,
            stepStats: stepStats
        )
    }

    private func decodeWebhook(_ dict: [String: Any]) -> WebhookEndpoint? {
        guard let id = dict["id"] as? String else { return nil }
        return WebhookEndpoint(
            id: id,
            workflowId: dict["workflow_id"] as? String ?? "",
            name: dict["name"] as? String ?? "",
            slug: dict["slug"] as? String ?? "",
            url: dict["url"] as? String,
            isActive: dict["is_active"] as? Bool ?? true,
            createdAt: dict["created_at"] as? String ?? ""
        )
    }

    private func decodeCheckpoint(_ dict: [String: Any]) -> WorkflowCheckpoint? {
        guard let id = dict["id"] as? String else { return nil }
        var stateMap: [String: AnyCodable]?
        if let state = dict["state"] as? [String: Any] {
            stateMap = state.mapValues { AnyCodable($0) }
        }
        return WorkflowCheckpoint(
            id: id,
            runId: dict["run_id"] as? String ?? "",
            stepKey: dict["step_key"] as? String ?? "",
            state: stateMap,
            createdAt: dict["created_at"] as? String ?? ""
        )
    }

    private func decodeEvent(_ dict: [String: Any]) -> WorkflowEvent? {
        guard let id = dict["id"] as? String else { return nil }
        var dataMap: [String: AnyCodable]?
        if let data = dict["data"] as? [String: Any] {
            dataMap = data.mapValues { AnyCodable($0) }
        }
        return WorkflowEvent(
            id: id,
            runId: dict["run_id"] as? String ?? "",
            eventType: dict["event_type"] as? String ?? "",
            stepKey: dict["step_key"] as? String,
            data: dataMap,
            createdAt: dict["created_at"] as? String ?? ""
        )
    }

    private func decodeWaitpoint(_ dict: [String: Any]) -> WorkflowWaitpoint? {
        guard let id = dict["id"] as? String else { return nil }
        var dataMap: [String: AnyCodable]?
        if let data = dict["data"] as? [String: Any] {
            dataMap = data.mapValues { AnyCodable($0) }
        }
        return WorkflowWaitpoint(
            id: id,
            runId: dict["run_id"] as? String ?? "",
            stepKey: dict["step_key"] as? String ?? "",
            label: dict["label"] as? String,
            status: dict["status"] as? String ?? "pending",
            data: dataMap,
            expiresAt: dict["expires_at"] as? String,
            createdAt: dict["created_at"] as? String ?? ""
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
