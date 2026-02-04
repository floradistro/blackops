import Foundation
import os.log

// MARK: - App Logger
// Centralized logging that can be easily disabled for production
// Replaces 340+ NSLog/print calls with proper os.log

enum LogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case none = 99
}

struct AppLogger {
    // Set to .none in production to disable all logs
    #if DEBUG
    static var minimumLevel: LogLevel = .debug
    #else
    static var minimumLevel: LogLevel = .warning
    #endif

    private static let subsystem = Bundle.main.bundleIdentifier ?? "SwagManager"

    // Category-specific loggers
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let realtime = Logger(subsystem: subsystem, category: "Realtime")
    static let store = Logger(subsystem: subsystem, category: "Store")
    static let agent = Logger(subsystem: subsystem, category: "Agent")
    static let cart = Logger(subsystem: subsystem, category: "Cart")
    static let order = Logger(subsystem: subsystem, category: "Order")

    // Quick logging functions
    static func debug(_ message: String, category: Logger = ui) {
        guard minimumLevel.rawValue <= LogLevel.debug.rawValue else { return }
        category.debug("\(message)")
    }

    static func info(_ message: String, category: Logger = ui) {
        guard minimumLevel.rawValue <= LogLevel.info.rawValue else { return }
        category.info("\(message)")
    }

    static func warning(_ message: String, category: Logger = ui) {
        guard minimumLevel.rawValue <= LogLevel.warning.rawValue else { return }
        category.warning("\(message)")
    }

    static func error(_ message: String, category: Logger = ui) {
        guard minimumLevel.rawValue <= LogLevel.error.rawValue else { return }
        category.error("\(message)")
    }
}

// MARK: - Convenience Type Alias

typealias Log = AppLogger
