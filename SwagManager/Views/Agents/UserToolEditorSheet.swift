import SwiftUI

// MARK: - User Tool Editor Sheet

struct UserToolEditorSheet: View {
    @Environment(\.editorStore) private var store
    let tool: UserTool?
    @Environment(\.dismiss) private var dismiss

    // Basic Info
    @State private var name = ""
    @State private var displayName = ""
    @State private var description = ""
    @State private var category = "custom"
    @State private var icon = "wrench.fill"

    // Execution
    @State private var executionType: UserTool.ExecutionType = .rpc
    @State private var rpcFunction = ""
    @State private var httpUrl = ""
    @State private var httpMethod: HTTPConfig.HTTPMethod = .GET
    @State private var httpHeaders: [String: String] = [:]
    @State private var sqlTemplate = ""
    @State private var selectedTables: Set<String> = []

    // API Secrets
    @State private var apiSecrets: [String: String] = [:]
    @State private var existingSecretNames: Set<String> = []

    // Batch Config
    @State private var batchEnabled = false
    @State private var batchMaxConcurrent = 5
    @State private var batchDelayMs = 100
    @State private var batchSize = 10
    @State private var batchInputPath = ""
    @State private var batchContinueOnError = true

    // Response Mapping
    @State private var resultPath = ""
    @State private var errorPath = ""

    // Input Parameters
    @State private var inputParameters: [InputParameter] = []
    @State private var showAddParameter = false

    // Settings
    @State private var isReadOnly = true
    @State private var requiresApproval = false
    @State private var isActive = true
    @State private var maxExecutionTimeMs = 5000

    @State private var isSaving = false

    // Available tables for SQL queries (store-scoped tables only)
    private let availableTables = [
        ("orders", "Customer orders"),
        ("order_items", "Line items in orders"),
        ("customers", "Customer profiles"),
        ("customer_loyalty", "Loyalty points & tiers"),
        ("inventory", "Stock levels by location"),
        ("locations", "Store locations"),
        ("carts", "Active shopping carts"),
        ("cart_items", "Items in carts")
    ]

    private let icons = [
        "wrench.fill", "function", "network", "tablecells", "gear",
        "bolt.fill", "cube.fill", "doc.text", "chart.bar", "envelope",
        "cart.fill", "person.fill", "shippingbox.fill", "tag.fill"
    ]

