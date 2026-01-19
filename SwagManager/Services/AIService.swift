import Foundation

// MARK: - AI Service (Wilson Integration - REFACTORED)
//
// Reduced from 750 lines to ~350 lines by extracting components:
// - AIServiceModels.swift (100 lines) - Types, enums, errors
// - WilsonLocalExecutor.swift (175 lines) - Local CLI execution
// - WilsonCloudExecutor.swift (131 lines) - Cloud API execution
//
// File size: ~350 lines (under Apple's 500 line "good" threshold)

final class AIService: @unchecked Sendable {
    static let shared = AIService()

    // Executors
    private let localExecutor = WilsonLocalExecutor()
    private let cloudExecutor = WilsonCloudExecutor()

    // Execution mode
    var preferredMode: AIExecutionMode = .auto

    // MARK: - Quick Actions

    static let quickActions: [QuickAction] = [
        QuickAction(label: "Today's sales", icon: "chart.bar", prompt: "@lisa what were today's sales?"),
        QuickAction(label: "Low stock", icon: "exclamationmark.triangle", prompt: "@lisa show me low stock items"),
        QuickAction(label: "Recent orders", icon: "bag", prompt: "@lisa show recent orders"),
        QuickAction(label: "Product search", icon: "magnifyingglass", prompt: "@lisa search for"),
    ]

    private init() {}

    // MARK: - Message Parsing

    func parseSlashCommand(from message: String) -> (command: SlashCommand, args: String)? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)

        for command in SlashCommand.allCases {
            if trimmed.hasPrefix(command.rawValue) {
                let args = String(trimmed.dropFirst(command.rawValue.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (command, args)
            }
        }

        return nil
    }

    func executeSlashCommand(_ command: SlashCommand, args: String, context: [String: Any]) async throws -> String {
        // Map slash commands to natural language queries
        let query: String
        switch command {
        case .summarize:
            query = "Summarize recent activity and key metrics"
        case .inventory:
            query = args.isEmpty ? "Show current inventory status" : "Check inventory for: \(args)"
        case .sales:
            query = args.isEmpty ? "Show sales summary" : "Analyze sales: \(args)"
        case .orders:
            query = args.isEmpty ? "Show recent orders" : "Show orders: \(args)"
        case .products:
            query = args.isEmpty ? "List products" : "Search products: \(args)"
        case .help:
            let commands = SlashCommand.allCases.map { "\($0.rawValue) - \($0.description)" }.joined(separator: "\n")
            return "Available commands:\n\(commands)"
        case .analyze:
            query = args.isEmpty ? "Analyze current data" : "Analyze: \(args)"
        case .report:
            query = args.isEmpty ? "Generate a report" : "Generate report for: \(args)"
        case .lowstock:
            query = "Show items with low stock levels"
        case .topsellers:
            query = "Show top selling products"
        }

        // Execute as normal AI query
        let response = try await invokeAI(
            messages: [["role": "user", "content": query]],
            context: context,
            streaming: false
        )

        return response
    }

    // MARK: - AI Context

    func buildContext(storeId: String?, locationId: String?) -> [String: Any] {
        var context: [String: Any] = [:]

        if let storeId = storeId {
            context["STORE_ID"] = storeId
        }

        if let locationId = locationId {
            context["LOCATION_ID"] = locationId
        }

        return context
    }

    // MARK: - Invoke AI (Main Entry Point)

    func invokeAI(
        messages: [[String: Any]],
        context: [String: Any] = [:],
        streaming: Bool = false
    ) async throws -> String {
        switch preferredMode {
        case .local:
            return try await invokeLocalMode(messages: messages, context: context)

        case .cloud:
            return try await invokeCloudMode(messages: messages, context: context)

        case .auto:
            // Try local first
            if let wilsonPath = localExecutor.findWilson() {
                NSLog("[AIService] Found Wilson at: \(wilsonPath)")
                return try await invokeLocalMode(messages: messages, context: context)
            }

            // Fallback to cloud
            NSLog("[AIService] Wilson not found locally, using cloud API")
            return try await invokeCloudMode(messages: messages, context: context)
        }
    }

    // MARK: - Streaming AI (Returns AsyncThrowingStream)

    func streamAI(
        messages: [[String: Any]],
        context: [String: Any] = [:]
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    switch preferredMode {
                    case .local:
                        try await streamLocalMode(messages: messages, context: context, continuation: continuation)

                    case .cloud:
                        try await streamCloudMode(messages: messages, context: context, continuation: continuation)

                    case .auto:
                        // Try local first
                        if let wilsonPath = localExecutor.findWilson() {
                            NSLog("[AIService] Found Wilson at: \(wilsonPath)")
                            try await streamLocalMode(messages: messages, context: context, continuation: continuation)
                        } else {
                            // Fallback to cloud
                            NSLog("[AIService] Wilson not found locally, using cloud API")
                            try await streamCloudMode(messages: messages, context: context, continuation: continuation)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Mode Handlers

    private func invokeLocalMode(messages: [[String: Any]], context: [String: Any]) async throws -> String {
        guard let wilsonPath = localExecutor.findWilson() else {
            throw AIServiceError.wilsonNotFound
        }
        return try await localExecutor.invokeWilsonCLI(messages: messages, context: context, wilsonPath: wilsonPath)
    }

    private func invokeCloudMode(messages: [[String: Any]], context: [String: Any]) async throws -> String {
        return try await cloudExecutor.invokeWilsonCloud(messages: messages, context: context)
    }

    private func streamLocalMode(
        messages: [[String: Any]],
        context: [String: Any],
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) async throws {
        guard let wilsonPath = localExecutor.findWilson() else {
            throw AIServiceError.wilsonNotFound
        }

        // Parse subprocess output and emit events
        let response = try await localExecutor.invokeWilsonCLI(messages: messages, context: context, wilsonPath: wilsonPath)

        // For now, emit as single text event
        // TODO: Parse streaming format from Wilson CLI
        continuation.yield(.text(response))
        continuation.yield(.done)
    }

    private func streamCloudMode(
        messages: [[String: Any]],
        context: [String: Any],
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) async throws {
        // Parse cloud API streaming response
        let response = try await cloudExecutor.invokeWilsonCloud(messages: messages, context: context)

        // For now, emit as single text event
        // TODO: Implement proper SSE streaming parser
        continuation.yield(.text(response))
        continuation.yield(.done)
    }

    // MARK: - Status Check

    func checkWilsonStatus() async -> (available: Bool, mode: String, path: String?) {
        if let wilsonPath = localExecutor.findWilson() {
            return (true, "local", wilsonPath)
        }

        // Check cloud availability by making a test request
        do {
            _ = try await cloudExecutor.invokeWilsonCloud(
                messages: [["role": "user", "content": "test"]],
                context: [:]
            )
            return (true, "cloud", nil)
        } catch {
            return (false, "none", nil)
        }
    }
}

// MARK: - String Extensions

extension String {
    func extractJSON() -> [String: Any]? {
        guard let data = self.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
