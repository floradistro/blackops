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
    let request: ExecutionRequest?
    let response: ExecutionResponse?
    let userId: UUID?
    let storeId: UUID?
    let createdAt: Date

    var success: Bool { resultStatus == "success" }

    enum CodingKeys: String, CodingKey {
        case id
        case toolName = "tool_name"
        case resultStatus = "result_status"
        case executionTimeMs = "execution_time_ms"
        case errorMessage = "error_message"
        case errorCode = "error_code"
        case request
        case response
        case userId = "user_id"
        case storeId = "store_id"
        case createdAt = "created_at"
    }
}

struct ExecutionRequest: Codable {
    let parameters: [String: AnyCodable]?
    let headers: [String: String]?
    let method: String?
    let url: String?

    var prettyJSON: String {
        if let params = parameters {
            let dict = params.mapValues { $0.value }
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        return "{}"
    }
}

struct ExecutionResponse: Codable {
    let data: AnyCodable?
    let statusCode: Int?
    let headers: [String: String]?

    var prettyJSON: String {
        if let responseData = data?.value {
            if let data = try? JSONSerialization.data(withJSONObject: responseData, options: .prettyPrinted),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        return "{}"
    }
}

