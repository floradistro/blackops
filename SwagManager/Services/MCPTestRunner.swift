import Foundation
import Supabase

// MARK: - MCP Test Runner
// Executes MCP server calls and tracks results

@MainActor
class MCPTestRunner: ObservableObject {
    @Published var isRunning = false
    @Published var lastResult: TestResult?
    @Published var history: [TestExecution] = []

    private let supabase = SupabaseService.shared

    struct TestResult {
        let success: Bool
        let output: String
        let duration: Double?
        let timestamp: Date
    }

    struct TestExecution: Identifiable {
        let id = UUID()
        let serverName: String
        let parameters: [String: String]
        let result: TestResult
    }

    func execute(server: MCPServer, parameters: [String: String]) async {
        isRunning = true
        let startTime = Date()

        do {
            let result = try await executeServer(server: server, parameters: parameters)
            let duration = Date().timeIntervalSince(startTime)

            let testResult = TestResult(
                success: true,
                output: formatOutput(result),
                duration: duration,
                timestamp: Date()
            )

            lastResult = testResult
            history.append(TestExecution(
                serverName: server.name,
                parameters: parameters,
                result: testResult
            ))

            // Log execution to database
            await logExecution(
                toolName: server.name,
                parameters: parameters,
                result: result,
                duration: duration,
                success: true
            )

            NSLog("[MCPTestRunner] Successfully executed \(server.name) in \(String(format: "%.2f", duration))s")
        } catch {
            let duration = Date().timeIntervalSince(startTime)

            let testResult = TestResult(
                success: false,
                output: "Error: \(error.localizedDescription)\n\n\(error)",
                duration: duration,
                timestamp: Date()
            )

            lastResult = testResult
            history.append(TestExecution(
                serverName: server.name,
                parameters: parameters,
                result: testResult
            ))

            // Log failed execution to database
            await logExecution(
                toolName: server.name,
                parameters: parameters,
                result: ["error": error.localizedDescription],
                duration: duration,
                success: false,
                errorMessage: error.localizedDescription
            )

            NSLog("[MCPTestRunner] Error executing \(server.name): \(error)")
        }

        isRunning = false
    }

    private func executeServer(server: MCPServer, parameters: [String: String]) async throws -> Any {
        // Log server details for debugging
        NSLog("[MCPTestRunner] Executing server: \(server.name)")
        NSLog("[MCPTestRunner]   rpcFunction: \(server.rpcFunction ?? "nil")")
        NSLog("[MCPTestRunner]   edgeFunction: \(server.edgeFunction ?? "nil")")
        NSLog("[MCPTestRunner]   category: \(server.category)")
        NSLog("[MCPTestRunner]   id: \(server.id)")

        // Determine execution method
        if let rpcFunction = server.rpcFunction {
            return try await executeRPC(function: rpcFunction, parameters: parameters)
        } else if let edgeFunction = server.edgeFunction {
            return try await executeEdgeFunction(function: edgeFunction, serverName: server.name, parameters: parameters)
        } else {
            NSLog("[MCPTestRunner] ERROR: Both rpcFunction and edgeFunction are nil!")
            throw MCPError.noExecutionMethod
        }
    }

    private func executeRPC(function: String, parameters: [String: String]) async throws -> Any {
        // Convert string parameters to proper JSON types and add required context
        var jsonParams: [String: Any] = [:]

        // Add user context if available
        if let user = try? await supabase.client.auth.session.user {
            jsonParams["user_id"] = user.id.uuidString
        }

        // Add store context (use default store for now)
        jsonParams["store_id"] = "cd2e1122-d511-4edb-be5d-98ef274b4baf"

        // Parse string parameters into proper types
        for (key, value) in parameters {
            if value.isEmpty { continue }

            // Try to detect and convert types
            if let intValue = Int(value) {
                jsonParams[key] = intValue
            } else if let doubleValue = Double(value) {
                jsonParams[key] = doubleValue
            } else if value.lowercased() == "true" || value.lowercased() == "false" {
                jsonParams[key] = value.lowercased() == "true"
            } else if value.starts(with: "{") || value.starts(with: "[") {
                // Try to parse as JSON
                if let data = value.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) {
                    jsonParams[key] = json
                } else {
                    jsonParams[key] = value
                }
            } else {
                jsonParams[key] = value
            }
        }

        // Execute RPC with properly typed parameters
        let jsonData = try JSONSerialization.data(withJSONObject: jsonParams)

