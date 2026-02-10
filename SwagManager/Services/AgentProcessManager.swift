import Foundation
import Combine
import SwiftUI
import Darwin

// MARK: - Agent State (Unified)
// Single source of truth for agent status - prevents multiple @Published mutations

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
// Manages the lifecycle of the local Node.js agent server
// Spawns on app launch, terminates on app quit

@MainActor
@Observable
class AgentProcessManager {
    static let shared = AgentProcessManager()

    // MARK: - State (SINGLE source of truth)

    /// Unified agent state
    private(set) var state: AgentState = .idle

    /// Convenience accessors for backwards compatibility
    var isRunning: Bool { state.isRunning }
    var error: String? { state.error }

    private(set) var lastOutput: String = ""

    // MARK: - Process

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    // MARK: - Configuration

    private let serverPath: String
    private let port = 3847

    // MARK: - Initialization

    private init() {
        // Path to agent server (relative to app bundle or development path)
        #if DEBUG
        serverPath = "/Users/whale/Desktop/blackops/agent-server"
        #else
        serverPath = Bundle.main.resourcePath! + "/agent-server"
        #endif
    }

    // MARK: - State Transition (SINGLE POINT OF MUTATION)

    /// Transition to new state - guarded against duplicates
    private func transition(to newState: AgentState, reason: String = "") {
        guard state != newState else {
            FreezeDebugger.logStateChange("agentState (SKIPPED - same)", old: state, new: newState)
            return
        }

        FreezeDebugger.transitionAgentState(
            newState.isRunning ? .running : (newState.error != nil ? .failed : .idle),
            reason: reason
        )
        FreezeDebugger.logStateChange("agentState", old: state, new: newState)
        state = newState
    }

    // MARK: - Lifecycle

    func start() {
        print("[AgentProcessManager] start() called, isRunning=\(isRunning)")
        guard !isRunning else {
            print("[AgentProcessManager] Already running, skipping")
            return
        }

        FreezeDebugger.printRunloopContext("AgentProcessManager.start()")

        transition(to: .launching, reason: "start() called")

        // If port is already in use, just connect to the existing server
        let portInUse = isPortInUse(port)
        print("[AgentProcessManager] Port \(port) in use: \(portInUse)")

        if portInUse {
            print("[AgentProcessManager] Port \(port) already in use — connecting to existing server")
            // Set state immediately (not deferred) so AgentClient.connect() sees isRunning=true
            transition(to: .running, reason: "existing server on port")
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                print("[AgentProcessManager] Calling AgentClient.connect()")
                AgentClient.shared.connect()
            }
            return
        }

        // Check if npm/node is available
        guard FileManager.default.fileExists(atPath: "/usr/local/bin/node") ||
              FileManager.default.fileExists(atPath: "/opt/homebrew/bin/node") else {
            transition(to: .failed("Node.js not found. Please install Node.js."), reason: "Node.js not found")
            return
        }

        // Check if server directory exists
        guard FileManager.default.fileExists(atPath: serverPath) else {
            transition(to: .failed("Agent server not found at \(serverPath)"), reason: "server path not found")
            return
        }

        process = Process()
        outputPipe = Pipe()
        errorPipe = Pipe()

        // Use npx tsx to run TypeScript directly
        // Source shell profile to get PATH with node/npm
        process?.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process?.arguments = ["-l", "-c", "cd '\(serverPath)' && npx tsx src/index.ts"]
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe
        process?.currentDirectoryURL = URL(fileURLWithPath: serverPath)

        // Environment variables
        // The agent server should source its own .env for SUPABASE_SERVICE_ROLE_KEY
        var env = ProcessInfo.processInfo.environment
        env["AGENT_PORT"] = String(port)
        env["SUPABASE_URL"] = SupabaseConfig.url.absoluteString
        process?.environment = env

        // Handle output
        outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                Task { @MainActor in
                    self?.lastOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("[AgentServer] \(output)")
                }
            }
        }

        errorPipe?.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("[AgentServer Error] \(output)")
            }
        }

        // Handle termination - ONE deferred state change
        process?.terminationHandler = { [weak self] process in
            let exitCode = process.terminationStatus
            // Must dispatch to main since terminationHandler runs on background thread
            DispatchQueue.main.async {
                if exitCode != 0 {
                    self?.transition(to: .failed("Agent server exited with code \(exitCode)"), reason: "process terminated")
                } else {
                    self?.transition(to: .idle, reason: "process terminated normally")
                }
            }
        }

        do {
            try process?.run()
            print("[AgentProcessManager] Launched agent server process...")

            // Wait briefly then verify process is still running
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                // Check if process died immediately (e.g., npx not found)
                guard let proc = self.process, proc.isRunning else {
                    // ONE state change for failure
                    let errorMsg = self.state.error ?? "Agent server process exited immediately. Check Node.js installation."
                    self.transition(to: .failed(errorMsg), reason: "process died immediately")
                    print("[AgentProcessManager] Process died - NOT connecting client")
                    return
                }

                // Process is running - ONE state change
                self.transition(to: .running, reason: "process verified running")
                print("[AgentProcessManager] Agent server running on port \(self.port)")

                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 more seconds

                // Final check before connecting
                guard self.isRunning, self.process?.isRunning == true else {
                    print("[AgentProcessManager] Process stopped - NOT connecting client")
                    return
                }

                AgentClient.shared.connect()
            }
        } catch {
            // ONE state change for failure
            transition(to: .failed("Failed to start agent server: \(error.localizedDescription)"), reason: "launch error")
            print("[AgentProcessManager] Error: \(error)")
        }
    }

    func stop() {
        FreezeDebugger.printRunloopContext("AgentProcessManager.stop()")

        AgentClient.shared.disconnect()

        if let process = process {
            process.terminate()
            self.process = nil
            outputPipe = nil
            errorPipe = nil
            print("[AgentProcessManager] Stopped agent server process")
        } else {
            print("[AgentProcessManager] Disconnected from external server")
        }

        // ONE state change
        transition(to: .idle, reason: "stop() called")
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.start()
        }
    }

    // MARK: - Install Dependencies

    func installDependencies() async -> Bool {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "cd '\(serverPath)' && npm install"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            print("[AgentProcessManager] npm install output: \(output)")

            return process.terminationStatus == 0
        } catch {
            print("[AgentProcessManager] npm install error: \(error)")
            return false
        }
    }

    // MARK: - Check Dependencies

    func checkDependencies() -> Bool {
        let nodeModulesPath = "\(serverPath)/node_modules"
        return FileManager.default.fileExists(atPath: nodeModulesPath)
    }

    // MARK: - Port Check

    private func isPortInUse(_ port: Int) -> Bool {
        // Use socket connection test instead of lsof (works in app sandbox)
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            print("[AgentProcessManager] Failed to create socket")
            return false
        }
        defer { close(sock) }

        // Try to connect (blocking, but fast if port is open)
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        let inUse = (result == 0)
        print("[AgentProcessManager] Port \(port) in use: \(inUse)")
        return inUse
    }

    /// Call this when external server is detected to clear stale errors
    func clearErrorIfConnected() {
        if AgentClient.shared.isConnected && state.error != nil {
            transition(to: .running, reason: "connected - clearing error")
        }
    }
}
