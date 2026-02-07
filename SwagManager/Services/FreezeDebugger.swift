//
//  FreezeDebugger.swift
//  SwagManager
//
//  Surgical logging to catch layout recursion freezes.
//  Remove this file once the freeze is diagnosed.
//

import Foundation
import SwiftUI

// MARK: - Freeze Debugger

/// Surgical logging for diagnosing UI freezes caused by layout recursion.
/// Usage: Call these functions at state mutation and lifecycle points.
enum FreezeDebugger {

    /// Enable/disable all freeze debugging logs
    static var isEnabled = true

    /// Track nested layout calls - if this exceeds 1, we have recursion
    static var layoutDepth = 0

    // MARK: - State Change Logging

    /// Log any UI-driving state change with context
    static func logStateChange<T>(
        _ name: String,
        old: T,
        new: T,
        file: String = #file,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        let fileName = (file as NSString).lastPathComponent
        print("""
        🧠 STATE CHANGE: \(name)
           from: \(old)
             to: \(new)
           at: \(fileName):\(line)
           main: \(Thread.isMainThread)
           runloop: \(RunLoop.current.currentMode?.rawValue ?? "nil")
        """)
    }

    /// Log state change for optional values
    static func logStateChange<T>(
        _ name: String,
        old: T?,
        new: T?,
        file: String = #file,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        let fileName = (file as NSString).lastPathComponent
        print("""
        🧠 STATE CHANGE: \(name)
           from: \(old.map { "\($0)" } ?? "nil")
             to: \(new.map { "\($0)" } ?? "nil")
           at: \(fileName):\(line)
           main: \(Thread.isMainThread)
           runloop: \(RunLoop.current.currentMode?.rawValue ?? "nil")
        """)
    }

    // MARK: - Layout Logging

    /// Call at start of layoutSubviews
    static func layoutEnter(_ viewType: String) {
        guard isEnabled else { return }
        layoutDepth += 1
        let warning = layoutDepth > 1 ? " ⚠️ RECURSION DETECTED!" : ""
        print("📐 layoutSubviews ENTER \(viewType) [depth=\(layoutDepth)]\(warning)")
    }

    /// Call at end of layoutSubviews
    static func layoutExit(_ viewType: String) {
        guard isEnabled else { return }
        print("📐 layoutSubviews EXIT \(viewType) [depth=\(layoutDepth)]")
        layoutDepth -= 1
    }

    // MARK: - View Lifecycle Logging

    /// Log onAppear for a view
    static func onAppear(_ viewName: String) {
        guard isEnabled else { return }
        print("👁️ onAppear \(viewName)")
    }

    /// Log onDisappear for a view
    static func onDisappear(_ viewName: String) {
        guard isEnabled else { return }
        print("👁️ onDisappear \(viewName)")
    }

    // MARK: - Async Task Logging

    /// Log task cancellation
    static func taskCancelled(_ name: String) {
        guard isEnabled else { return }
        print("⛔️ TASK CANCELLED: \(name)")
    }

    /// Log async error
    static func asyncError(_ name: String, error: Error) {
        guard isEnabled else { return }
        print("❌ ASYNC ERROR in \(name): \(error)")
    }

    // MARK: - Agent Lifecycle FSM

    enum AgentLifecycleState: String {
        case idle = "idle"
        case launching = "launching"
        case failed = "failed"
        case running = "running"
        case connecting = "connecting"
        case connected = "connected"
        case disconnected = "disconnected"
    }

    private static var _agentState: AgentLifecycleState = .idle

    /// Transition agent lifecycle state (single authoritative log point)
    static func transitionAgentState(_ new: AgentLifecycleState, reason: String = "") {
        guard isEnabled else { return }
        let old = _agentState
        _agentState = new
        let reasonStr = reason.isEmpty ? "" : " (\(reason))"
        print("🤖 AgentLifecycle: \(old.rawValue) → \(new.rawValue)\(reasonStr)")
        print("   main: \(Thread.isMainThread), runloop: \(RunLoop.current.currentMode?.rawValue ?? "nil")")
    }

    // MARK: - Telemetry Lifecycle

    static func telemetryEvent(_ event: String) {
        guard isEnabled else { return }
        print("📊 Telemetry: \(event)")
    }

    // MARK: - Runloop Context

    /// Print current runloop context (call before suspicious state changes)
    static func printRunloopContext(_ label: String) {
        guard isEnabled else { return }
        print("""
        🌀 CONTEXT: \(label)
           MainThread: \(Thread.isMainThread)
           RunLoop: \(RunLoop.current.currentMode?.rawValue ?? "nil")
           LayoutDepth: \(layoutDepth)
        """)
    }
}

// MARK: - SwiftUI View Extension for Lifecycle Logging

extension View {
    /// Add freeze debugging lifecycle logging to a view
    func freezeDebugLifecycle(_ name: String) -> some View {
        self
            .onAppear { FreezeDebugger.onAppear(name) }
            .onDisappear { FreezeDebugger.onDisappear(name) }
    }
}