        // Log the request for debugging
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            NSLog("[MCPTestRunner] Executing RPC: \(function) with params: \(jsonString)")
        }

        let response = try await supabase.client
            .rpc(function, params: jsonData)
            .execute()

        return try JSONSerialization.jsonObject(with: response.data)
    }

    private func executeEdgeFunction(function: String, serverName: String, parameters: [String: String]) async throws -> Any {
        // Execute Supabase Edge Function
        let supabaseURL = SupabaseConfig.url.absoluteString
        let apiKey = SupabaseConfig.anonKey

        let urlString = "\(supabaseURL)/functions/v1/\(function)"
        guard let url = URL(string: urlString) else {
            throw MCPError.executionFailed("Invalid edge function URL")
        }

        // Convert string parameters to proper types
        var typedParams: [String: Any] = [:]
        for (key, value) in parameters {
            if value.isEmpty { continue }

            if let intValue = Int(value) {
                typedParams[key] = intValue
            } else if let doubleValue = Double(value) {
                typedParams[key] = doubleValue
            } else if value.lowercased() == "true" || value.lowercased() == "false" {
                typedParams[key] = value.lowercased() == "true"
            } else if value.starts(with: "{") || value.starts(with: "[") {
                if let data = value.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) {
                    typedParams[key] = json
                } else {
                    typedParams[key] = value
                }
            } else {
                typedParams[key] = value
            }
        }

        // Build request body with context
        var requestBody: [String: Any] = [
            "operation": serverName,  // Edge function expects "operation" not "tool_name"
            "parameters": typedParams
        ]

        // Add user context if available
        if let user = try? await supabase.client.auth.session.user {
            requestBody["user_id"] = user.id.uuidString
        }

        // Add store context
        requestBody["store_id"] = "cd2e1122-d511-4edb-be5d-98ef274b4baf"

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        // Log the request for debugging
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            NSLog("[MCPTestRunner] Calling edge function: \(function) with body: \(jsonString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.executionFailed("Invalid response from edge function")
        }

        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            NSLog("[MCPTestRunner] Edge function error \(httpResponse.statusCode): \(errorMessage)")
            throw MCPError.executionFailed("Edge function failed: \(errorMessage)")
        }

        let result = try JSONSerialization.jsonObject(with: responseData)
        NSLog("[MCPTestRunner] Successfully executed edge function: \(function)")
        return result
    }

    private func formatOutput(_ result: Any) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(describing: result)
    }

    private func logExecution(
        toolName: String,
        parameters: [String: String],
        result: Any,
        duration: TimeInterval,
        success: Bool,
        errorMessage: String? = nil
    ) async {
        do {
            // Get user ID if available
            let userId = try? await supabase.client.auth.session.user.id

            // Get store ID (hardcoded for now, should come from context)
            let storeId = UUID(uuidString: "cd2e1122-d511-4edb-be5d-98ef274b4baf")!

            // Prepare request and response JSON as strings
            let requestJson = try? JSONSerialization.data(withJSONObject: parameters)
            let responseJson = try? JSONSerialization.data(withJSONObject: result)

            let requestString = requestJson.flatMap { String(data: $0, encoding: .utf8) }
            let responseString = responseJson.flatMap { String(data: $0, encoding: .utf8) }

            struct ExecutionLog: Encodable {
                let store_id: String
                let user_id: String?
                let tool_name: String
                let execution_time_ms: Int
                let result_status: String
                let error_message: String?
                let request: String?
                let response: String?
            }

            let log = ExecutionLog(
                store_id: storeId.uuidString,
                user_id: userId?.uuidString,
                tool_name: toolName,
                execution_time_ms: Int(duration * 1000),
                result_status: success ? "success" : "error",
                error_message: errorMessage,
                request: requestString,
                response: responseString
            )

            _ = try await supabase.client
                .from("lisa_tool_execution_log")
                .insert(log)
                .execute()

            NSLog("[MCPTestRunner] Logged execution to database: \(toolName)")
        } catch {
            NSLog("[MCPTestRunner] Failed to log execution: \(error)")
        }
    }
}

enum MCPError: Error, LocalizedError {
    case noExecutionMethod
    case invalidParameters
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noExecutionMethod:
            return "No execution method configured. Server must have either rpc_function or edge_function set."
        case .invalidParameters:
            return "Invalid parameters provided for tool execution."
        case .executionFailed(let message):
            return message
        }
    }
}
