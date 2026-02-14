import Foundation
import SwiftUI

// MARK: - Agent State (Unified)
// Single source of truth for agent status

enum AgentState: Equatable {
    case idle
    case launching
    case running
    case failed(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var error: String? {
        if case .failed(let msg) = self { return msg }
        return nil
    }
}

// MARK: - Agent Process Manager
// Manages the lifecycle of the cloud agent connection (Fly.io)
// No local process needed — the server runs on whale-agent.fly.dev

@MainActor
@Observable
class AgentProcessManager {
    static let shared = AgentProcessManager()

    // MARK: - State (SINGLE source of truth)

    private(set) var state: AgentState = .idle

    var isRunning: Bool { state.isRunning }
    var error: String? { state.error }

    // MARK: - State Transition

    private func transition(to newState: AgentState, reason: String = "") {
        guard state != newState else { return }
        FreezeDebugger.transitionAgentState(
            newState.isRunning ? .running : (newState.error != nil ? .failed : .idle),
            reason: reason
        )
        FreezeDebugger.logStateChange("agentState", old: state, new: newState)
        state = newState
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        transition(to: .launching, reason: "start() called")

        // Cloud service — verify server is reachable, then connect
        Task {
            let reachable = await checkServerHealth()
            if reachable {
                transition(to: .running, reason: "Fly.io server reachable")
                AgentClient.shared.connect()
            } else {
                transition(to: .failed("Cannot reach agent server at \(SupabaseConfig.agentServerURL.absoluteString)"), reason: "server unreachable")
            }
        }
    }

    func stop() {
        AgentClient.shared.disconnect()
        transition(to: .idle, reason: "stop() called")
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.start()
        }
    }

    // MARK: - Health Check

    private func checkServerHealth() async -> Bool {
        var request = URLRequest(url: SupabaseConfig.agentServerURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // Server returns 405 for GET (expects POST), but that proves it's alive
                return httpResponse.statusCode < 500
            }
            return false
        } catch {
            print("[AgentProcessManager] Health check failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Clear error state if client reconnects
    func clearErrorIfConnected() {
        if AgentClient.shared.isConnected && state.error != nil {
            transition(to: .running, reason: "connected - clearing error")
        }
    }
}
