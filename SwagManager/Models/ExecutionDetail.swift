import Foundation

// MARK: - Execution Detail Models
// Full execution details for debugging and inspection

struct ExecutionDetail: Codable, Identifiable {
    let id: UUID
    let toolName: String
    let resultStatus: String
    let executionTimeMs: Int?
    let errorMessage: String?
    let errorCode: String?
    let request: String?
    let response: String?
    let userId: UUID?
    let storeId: UUID?
    let createdAt: Date

    var success: Bool { resultStatus == "success" }

    // No CodingKeys - JSONDecoder uses .convertFromSnakeCase
    // which automatically converts tool_name -> toolName, etc.

    // Helper to pretty-print request JSON
    var prettyRequest: String {
        guard let request = request,
              let data = request.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return request ?? "{}"
        }
        return prettyString
    }

    // Helper to pretty-print response JSON
    var prettyResponse: String {
        guard let response = response,
              let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return response ?? "{}"
        }
        return prettyString
    }
}

