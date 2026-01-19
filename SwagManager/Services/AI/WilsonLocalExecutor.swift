import Foundation

// MARK: - Wilson Local Executor
// Extracted from AIService.swift following Apple engineering standards
// Contains: Local Wilson CLI subprocess execution logic
// File size: ~150 lines (under Apple's 300 line "excellent" threshold)

final class WilsonLocalExecutor: @unchecked Sendable {
    
    // Wilson CLI paths - try multiple locations
    private let wilsonPaths = [
        "/usr/local/bin/wilson",
        "/opt/homebrew/bin/wilson",
        "\(NSHomeDirectory())/.bun/bin/wilson",
        "\(NSHomeDirectory())/Desktop/wilson/dist/index.js"
    ]
    
    // MARK: - Find Wilson CLI
    
    func findWilson() -> String? {
        for path in wilsonPaths {
            if FileManager.default.fileExists(atPath: path) {
                if path.hasSuffix(".js") {
                    // Need to use node/bun to run the JS file
                    if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/bun") {
                        return "/opt/homebrew/bin/bun \(path)"
                    } else if FileManager.default.fileExists(atPath: "/usr/local/bin/node") {
                        return "/usr/local/bin/node \(path)"
                    }
                } else {
                    return path
                }
            }
        }
        return nil
    }
    
    // MARK: - Invoke Wilson CLI (Local Subprocess)

    func invokeWilsonCLI(
        messages: [[String: Any]],
        context: [String: Any],
        wilsonPath: String
    ) async throws -> String {

        // Extract last message
        guard let lastMessage = messages.last,
              let content = lastMessage["content"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()

                // Determine how to run wilson
                if wilsonPath.hasSuffix(".js") {
                    // Run via bun
                    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/bun")
                    if !FileManager.default.fileExists(atPath: "/usr/local/bin/bun") {
                        // Try homebrew bun
                        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/bun")
                    }
                    process.arguments = ["run", wilsonPath, "test", content]
                } else {
                    // Run directly
                    process.executableURL = URL(fileURLWithPath: wilsonPath)
                    process.arguments = ["test", content]
                }

                // Set environment with store context
                var env = ProcessInfo.processInfo.environment
                if let storeId = context["STORE_ID"] as? String {
                    env["WILSON_STORE_ID"] = storeId
                }
                if let locationId = context["LOCATION_ID"] as? String {
                    env["WILSON_LOCATION_ID"] = locationId
                }
                process.environment = env

                // Capture output
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                // Set timeout
                let timeoutItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: timeoutItem)

                do {
                    try process.run()
                    process.waitUntilExit()
                    timeoutItem.cancel()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    if process.terminationStatus != 0 {
                        let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: AIServiceError.apiError(errorString))
                        return
                    }

                    guard let output = String(data: outputData, encoding: .utf8) else {
                        continuation.resume(throwing: AIServiceError.invalidResponse)
                        return
                    }

                    // Parse Wilson output - strip ANSI codes and extract response
                    let cleanedOutput = self.stripANSICodes(output)
                    let responseText = self.extractWilsonResponse(cleanedOutput)

                    if responseText.isEmpty {
                        continuation.resume(throwing: AIServiceError.invalidResponse)
                    } else {
                        continuation.resume(returning: responseText)
                    }
                } catch {
                    timeoutItem.cancel()
                    continuation.resume(throwing: AIServiceError.apiError(error.localizedDescription))
                }
            }
        }
    }

    // Strip ANSI escape codes from terminal output
    private func stripANSICodes(_ text: String) -> String {
        // Match ANSI escape sequences: ESC[ followed by params and ending with a letter
        let pattern = "\\x1B\\[[0-9;]*[A-Za-z]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    // Extract the actual response from Wilson CLI output
    private func extractWilsonResponse(_ output: String) -> String {
        let lines = output.components(separatedBy: "\n")

        // Skip header lines, tool output markers, and capture the main response
        var responseLines: [String] = []
        var inResponse = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines at start
            if !inResponse && trimmed.isEmpty { continue }

            // Skip Wilson CLI header
            if trimmed.contains("Wilson CLI Test") { continue }
            if trimmed.hasPrefix("Store:") { continue }
            if trimmed.hasPrefix("❯") { continue }

            // Skip tool execution markers
            if trimmed.hasPrefix("⟳") || trimmed.hasPrefix("✓") || trimmed.hasPrefix("✗") { continue }
            if trimmed.hasPrefix("╭─") || trimmed.hasPrefix("╰─") || trimmed.hasPrefix("│") { continue }
            if trimmed.hasPrefix("[TOOL") { continue }
            if trimmed.contains("Continuation") { continue }

            // Skip final separator
            if trimmed.hasPrefix("─────") {
                if inResponse { break }
                continue
            }

            // Start capturing response content
            inResponse = true
            responseLines.append(line)
        }

        return responseLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
