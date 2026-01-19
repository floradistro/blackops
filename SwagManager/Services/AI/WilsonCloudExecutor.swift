import Foundation

// MARK: - Wilson Cloud Executor
// Extracted from AIService.swift following Apple engineering standards
// Contains: Wilson Cloud API execution logic
// File size: ~130 lines (under Apple's 300 line "excellent" threshold)

final class WilsonCloudExecutor: @unchecked Sendable {
    
    // Supabase config - same as Wilson uses
    private let apiUrl = "https://uaednwpxursknmwdeejn.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg"
    
    // MARK: - Invoke Wilson Cloud API

    func invokeWilsonCloud(
        messages: [[String: Any]],
        context: [String: Any]
    ) async throws -> String {
        // Extract last message
        guard let lastMessage = messages.last,
              let content = lastMessage["content"] as? String else {
            throw AIServiceError.invalidResponse
        }

        // Build the request body (matching Wilson's format)
        let body: [String: Any] = [
            "message": content,
            "history": messages.dropLast(),
            "store_id": context["STORE_ID"] as? String ?? "",
            "location_id": context["LOCATION_ID"] as? String ?? "",
            "platform": "darwin",
            "client": "swagmanager-desktop",
            "format_hint": "markdown",
            "execute_tools": true,  // Execute tools server-side
            "auto_execute": true,   // Auto-continue after tool execution
            "style_instructions": """
                SwagManager Desktop App. Format for rich display:
                - Use markdown tables for data
                - Use code blocks for technical output
                - Keep responses concise but complete
                - Include relevant metrics and numbers
                """
        ]

        // Create the request
        guard let url = URL(string: "\(apiUrl)/functions/v1/agentic-loop") else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        // TODO: Add authentication token
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        // Make the request and collect SSE response
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Parse SSE stream and collect text
        var fullResponse = ""

        for try await line in bytes.lines {
            // SSE format: "data: {...}"
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))

                if jsonString == "[DONE]" {
                    break
                }

                if let data = jsonString.data(using: .utf8),
                   let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    // Handle different event types
                    if let eventType = event["type"] as? String {
                        switch eventType {
                        case "text_delta":
                            if let text = event["text"] as? String {
                                fullResponse += text
                            }
                        case "content_block_delta":
                            if let delta = event["delta"] as? [String: Any],
                               let text = delta["text"] as? String {
                                fullResponse += text
                            }
                        case "error":
                            if let errorMsg = event["error"] as? String {
                                throw AIServiceError.apiError(errorMsg)
                            }
                        default:
                            break
                        }
                    }

                    // Also check for direct text field (some backends)
                    if let text = event["text"] as? String, fullResponse.isEmpty {
                        fullResponse += text
                    }
                }
            }
        }

        if fullResponse.isEmpty {
            // Fallback if streaming didn't work - might be direct response
            throw AIServiceError.invalidResponse
        }

        return fullResponse
    }

}
