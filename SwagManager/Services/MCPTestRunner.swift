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

            NSLog("[MCPTestRunner] Error executing \(server.name): \(error)")
        }

        isRunning = false
    }

    private func executeServer(server: MCPServer, parameters: [String: String]) async throws -> Any {
        // Determine execution method
        if let rpcFunction = server.rpcFunction {
            return try await executeRPC(function: rpcFunction, parameters: parameters)
        } else if let edgeFunction = server.edgeFunction {
            return try await executeEdgeFunction(function: edgeFunction, serverName: server.name, parameters: parameters)
        } else {
            throw MCPError.noExecutionMethod
        }
    }

    private func executeRPC(function: String, parameters: [String: String]) async throws -> Any {
        // For now, just pass string parameters and return the raw response
        // TODO: Improve parameter parsing and type conversion

        let response = try await supabase.client
            .rpc(function, params: parameters)
            .execute()

        return try JSONSerialization.jsonObject(with: response.data)
    }

    private func executeEdgeFunction(function: String, serverName: String, parameters: [String: String]) async throws -> Any {
        // TODO: Implement edge function execution
        // For now, return a placeholder
        NSLog("[MCPTestRunner] Edge function execution pending implementation")
        return ["status": "pending", "message": "Edge function execution not yet implemented"]
    }

    private func formatOutput(_ result: Any) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(describing: result)
    }
}

enum MCPError: Error {
    case noExecutionMethod
    case invalidParameters
    case executionFailed(String)
}