    private let categories = [
        ("custom", "Custom"),
        ("orders", "Orders"),
        ("inventory", "Inventory"),
        ("customers", "Customers"),
        ("analytics", "Analytics"),
        ("notifications", "Notifications")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sheetHeader

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    basicInfoSection
                    executionTypeSection
                    if executionType == .http {
                        batchConfigSection
                    }
                    inputParametersSection
                    settingsSection
                }
                .padding(24)
            }

            Divider()

            // Footer
            sheetFooter
        }
        .frame(width: 600, height: 700)
        .onAppear { loadTool() }
        .task {
            // Load existing secret names
            if let storeId = store.selectedStore?.id {
                let names = await store.loadToolSecretNames(storeId: storeId)
                existingSecretNames = Set(names)
            }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Text(tool == nil ? "NEW" : "EDIT")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text("Tool")
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
            Spacer()
            Button("Close") { dismiss() }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Basic Info

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BASIC INFO")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Icon picker - minimal
                    Menu {
                        ForEach(icons, id: \.self) { iconName in
                            Button {
                                icon = iconName
                            } label: {
                                Label(iconName, systemImage: iconName)
                            }
                        }
                    } label: {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color.primary.opacity(0.04))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(.plain)
                            .font(.system(.body, weight: .medium))
                            .padding(8)
                            .background(Color.primary.opacity(0.03))

                        TextField("internal_name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.primary.opacity(0.03))
                            .disableAutocorrection(true)
                    }
                }

                TextField("Description", text: $description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(.caption))
                    .lineLimit(2...3)
                    .padding(8)
                    .background(Color.primary.opacity(0.03))

                HStack {
                    Text("Category")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $category) {
                        ForEach(categories, id: \.0) { id, name in
                            Text(name).tag(id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
    }

    // MARK: - Execution Type

    private var executionTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXECUTION")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(UserTool.ExecutionType.allCases, id: \.self) { type in
                        Button {
                            executionType = type
                        } label: {
                            Text(type.displayName)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(executionType == type ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
                                .foregroundStyle(executionType == type ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                switch executionType {
                case .rpc:
                    rpcConfigSection
                case .http:
                    httpConfigSection
                case .sql:
                    sqlConfigSection
                }
            }
        }
    }

    private var rpcConfigSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("function_name", text: $rpcFunction)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .background(Color.primary.opacity(0.03))
                .autocorrectionDisabled()

            Text("RPC receives (p_store_id UUID, p_args JSONB). store_id auto-injected.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    private var httpConfigSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // URL & Method
            VStack(alignment: .leading, spacing: 8) {
                TextField("https://api.example.com/endpoint", text: $httpUrl)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .background(Color.primary.opacity(0.03))
                    .autocorrectionDisabled()

                HStack(spacing: 4) {
                    ForEach(HTTPConfig.HTTPMethod.allCases, id: \.self) { method in
                        Button {
                            httpMethod = method
                        } label: {
                            Text(method.rawValue)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(httpMethod == method ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
                                .foregroundStyle(httpMethod == method ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Response Mapping
            responseMappingSection

            Text("Server-side execution. Secrets encrypted, injected via {{SECRET_NAME}}.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    private var responseMappingSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("result")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                    TextField("data.url", text: $resultPath)
                        .textFieldStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .padding(6)
                        .background(Color.primary.opacity(0.03))
                }

                HStack(spacing: 8) {
                    Text("error")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                    TextField("error.message", text: $errorPath)
                        .textFieldStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .padding(6)
                        .background(Color.primary.opacity(0.03))
                }
            }
            .padding(.top, 6)
        } label: {
            Text("RESPONSE MAPPING")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Batch Config Section

    private var batchConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("BATCH")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Toggle("", isOn: $batchEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }

            if batchEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("concurrent")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Stepper("\(batchMaxConcurrent)", value: $batchMaxConcurrent, in: 1...20)
                                .frame(width: 90)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("delay ms")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Stepper("\(batchDelayMs)", value: $batchDelayMs, in: 0...5000, step: 50)
                                .frame(width: 90)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("batch size")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Stepper("\(batchSize)", value: $batchSize, in: 1...100)
                                .frame(width: 90)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("input array path")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        TextField("image_urls, prompts, recipients", text: $batchInputPath)
                            .textFieldStyle(.plain)
                            .font(.system(.caption, design: .monospaced))
                            .padding(6)
                            .background(Color.primary.opacity(0.03))
                    }

                    Toggle("continue on failure", isOn: $batchContinueOnError)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Process multiple items in a single call")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var sqlConfigSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Table selector
            VStack(alignment: .leading, spacing: 6) {
                Text("TABLES")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 4) {
                    ForEach(availableTables, id: \.0) { table, desc in
                        Button {
                            if selectedTables.contains(table) {
                                selectedTables.remove(table)
                            } else {
                                selectedTables.insert(table)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedTables.contains(table) ? "✓" : "○")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(selectedTables.contains(table) ? .primary : .tertiary)
                                Text(table)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(selectedTables.contains(table) ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(selectedTables.contains(table) ? Color.primary.opacity(0.06) : Color.primary.opacity(0.02))
                        }
                        .buttonStyle(.plain)
                        .help(desc)
                    }
                }
            }

            // SQL Editor
            VStack(alignment: .leading, spacing: 6) {
                Text("QUERY")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)

                TextEditor(text: $sqlTemplate)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.primary.opacity(0.03))
            }

            Text("SELECT only. store_id auto-injected. Use $param for inputs.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Input Parameters

    private var inputParametersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("INPUT PARAMETERS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    inputParameters.append(InputParameter(name: "", type: "string", description: "", required: true))
                } label: {
                    Text("+ add")
                        .font(.system(size: 10, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if inputParameters.isEmpty {
                Text("No parameters defined")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach($inputParameters) { $param in
                        InputParameterRow(parameter: $param) {
                            inputParameters.removeAll { $0.id == param.id }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SETTINGS")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)

            VStack(spacing: 8) {
                HStack {
                    Text("read only")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $isReadOnly)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                }
                HStack {
                    Text("requires approval")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $requiresApproval)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                }
                HStack {
                    Text("active")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $isActive)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                }

                Divider()

                HStack {
                    Text("timeout")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    MonoOptionSelector(
                        options: [1000, 5000, 15000, 30000, 60000],
                        selection: $maxExecutionTimeMs,
                        labels: [1000: "1s", 5000: "5s", 15000: "15s", 30000: "30s", 60000: "60s"]
                    )
                }
            }
        }
    }

    // MARK: - Footer

    private var sheetFooter: some View {
        HStack {
            if tool != nil {
                Button("Delete") {
                    // Handle delete
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }

            Spacer()

            if isSaving {
                Text("saving...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Button(tool == nil ? "Create" : "Save") {
                Task { await saveTool() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!isValid || isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Validation

    private var isValid: Bool {
        guard !name.isEmpty, !displayName.isEmpty else { return false }

        switch executionType {
        case .rpc:
            return !rpcFunction.isEmpty
        case .http:
            return !httpUrl.isEmpty
        case .sql:
            return !sqlTemplate.isEmpty && !selectedTables.isEmpty
        }
    }

    // MARK: - Load/Save

    private func loadTool() {
        guard let tool = tool else { return }
        name = tool.name
        displayName = tool.displayName
        description = tool.description
        category = tool.category
        icon = tool.icon
        executionType = tool.executionType
        rpcFunction = tool.rpcFunction ?? ""
        if let config = tool.httpConfig {
            httpUrl = config.url
            httpMethod = config.method
            httpHeaders = config.headers ?? [:]

            // Load batch config
            if let batch = config.batchConfig {
                batchEnabled = batch.enabled
                batchMaxConcurrent = batch.maxConcurrent
                batchDelayMs = batch.delayBetweenMs
                batchSize = batch.batchSize
                batchInputPath = batch.inputArrayPath ?? ""
                batchContinueOnError = batch.continueOnError
            }

            // Load response mapping
            if let mapping = config.responseMapping {
                resultPath = mapping.resultPath ?? ""
                errorPath = mapping.errorPath ?? ""
            }

        }
        sqlTemplate = tool.sqlTemplate ?? ""
        selectedTables = Set(tool.allowedTables ?? [])
        isReadOnly = tool.isReadOnly
        requiresApproval = tool.requiresApproval
        isActive = tool.isActive
        maxExecutionTimeMs = tool.maxExecutionTimeMs

        // Load input parameters from schema
        if let schema = tool.inputSchema, let props = schema.properties {
            inputParameters = props.map { key, value in
                InputParameter(
                    name: key,
                    type: value.type,
                    description: value.description ?? "",
                    required: schema.required?.contains(key) ?? false
                )
            }
        }
    }

    private func saveTool() async {
        guard let storeId = store.selectedStore?.id else { return }
        isSaving = true

        // Save secrets first (if any)
        if executionType == .http && !apiSecrets.isEmpty {
            await store.saveToolSecrets(storeId: storeId, toolId: tool?.id, secrets: apiSecrets)
        }

        var newTool = tool ?? UserTool(storeId: storeId)
        newTool.name = name.lowercased().replacingOccurrences(of: " ", with: "_")
        newTool.displayName = displayName
        newTool.description = description
        newTool.category = category
        newTool.icon = icon
        newTool.executionType = executionType
        newTool.isReadOnly = isReadOnly
        newTool.requiresApproval = requiresApproval
        newTool.isActive = isActive
        newTool.maxExecutionTimeMs = maxExecutionTimeMs

        // Build input schema
        if !inputParameters.isEmpty {
            var properties: [String: PropertySchema] = [:]
            var required: [String] = []
            for param in inputParameters {
                properties[param.name] = PropertySchema(type: param.type, description: param.description)
                if param.required {
                    required.append(param.name)
                }
            }
            newTool.inputSchema = InputSchema(type: "object", properties: properties, required: required.isEmpty ? nil : required)
        } else {
            newTool.inputSchema = nil
        }

        switch executionType {
        case .rpc:
            newTool.rpcFunction = rpcFunction
            newTool.httpConfig = nil
            newTool.sqlTemplate = nil
            newTool.allowedTables = nil
        case .http:
            // Build batch config if enabled
            let batchConfig: BatchConfig? = batchEnabled ? BatchConfig(
                enabled: true,
                maxConcurrent: batchMaxConcurrent,
                delayBetweenMs: batchDelayMs,
                batchSize: batchSize,
                inputArrayPath: batchInputPath.isEmpty ? nil : batchInputPath,
                retryOnFailure: true,
                continueOnError: batchContinueOnError
            ) : nil

            // Build response mapping if configured
            let responseMapping: ResponseMapping? = (!resultPath.isEmpty || !errorPath.isEmpty) ? ResponseMapping(
                resultPath: resultPath.isEmpty ? nil : resultPath,
                errorPath: errorPath.isEmpty ? nil : errorPath
            ) : nil

            newTool.httpConfig = HTTPConfig(
                url: httpUrl,
                method: httpMethod,
                headers: httpHeaders.isEmpty ? nil : httpHeaders,
                batchConfig: batchConfig,
                responseMapping: responseMapping
            )
            newTool.rpcFunction = nil
            newTool.sqlTemplate = nil
            newTool.allowedTables = nil
        case .sql:
            newTool.sqlTemplate = sqlTemplate
            newTool.allowedTables = Array(selectedTables)
            newTool.rpcFunction = nil
            newTool.httpConfig = nil
        }

        if tool == nil {
            _ = await store.createUserTool(newTool)
        } else {
            _ = await store.updateUserTool(newTool)
        }

        isSaving = false
        dismiss()
    }
}

// MARK: - Input Parameter Model

struct InputParameter: Identifiable {
    let id = UUID()
    var name: String
    var type: String
    var description: String
    var required: Bool
}

// MARK: - Input Parameter Row

struct InputParameterRow: View {
    @Binding var parameter: InputParameter
    let onDelete: () -> Void

    private let types = ["string", "number", "boolean", "array"]

    var body: some View {
        HStack(spacing: 8) {
            TextField("name", text: $parameter.name)
                .textFieldStyle(.plain)
                .font(.system(.caption, design: .monospaced))
                .padding(6)
                .background(Color.primary.opacity(0.03))
                .frame(width: 90)

            Picker("", selection: $parameter.type) {
                ForEach(types, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 75)

            TextField("description", text: $parameter.description)
                .textFieldStyle(.plain)
                .font(.system(.caption, design: .monospaced))
                .padding(6)
                .background(Color.primary.opacity(0.03))

            Text(parameter.required ? "req" : "opt")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(parameter.required ? .primary : .tertiary)
                .onTapGesture { parameter.required.toggle() }

            Button { onDelete() } label: {
                Text("×")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color.primary.opacity(0.02))
    }
}
