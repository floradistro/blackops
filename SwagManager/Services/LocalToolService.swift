import Foundation

// MARK: - Local Tool Service
// Executes coding tools locally on the Mac
// Mirrors Claude Code's local tool execution

@MainActor
class LocalToolService {
    static let shared = LocalToolService()

    // MARK: - Tool Definitions (for Anthropic API)

    static let toolDefinitions: [[String: Any]] = [
        [
            "name": "read_file",
            "description": "Read the contents of a file at the specified path",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "Absolute path to the file"]
                ],
                "required": ["path"]
            ]
        ],
        [
            "name": "write_file",
            "description": "Write content to a file, creating it if it doesn't exist",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "Absolute path to the file"],
                    "content": ["type": "string", "description": "Content to write"]
                ],
                "required": ["path", "content"]
            ]
        ],
        [
            "name": "edit_file",
            "description": "Edit a file by replacing old_string with new_string",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "Absolute path to the file"],
                    "old_string": ["type": "string", "description": "Text to find and replace"],
                    "new_string": ["type": "string", "description": "Replacement text"]
                ],
                "required": ["path", "old_string", "new_string"]
            ]
        ],
        [
            "name": "list_directory",
            "description": "List files and directories at the specified path",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "Absolute path to the directory"],
                    "recursive": ["type": "boolean", "description": "Whether to list recursively"]
                ],
                "required": ["path"]
            ]
        ],
        [
            "name": "search_files",
            "description": "Search for files matching a pattern using glob",
            "input_schema": [
                "type": "object",
                "properties": [
                    "pattern": ["type": "string", "description": "Glob pattern like *.swift or **/*.ts"],
                    "path": ["type": "string", "description": "Directory to search in"]
                ],
                "required": ["pattern", "path"]
            ]
        ],
        [
            "name": "search_content",
            "description": "Search for text content in files (like grep)",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "Text or regex to search for"],
                    "path": ["type": "string", "description": "Directory to search in"],
                    "file_pattern": ["type": "string", "description": "Optional file pattern like *.swift"]
                ],
                "required": ["query", "path"]
            ]
        ],
        [
            "name": "run_shell",
            "description": "Execute a shell command and return the output",
            "input_schema": [
                "type": "object",
                "properties": [
                    "command": ["type": "string", "description": "Shell command to execute"],
                    "working_directory": ["type": "string", "description": "Optional working directory"]
                ],
                "required": ["command"]
            ]
        ]
    ]

    // MARK: - Tool Names

    static let localToolNames: Set<String> = [
        "read_file", "write_file", "edit_file",
        "list_directory", "search_files", "search_content",
        "run_shell"
    ]

    static func isLocalTool(_ name: String) -> Bool {
        localToolNames.contains(name)
    }

    // MARK: - Execute Tool

    func execute(tool: String, input: [String: Any]) async -> ToolResult {
        switch tool {
        case "read_file":
            return await readFile(input)
        case "write_file":
            return await writeFile(input)
        case "edit_file":
            return await editFile(input)
        case "list_directory":
            return await listDirectory(input)
        case "search_files":
            return await searchFiles(input)
        case "search_content":
            return await searchContent(input)
        case "run_shell":
            return await runShell(input)
        default:
            return ToolResult(success: false, output: "Unknown local tool: \(tool)")
        }
    }

    // MARK: - File Operations

    private func readFile(_ input: [String: Any]) async -> ToolResult {
        guard let path = input["path"] as? String else {
            return ToolResult(success: false, output: "Missing path parameter")
        }

        let url = URL(fileURLWithPath: path)

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return ToolResult(success: true, output: content)
        } catch {
            return ToolResult(success: false, output: "Error reading file: \(error.localizedDescription)")
        }
    }

    private func writeFile(_ input: [String: Any]) async -> ToolResult {
        guard let path = input["path"] as? String,
              let content = input["content"] as? String else {
            return ToolResult(success: false, output: "Missing path or content parameter")
        }

        let url = URL(fileURLWithPath: path)

        do {
            // Create parent directories if needed
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try content.write(to: url, atomically: true, encoding: .utf8)
            return ToolResult(success: true, output: "File written successfully: \(path)")
        } catch {
            return ToolResult(success: false, output: "Error writing file: \(error.localizedDescription)")
        }
    }

    private func editFile(_ input: [String: Any]) async -> ToolResult {
        guard let path = input["path"] as? String,
              let oldString = input["old_string"] as? String,
              let newString = input["new_string"] as? String else {
            return ToolResult(success: false, output: "Missing path, old_string, or new_string parameter")
        }

        let url = URL(fileURLWithPath: path)

        do {
            var content = try String(contentsOf: url, encoding: .utf8)

            guard content.contains(oldString) else {
                return ToolResult(success: false, output: "old_string not found in file")
            }

            content = content.replacingOccurrences(of: oldString, with: newString)
            try content.write(to: url, atomically: true, encoding: .utf8)

            return ToolResult(success: true, output: "File edited successfully: \(path)")
        } catch {
            return ToolResult(success: false, output: "Error editing file: \(error.localizedDescription)")
        }
    }

    private func listDirectory(_ input: [String: Any]) async -> ToolResult {
        guard let path = input["path"] as? String else {
            return ToolResult(success: false, output: "Missing path parameter")
        }

        let recursive = input["recursive"] as? Bool ?? false
        let url = URL(fileURLWithPath: path)

        do {
            let contents: [URL]
            if recursive {
                contents = try FileManager.default.subpathsOfDirectory(atPath: path)
                    .map { url.appendingPathComponent($0) }
            } else {
                contents = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
            }

            let listing = contents.map { url -> String in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return "\(isDir ? "📁" : "📄") \(url.lastPathComponent)"
            }.joined(separator: "\n")

            return ToolResult(success: true, output: listing.isEmpty ? "(empty directory)" : listing)
        } catch {
            return ToolResult(success: false, output: "Error listing directory: \(error.localizedDescription)")
        }
    }

    private func searchFiles(_ input: [String: Any]) async -> ToolResult {
        guard let pattern = input["pattern"] as? String,
              let path = input["path"] as? String else {
            return ToolResult(success: false, output: "Missing pattern or path parameter")
        }

        // Use find command for glob matching
        let result = await runShellCommand("find \(path) -name '\(pattern)' -type f 2>/dev/null | head -100")
        return result
    }

    private func searchContent(_ input: [String: Any]) async -> ToolResult {
        guard let query = input["query"] as? String,
              let path = input["path"] as? String else {
            return ToolResult(success: false, output: "Missing query or path parameter")
        }

        let filePattern = input["file_pattern"] as? String

        var command = "grep -rn '\(query)' '\(path)'"
        if let pattern = filePattern {
            command += " --include='\(pattern)'"
        }
        command += " 2>/dev/null | head -50"

        let result = await runShellCommand(command)
        return result
    }

    // MARK: - Shell Execution

    private func runShell(_ input: [String: Any]) async -> ToolResult {
        guard let command = input["command"] as? String else {
            return ToolResult(success: false, output: "Missing command parameter")
        }

        let workingDirectory = input["working_directory"] as? String

        return await runShellCommand(command, workingDirectory: workingDirectory)
    }

    private func runShellCommand(_ command: String, workingDirectory: String? = nil) async -> ToolResult {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe

        if let wd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: wd)
        }

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return ToolResult(success: true, output: output.isEmpty ? "(no output)" : output)
            } else {
                return ToolResult(success: false, output: "Exit code \(process.terminationStatus): \(output)")
            }
        } catch {
            return ToolResult(success: false, output: "Error running command: \(error.localizedDescription)")
        }
    }
}

// MARK: - Tool Result

struct ToolResult {
    let success: Bool
    let output: String

    var asJSON: String {
        let escaped = output
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")

        if success {
            return "{\"result\": \"\(escaped)\"}"
        } else {
            return "{\"error\": \"\(escaped)\"}"
        }
    }
}
