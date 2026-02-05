import Foundation
import Combine

// MARK: - Agent Process Manager
// Manages the lifecycle of the local Node.js agent server
// Spawns on app launch, terminates on app quit

@MainActor
class AgentProcessManager: ObservableObject {
    static let shared = AgentProcessManager()

    // MARK: - Published State

    @Published private(set) var isRunning = false
    @Published private(set) var lastOutput: String = ""
    @Published private(set) var error: String?

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

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }

        error = nil

        // If port is already in use, just connect to the existing server
        if isPortInUse(port) {
            print("[AgentProcessManager] Port \(port) already in use — connecting to existing server")
            isRunning = true
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                AgentClient.shared.connect()
            }
            return
        }

        // Check if npm/node is available
        guard FileManager.default.fileExists(atPath: "/usr/local/bin/node") ||
              FileManager.default.fileExists(atPath: "/opt/homebrew/bin/node") else {
            error = "Node.js not found. Please install Node.js."
            return
        }

        // Check if server directory exists
        guard FileManager.default.fileExists(atPath: serverPath) else {
            error = "Agent server not found at \(serverPath)"
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
        var env = ProcessInfo.processInfo.environment
        env["AGENT_PORT"] = String(port)
        env["SUPABASE_URL"] = SupabaseConfig.url.absoluteString
        env["SUPABASE_SERVICE_ROLE_KEY"] = SupabaseConfig.serviceRoleKey
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

        errorPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                Task { @MainActor in
                    print("[AgentServer Error] \(output)")
                }
            }
        }

        // Handle termination
        process?.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.isRunning = false
                if process.terminationStatus != 0 {
                    self?.error = "Agent server exited with code \(process.terminationStatus)"
                }
            }
        }

        do {
            try process?.run()
            isRunning = true
            print("[AgentProcessManager] Started agent server on port \(port)")

            // Give server time to start, then connect client
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                AgentClient.shared.connect()
            }
        } catch {
            self.error = "Failed to start agent server: \(error.localizedDescription)"
            print("[AgentProcessManager] Error: \(error)")
        }
    }

    func stop() {
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
        isRunning = false
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
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-i", ":\(port)"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return !output.isEmpty && output.contains("LISTEN")
        } catch {
            return false
        }
    }

    /// Call this when external server is detected to clear stale errors
    func clearErrorIfConnected() {
        if AgentClient.shared.isConnected {
            error = nil
        }
    }
}
