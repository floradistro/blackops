import Foundation

// MARK: - EditorStore + User Tools & Triggers
// Extension for managing custom user-created tools and their triggers

extension EditorStore {

    // MARK: - Load User Tools

    @MainActor
    func loadUserTools() async {
        guard let storeId = selectedStore?.id else { return }

        do {
            let tools: [UserTool] = try await SupabaseService.shared.adminClient
                .from("user_tools")
                .select()
                .eq("store_id", value: storeId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.userTools = tools
            print("[EditorStore] Loaded \(tools.count) user tools")
        } catch is CancellationError {
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            self.error = "Failed to load user tools: \(error.localizedDescription)"
            self.showError = true
        }
    }

    // MARK: - Load User Triggers

    @MainActor
    func loadUserTriggers() async {
        guard let storeId = selectedStore?.id else { return }

        do {
            let triggers: [UserTrigger] = try await SupabaseService.shared.adminClient
                .from("user_triggers")
                .select()
                .eq("store_id", value: storeId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.userTriggers = triggers
            print("[EditorStore] Loaded \(triggers.count) user triggers")
        } catch is CancellationError {
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            self.error = "Failed to load user triggers: \(error.localizedDescription)"
            self.showError = true
        }
    }

    // MARK: - Create User Tool

    @MainActor
    func createUserTool(_ tool: UserTool) async -> UserTool? {
        do {
            let created: UserTool = try await SupabaseService.shared.adminClient
                .from("user_tools")
                .insert(tool)
                .select()
                .single()
                .execute()
                .value

            self.userTools.insert(created, at: 0)
            print("[EditorStore] Created user tool: \(created.name)")
            return created
        } catch {
            self.error = "Failed to create tool: \(error.localizedDescription)"
            self.showError = true
            return nil
        }
    }

    // MARK: - Update User Tool

    @MainActor
    func updateUserTool(_ tool: UserTool) async -> Bool {
        do {
            try await SupabaseService.shared.adminClient
                .from("user_tools")
                .update(tool)
                .eq("id", value: tool.id.uuidString)
                .execute()

            if let index = userTools.firstIndex(where: { $0.id == tool.id }) {
                userTools[index] = tool
            }
            print("[EditorStore] Updated user tool: \(tool.name)")
            return true
        } catch {
            self.error = "Failed to update tool: \(error.localizedDescription)"
            self.showError = true
            return false
        }
    }

    // MARK: - Delete User Tool

    @MainActor
    func deleteUserTool(_ tool: UserTool) async -> Bool {
        do {
            try await SupabaseService.shared.adminClient
                .from("user_tools")
                .delete()
                .eq("id", value: tool.id.uuidString)
                .execute()

            userTools.removeAll { $0.id == tool.id }
            // Also remove any triggers for this tool
            userTriggers.removeAll { $0.toolId == tool.id }
            print("[EditorStore] Deleted user tool: \(tool.name)")
            return true
        } catch {
            self.error = "Failed to delete tool: \(error.localizedDescription)"
            self.showError = true
            return false
        }
    }

    // MARK: - Create User Trigger

    @MainActor
    func createUserTrigger(_ trigger: UserTrigger) async -> UserTrigger? {
        do {
            let created: UserTrigger = try await SupabaseService.shared.adminClient
                .from("user_triggers")
                .insert(trigger)
                .select()
                .single()
                .execute()
                .value

            self.userTriggers.insert(created, at: 0)
            print("[EditorStore] Created user trigger: \(created.name)")
            return created
        } catch {
            self.error = "Failed to create trigger: \(error.localizedDescription)"
            self.showError = true
            return nil
        }
    }

    // MARK: - Update User Trigger

    @MainActor
    func updateUserTrigger(_ trigger: UserTrigger) async -> Bool {
        do {
            try await SupabaseService.shared.adminClient
                .from("user_triggers")
                .update(trigger)
                .eq("id", value: trigger.id.uuidString)
                .execute()

            if let index = userTriggers.firstIndex(where: { $0.id == trigger.id }) {
                userTriggers[index] = trigger
            }
            print("[EditorStore] Updated user trigger: \(trigger.name)")
            return true
        } catch {
            self.error = "Failed to update trigger: \(error.localizedDescription)"
            self.showError = true
            return false
        }
    }

    // MARK: - Delete User Trigger

    @MainActor
    func deleteUserTrigger(_ trigger: UserTrigger) async -> Bool {
        do {
            try await SupabaseService.shared.adminClient
                .from("user_triggers")
                .delete()
                .eq("id", value: trigger.id.uuidString)
                .execute()

            userTriggers.removeAll { $0.id == trigger.id }
            print("[EditorStore] Deleted user trigger: \(trigger.name)")
            return true
        } catch {
            self.error = "Failed to delete trigger: \(error.localizedDescription)"
            self.showError = true
            return false
        }
    }

    // MARK: - Test User Tool

    @MainActor
    func testUserTool(_ tool: UserTool, args: [String: Any]) async -> TestResult {
        let startTime = Date()

        // Execute based on tool type
        switch tool.executionType {
        case .http:
            let httpResult = await executeHTTPTool(tool, input: args)
            let result = TestResult(
                success: httpResult.success,
                output: httpResult.data.map { AnyCodable($0) },
                error: httpResult.error,
                executionTimeMs: httpResult.durationMs,
                testedAt: Date()
            )

            // Update the tool with test result
            var updatedTool = tool
            updatedTool.isTested = true
            updatedTool.testResult = result
            _ = await updateUserTool(updatedTool)

            return result

        case .rpc:
            // Execute RPC function
            guard let rpcFunction = tool.rpcFunction, let storeId = selectedStore?.id else {
                return TestResult(success: false, error: "No RPC function configured", testedAt: Date())
            }

            do {
                struct RPCParams: Encodable {
                    let p_store_id: String
                    let p_args: [String: AnyCodable]
                }

                let params = RPCParams(
                    p_store_id: storeId.uuidString,
                    p_args: args.mapValues { AnyCodable($0) }
                )

                let response = try await SupabaseService.shared.adminClient
                    .rpc(rpcFunction, params: params)
                    .execute()

                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                let jsonResult = try? JSONSerialization.jsonObject(with: response.data)

                let result = TestResult(
                    success: true,
                    output: jsonResult.map { AnyCodable($0) },
                    executionTimeMs: duration,
                    testedAt: Date()
                )

                var updatedTool = tool
                updatedTool.isTested = true
                updatedTool.testResult = result
                _ = await updateUserTool(updatedTool)

                return result
            } catch {
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                return TestResult(
                    success: false,
                    error: error.localizedDescription,
                    executionTimeMs: duration,
                    testedAt: Date()
                )
            }

        case .sql:
            // SQL execution would need server-side handling for security
            return TestResult(
                success: false,
                error: "SQL tool testing requires server-side execution",
                testedAt: Date()
            )
        }
    }

    // MARK: - Manually Fire Trigger

    @MainActor
    func fireTrigger(_ trigger: UserTrigger, payload: [String: AnyCodable]?) async -> Bool {
        guard selectedStore?.id != nil else { return false }

        do {
            // Call the enqueue_trigger RPC
            struct EnqueueTriggerParams: Encodable {
                let p_trigger_id: String
                let p_event_payload: [String: AnyCodable]
            }

            let params = EnqueueTriggerParams(
                p_trigger_id: trigger.id.uuidString,
                p_event_payload: payload ?? [:]
            )

            try await SupabaseService.shared.adminClient
                .rpc("enqueue_trigger", params: params)
                .execute()

            print("[EditorStore] Fired trigger: \(trigger.name)")
            return true
        } catch {
            self.error = "Failed to fire trigger: \(error.localizedDescription)"
            self.showError = true
            return false
        }
    }

    // MARK: - Tool Secrets Management

    /// Save a secret for a tool (stored encrypted in database)
    @MainActor
    func saveToolSecret(storeId: UUID, toolId: UUID?, name: String, value: String) async -> Bool {
        do {
            struct UpsertSecretParams: Encodable {
                let p_store_id: String
                let p_tool_id: String?
                let p_name: String
                let p_value: String
            }

            let params = UpsertSecretParams(
                p_store_id: storeId.uuidString,
                p_tool_id: toolId?.uuidString,
                p_name: name,
                p_value: value
            )

            try await SupabaseService.shared.adminClient
                .rpc("upsert_tool_secret", params: params)
                .execute()

            print("[EditorStore] Saved secret: \(name)")
            return true
        } catch {
            self.error = "Failed to save secret: \(error.localizedDescription)"
            self.showError = true
            return false
        }
    }

    /// Save multiple secrets at once
    @MainActor
    func saveToolSecrets(storeId: UUID, toolId: UUID?, secrets: [String: String]) async {
        for (name, value) in secrets where !value.isEmpty {
            _ = await saveToolSecret(storeId: storeId, toolId: toolId, name: name, value: value)
        }
    }

    /// Load secrets for a store (returns names only, not values for security)
    @MainActor
    func loadToolSecretNames(storeId: UUID) async -> [String] {
        do {
            struct SecretRow: Decodable {
                let name: String
            }

            let secrets: [SecretRow] = try await SupabaseService.shared.adminClient
                .from("user_tool_secrets")
                .select("name")
                .eq("store_id", value: storeId.uuidString)
                .execute()
                .value

            return secrets.map { $0.name }
        } catch is CancellationError {
            return []
        } catch let urlError as URLError where urlError.code == .cancelled {
            return []
        } catch {
            self.error = "Failed to load secrets: \(error.localizedDescription)"
            self.showError = true
            return []
        }
    }

    /// Check if a specific secret exists
    @MainActor
    func hasSecret(storeId: UUID, name: String) async -> Bool {
        do {
            struct CountResult: Decodable {
                let count: Int
            }

            let result: [CountResult] = try await SupabaseService.shared.adminClient
                .from("user_tool_secrets")
                .select("count", head: true)
                .eq("store_id", value: storeId.uuidString)
                .eq("name", value: name)
                .execute()
                .value

            return (result.first?.count ?? 0) > 0
        } catch {
            return false
        }
    }

    /// Delete a secret
    @MainActor
    func deleteToolSecret(storeId: UUID, name: String) async -> Bool {
        do {
            try await SupabaseService.shared.adminClient
                .from("user_tool_secrets")
                .delete()
                .eq("store_id", value: storeId.uuidString)
                .eq("name", value: name)
                .execute()

            print("[EditorStore] Deleted secret: \(name)")
            return true
        } catch {
            self.error = "Failed to delete secret: \(error.localizedDescription)"
            self.showError = true
            return false
        }
    }

    // MARK: - Execute HTTP Tool

    /// Execute an HTTP tool with the given input
    @MainActor
    func executeHTTPTool(_ tool: UserTool, input: [String: Any]) async -> HTTPToolResult {
        guard let storeId = selectedStore?.id else {
            return HTTPToolResult(success: false, error: "No store selected")
        }

        guard tool.executionType == .http, let httpConfig = tool.httpConfig else {
            return HTTPToolResult(success: false, error: "Tool is not an HTTP tool")
        }

        // Check if batch processing is needed
        if let batchConfig = httpConfig.batchConfig,
           batchConfig.enabled,
           let inputPath = batchConfig.inputArrayPath,
           let inputArray = input[inputPath] as? [Any] {
            return await executeBatchHTTPTool(tool, items: inputArray, config: httpConfig, batchConfig: batchConfig, storeId: storeId)
        }

        // Single execution
        return await executeSingleHTTPRequest(tool, input: input, config: httpConfig, storeId: storeId)
    }

    /// Execute a single HTTP request
    private func executeSingleHTTPRequest(_ tool: UserTool, input: [String: Any], config: HTTPConfig, storeId: UUID) async -> HTTPToolResult {
        let startTime = Date()

        do {
            // Build the URL
            var urlString = config.url

            // Substitute input variables in URL (e.g., {{shop_domain}})
            for (key, value) in input {
                urlString = urlString.replacingOccurrences(of: "{{\(key)}}", with: "\(value)")
            }

            // Add query params
            if let queryParams = config.queryParams, !queryParams.isEmpty {
                var components = URLComponents(string: urlString)
                var queryItems = components?.queryItems ?? []
                for (key, value) in queryParams {
                    var substituted = value
                    for (inputKey, inputValue) in input {
                        substituted = substituted.replacingOccurrences(of: "{{\(inputKey)}}", with: "\(inputValue)")
                    }
                    // Skip secret placeholders - those are injected server-side
                    if !substituted.contains("{{") {
                        queryItems.append(URLQueryItem(name: key, value: substituted))
                    }
                }
                components?.queryItems = queryItems.isEmpty ? nil : queryItems
                urlString = components?.string ?? urlString
            }

            guard let url = URL(string: urlString) else {
                return HTTPToolResult(success: false, error: "Invalid URL: \(urlString)")
            }

            // Build request
            var request = URLRequest(url: url)
            request.httpMethod = config.method.rawValue
            request.timeoutInterval = TimeInterval(tool.maxExecutionTimeMs) / 1000.0

            // Add headers (substitute input variables, skip secrets)
            if let headers = config.headers {
                for (key, value) in headers {
                    var substituted = value
                    for (inputKey, inputValue) in input {
                        substituted = substituted.replacingOccurrences(of: "{{\(inputKey)}}", with: "\(inputValue)")
                    }
                    // For secrets, we need to fetch from database
                    if substituted.contains("{{") {
                        // Extract secret name
                        if let range = substituted.range(of: "\\{\\{([A-Z_]+)\\}\\}", options: .regularExpression) {
                            let secretName = String(substituted[range]).replacingOccurrences(of: "{{", with: "").replacingOccurrences(of: "}}", with: "")
                            if let secretValue = await fetchSecret(storeId: storeId, name: secretName) {
                                substituted = substituted.replacingOccurrences(of: "{{\(secretName)}}", with: secretValue)
                            }
                        }
                    }
                    request.setValue(substituted, forHTTPHeaderField: key)
                }
            }

            // Build body for POST/PUT/PATCH
            if config.method != .GET, let bodyTemplate = config.bodyTemplate {
                var body: [String: Any] = [:]
                for (key, value) in bodyTemplate {
                    if let stringValue = value.value as? String {
                        var substituted = stringValue
                        for (inputKey, inputValue) in input {
                            substituted = substituted.replacingOccurrences(of: "{{\(inputKey)}}", with: "\(inputValue)")
                        }
                        body[key] = substituted
                    } else {
                        body[key] = value.value
                    }
                }
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }

            // Execute request
            let (data, response) = try await URLSession.shared.data(for: request)

            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            let duration = Date().timeIntervalSince(startTime)

            // Parse response
            let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

            // Check for error based on status code
            if statusCode >= 400 {
                let errorMessage = extractError(from: jsonResponse, mapping: config.responseMapping) ?? "HTTP \(statusCode)"
                return HTTPToolResult(
                    success: false,
                    data: jsonResponse,
                    error: errorMessage,
                    statusCode: statusCode,
                    durationMs: Int(duration * 1000)
                )
            }

            // Extract result using response mapping
            let result = extractResult(from: jsonResponse, mapping: config.responseMapping)

            return HTTPToolResult(
                success: true,
                data: result ?? jsonResponse,
                statusCode: statusCode,
                durationMs: Int(duration * 1000)
            )

        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return HTTPToolResult(
                success: false,
                error: error.localizedDescription,
                durationMs: Int(duration * 1000)
            )
        }
    }

    /// Execute batch HTTP requests
    private func executeBatchHTTPTool(_ tool: UserTool, items: [Any], config: HTTPConfig, batchConfig: BatchConfig, storeId: UUID) async -> HTTPToolResult {
        let startTime = Date()
        var results: [[String: Any]] = []
        var errors: [String] = []
        var successCount = 0

        // Process items with controlled concurrency
        let maxConcurrent = batchConfig.maxConcurrent
        let delayMs = batchConfig.delayBetweenMs

        // Process in chunks to control concurrency
        for chunkStart in stride(from: 0, to: items.count, by: maxConcurrent) {
            let chunkEnd = min(chunkStart + maxConcurrent, items.count)
            let chunk = Array(items[chunkStart..<chunkEnd])

            // Process chunk concurrently
            await withTaskGroup(of: (Int, HTTPToolResult).self) { group in
                for (offsetIndex, item) in chunk.enumerated() {
                    let globalIndex = chunkStart + offsetIndex

                    group.addTask {
                        // Add delay between requests within chunk
                        if offsetIndex > 0 && delayMs > 0 {
                            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                        }

                        // Build input for this item
                        var itemInput: [String: Any]
                        if let dict = item as? [String: Any] {
                            itemInput = dict
                        } else {
                            // Single value - use the first property from body template as key
                            let key = config.bodyTemplate?.keys.first ?? "input"
                            itemInput = [key: item]
                        }

                        let result = await self.executeSingleHTTPRequest(tool, input: itemInput, config: config, storeId: storeId)
                        return (globalIndex, result)
                    }
                }

                for await (index, result) in group {
                    if result.success {
                        successCount += 1
                        if let data = result.data {
                            results.append(["index": index, "data": data])
                        }
                    } else {
                        if !batchConfig.continueOnError {
                            group.cancelAll()
                        }
                        errors.append("Item \(index): \(result.error ?? "Unknown error")")
                    }
                }
            }

            // Early exit if we hit an error and shouldn't continue
            if !errors.isEmpty && !batchConfig.continueOnError {
                break
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        return HTTPToolResult(
            success: errors.isEmpty || batchConfig.continueOnError,
            data: [
                "results": results,
                "total": items.count,
                "succeeded": successCount,
                "failed": errors.count
            ],
            error: errors.isEmpty ? nil : errors.joined(separator: "; "),
            durationMs: Int(duration * 1000)
        )
    }

    /// Fetch a secret value from the database
    private func fetchSecret(storeId: UUID, name: String) async -> String? {
        do {
            struct SecretRow: Decodable {
                let encrypted_value: String
            }

            let secrets: [SecretRow] = try await SupabaseService.shared.adminClient
                .from("user_tool_secrets")
                .select("encrypted_value")
                .eq("store_id", value: storeId.uuidString)
                .eq("name", value: name)
                .limit(1)
                .execute()
                .value

            return secrets.first?.encrypted_value
        } catch {
            print("[EditorStore] Failed to fetch secret \(name): \(error)")
            return nil  // Silent failure — secrets are fetched during HTTP tool execution
        }
    }

    /// Extract result using JSONPath-like mapping
    private func extractResult(from json: [String: Any]?, mapping: ResponseMapping?) -> Any? {
        guard let json = json, let path = mapping?.resultPath, !path.isEmpty else {
            return json
        }
        return extractValue(from: json, path: path)
    }

    /// Extract error using JSONPath-like mapping
    private func extractError(from json: [String: Any]?, mapping: ResponseMapping?) -> String? {
        guard let json = json, let path = mapping?.errorPath, !path.isEmpty else {
            return nil
        }
        if let value = extractValue(from: json, path: path) {
            return "\(value)"
        }
        return nil
    }

    /// Simple JSONPath extractor (supports "key.subkey" and "key[0]" syntax)
    private func extractValue(from json: Any, path: String) -> Any? {
        let components = path.components(separatedBy: ".")
        var current: Any = json

        for component in components {
            // Check for array index syntax: key[0]
            if let bracketRange = component.range(of: "["),
               let closeBracket = component.range(of: "]") {
                let key = String(component[..<bracketRange.lowerBound])
                let indexStr = String(component[bracketRange.upperBound..<closeBracket.lowerBound])

                if !key.isEmpty {
                    guard let dict = current as? [String: Any], let value = dict[key] else {
                        return nil
                    }
                    current = value
                }

                if let index = Int(indexStr), let array = current as? [Any], index < array.count {
                    current = array[index]
                } else {
                    return nil
                }
            } else {
                guard let dict = current as? [String: Any], let value = dict[component] else {
                    return nil
                }
                current = value
            }
        }

        return current
    }
}

// MARK: - HTTP Tool Result

struct HTTPToolResult {
    let success: Bool
    var data: Any?
    var error: String?
    var statusCode: Int?
    var durationMs: Int?

    init(success: Bool, data: Any? = nil, error: String? = nil, statusCode: Int? = nil, durationMs: Int? = nil) {
        self.success = success
        self.data = data
        self.error = error
        self.statusCode = statusCode
        self.durationMs = durationMs
    }
}

