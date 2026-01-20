import Foundation
import Supabase

// MARK: - MCP Monitor
// Tracks execution statistics and health metrics

@MainActor
class MCPMonitor: ObservableObject {
    @Published var stats: MCPStats = MCPStats()
    @Published var recentExecutions: [ExecutionLog] = []
    @Published var errors: [ErrorLog] = []

    private let supabase = SupabaseService.shared

    func loadStats(timeRange: MCPMonitoringView.TimeRange) async {
        await loadExecutionStats(timeRange: timeRange)
        await loadRecentExecutions()
        await loadErrors()
    }

    func refresh() async {
        await loadStats(timeRange: .last24Hours)
    }

    private func loadExecutionStats(timeRange: MCPMonitoringView.TimeRange) async {
        do {
            // Calculate time filter
            let hoursAgo = timeRangeToHours(timeRange)
            let startDate = Calendar.current.date(byAdding: .hour, value: -hoursAgo, to: Date())!

            // Query lisa_tool_execution_log for statistics
            let response = try await supabase.client
                .from("lisa_tool_execution_log")
                .select("tool_name, success, duration_ms, created_at")
                .gte("created_at", value: ISO8601DateFormatter().string(from: startDate))
                .order("created_at", ascending: false)
                .limit(1000)
                .execute()

            let decoder = JSONDecoder.supabaseDecoder
            let executions = try decoder.decode([RawExecution].self, from: response.data)

            // Calculate statistics
            let totalExecutions = executions.count
            let successCount = executions.filter { $0.success }.count
            let successRate = totalExecutions > 0 ? Double(successCount) / Double(totalExecutions) * 100 : 0
            let avgResponseTime = executions.compactMap { $0.durationMs }.reduce(0.0, +) / Double(max(executions.count, 1))

            // Category breakdown
            var categoryMap: [String: Int] = [:]
            for execution in executions {
                // TODO: Map tool_name to category via ai_tool_registry
                let category = "unknown" // Placeholder
                categoryMap[category, default: 0] += 1
            }

            let categoryStats = categoryMap.map { key, value in
                CategoryStat(
                    category: key,
                    count: value,
                    percentage: Double(value) / Double(totalExecutions)
                )
            }.sorted { $0.count > $1.count }

            // Count active servers
            let activeServers = try await countActiveServers()

            stats = MCPStats(
                totalExecutions: totalExecutions,
                successRate: successRate,
                avgResponseTime: avgResponseTime,
                activeServers: activeServers,
                categoryStats: categoryStats
            )

            NSLog("[MCPMonitor] Loaded stats: \(totalExecutions) executions, \(successRate)% success")
        } catch {
            NSLog("[MCPMonitor] Error loading stats: \(error)")
        }
    }

    private func loadRecentExecutions() async {
        do {
            let response = try await supabase.client
                .from("lisa_tool_execution_log")
                .select("tool_name, success, duration_ms, created_at")
                .order("created_at", ascending: false)
                .limit(50)
                .execute()

            let decoder = JSONDecoder.supabaseDecoder
            let executions = try decoder.decode([RawExecution].self, from: response.data)

            recentExecutions = executions.map { raw in
                ExecutionLog(
                    id: UUID(),
                    serverName: raw.toolName,
                    success: raw.success,
                    duration: raw.durationMs != nil ? raw.durationMs! / 1000 : nil,
                    timestamp: raw.createdAt
                )
            }

            NSLog("[MCPMonitor] Loaded \(recentExecutions.count) recent executions")
        } catch {
            NSLog("[MCPMonitor] Error loading recent executions: \(error)")
        }
    }

    private func loadErrors() async {
        do {
            let response = try await supabase.client
                .from("lisa_tool_execution_log")
                .select("tool_name, error_message, created_at")
                .eq("success", value: false)
                .not("error_message", operator: .is, value: "null")
                .order("created_at", ascending: false)
                .limit(20)
                .execute()

            let decoder = JSONDecoder.supabaseDecoder
            let rawErrors = try decoder.decode([RawError].self, from: response.data)

            errors = rawErrors.map { raw in
                ErrorLog(
                    id: UUID(),
                    serverName: raw.toolName,
                    message: raw.errorMessage ?? "Unknown error",
                    timestamp: raw.createdAt
                )
            }

            NSLog("[MCPMonitor] Loaded \(errors.count) errors")
        } catch {
            NSLog("[MCPMonitor] Error loading errors: \(error)")
        }
    }

    private func countActiveServers() async throws -> Int {
        let response = try await supabase.client
            .from("ai_tool_registry")
            .select("id", head: false, count: .exact)
            .eq("is_active", value: true)
            .execute()

        return response.count ?? 0
    }

    private func timeRangeToHours(_ range: MCPMonitoringView.TimeRange) -> Int {
        switch range {
        case .lastHour: return 1
        case .last24Hours: return 24
        case .last7Days: return 24 * 7
        case .last30Days: return 24 * 30
        }
    }
}

// MARK: - Data Models

struct MCPStats {
    var totalExecutions: Int = 0
    var successRate: Double = 0
    var avgResponseTime: Double = 0
    var activeServers: Int = 0
    var categoryStats: [CategoryStat] = []
}

struct CategoryStat {
    let category: String
    let count: Int
    let percentage: Double
}

struct ExecutionLog: Identifiable {
    let id: UUID
    let serverName: String
    let success: Bool
    let duration: Double?
    let timestamp: Date
}

struct ErrorLog: Identifiable {
    let id: UUID
    let serverName: String
    let message: String
    let timestamp: Date
}

// MARK: - Raw Database Models

private struct RawExecution: Codable {
    let toolName: String
    let success: Bool
    let durationMs: Double?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case success
        case durationMs = "duration_ms"
        case createdAt = "created_at"
    }
}

private struct RawError: Codable {
    let toolName: String
    let errorMessage: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case errorMessage = "error_message"
        case createdAt = "created_at"
    }
}
