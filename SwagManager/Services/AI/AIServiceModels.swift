import Foundation

// MARK: - AI Service Models & Types
// Extracted from AIService.swift following Apple engineering standards
// Contains: StreamEvent, SlashCommand, QuickAction, Errors
// File size: ~120 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Streaming Events

enum StreamEvent: Sendable {
    case text(String)                    // Text chunk
    case toolStart(name: String, id: String)  // Tool started executing
    case toolResult(name: String, id: String) // Tool result received
    case toolsPending(names: [String])   // Tools waiting to execute
    case usage(input: Int, output: Int)  // Token usage
    case done                            // Stream complete
    case error(String)                   // Error occurred
}

// MARK: - Execution Mode

enum AIExecutionMode {
    case local      // Spawn Wilson CLI subprocess
    case cloud      // Call cloud API
    case auto       // Try local first, fallback to cloud
}

// MARK: - Slash Commands

enum SlashCommand: String, CaseIterable {
    case summarize = "/summarize"
    case inventory = "/inventory"
    case sales = "/sales"
    case orders = "/orders"
    case products = "/products"
    case help = "/help"
    case analyze = "/analyze"
    case report = "/report"
    case lowstock = "/lowstock"
    case topsellers = "/topsellers"

    var description: String {
        switch self {
        case .summarize: return "Summarize recent activity"
        case .inventory: return "Check inventory levels"
        case .sales: return "View sales data"
        case .orders: return "View recent orders"
        case .products: return "Search products"
        case .help: return "Show available commands"
        case .analyze: return "Analyze data or trends"
        case .report: return "Generate a report"
        case .lowstock: return "Show low stock items"
        case .topsellers: return "Show top selling products"
        }
    }

    var icon: String {
        switch self {
        case .summarize: return "doc.text"
        case .inventory: return "shippingbox"
        case .sales: return "chart.bar"
        case .orders: return "bag"
        case .products: return "magnifyingglass"
        case .help: return "questionmark.circle"
        case .analyze: return "chart.xyaxis.line"
        case .report: return "doc.richtext"
        case .lowstock: return "exclamationmark.triangle"
        case .topsellers: return "star"
        }
    }
}

// MARK: - Quick Actions

struct QuickAction: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let prompt: String
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case wilsonNotFound
    case streamingNotSupported
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid response from API"
        case .apiError(let message): return "API Error: \(message)"
        case .wilsonNotFound: return "Wilson CLI not found"
        case .streamingNotSupported: return "Streaming not supported"
        }
    }
}
