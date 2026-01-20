import SwiftUI

// MARK: - MCP Test View
// Interactive testing interface for MCP servers

struct MCPTestView: View {
    let server: MCPServer
    @StateObject private var testRunner = MCPTestRunner()
    @State private var parameters: [String: String] = [:]
    @State private var showResults = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header
                headerSection

                Divider()

                // Parameter Input
                if let schema = server.definition.inputSchema,
                   let properties = schema.properties {
                    parameterInputSection(properties: properties, required: schema.required ?? [])
                    Divider()
                }

                // Test Controls
                testControlsSection

                // Results
                if showResults {
                    Divider()
                    resultsSection
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "testtube.2")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Test: \(server.name)")
                        .font(.system(size: 18, weight: .semibold))

                    if let desc = server.description {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: DesignSystem.Spacing.xs) {
                if let rpc = server.rpcFunction {
                    InfoChip(label: "RPC", value: rpc, icon: "function")
                }
                if let edge = server.edgeFunction {
                    InfoChip(label: "Edge", value: edge, icon: "cloud")
                }
                InfoChip(label: "Category", value: server.category, icon: "folder")
            }
        }
    }

    // MARK: - Parameter Input

    @ViewBuilder
    private func parameterInputSection(properties: [String: PropertyDefinition], required: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Parameters")
                .font(.system(size: 16, weight: .semibold))

            ForEach(Array(properties.keys.sorted()), id: \.self) { key in
                if let property = properties[key] {
                    parameterField(key: key, property: property, isRequired: required.contains(key))
                }
            }
        }
    }

    @ViewBuilder
    private func parameterField(key: String, property: PropertyDefinition, isRequired: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(key)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))

                if isRequired {
                    Text("required")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(3)
                }

                Spacer()

                Text(property.type)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let description = property.description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if let enumValues = property.enum {
                Picker("", selection: Binding(
                    get: { parameters[key] ?? "" },
                    set: { parameters[key] = $0 }
                )) {
                    Text("Select...").tag("")
                    ForEach(enumValues, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                .pickerStyle(.menu)
            } else {
                TextField(property.default?.stringValue ?? "Enter \(key)", text: Binding(
                    get: { parameters[key] ?? "" },
                    set: { parameters[key] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(6)
    }

    // MARK: - Test Controls

    @ViewBuilder
    private var testControlsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Actions")
                .font(.system(size: 16, weight: .semibold))

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(testRunner.isRunning ? "Running..." : "Execute Test", action: executeTest)
                    .buttonStyle(.borderedProminent)
                    .disabled(testRunner.isRunning)

                Button("Clear") {
                    parameters.removeAll()
                }
                .buttonStyle(.bordered)

                Button("Load Example", action: loadExample)
                    .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Results")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                if let result = testRunner.lastResult {
                    StatusBadge(
                        text: result.success ? "Success" : "Failed",
                        color: result.success ? .green : .red
                    )

                    if let duration = result.duration {
                        Text("\(String(format: "%.2f", duration))s")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let result = testRunner.lastResult {
                ScrollView {
                    Text(result.output)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                .padding(DesignSystem.Spacing.sm)
                .background(VisualEffectBackground(material: .sidebar))
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Actions

    private func executeTest() {
        showResults = true
        Task {
            await testRunner.execute(server: server, parameters: parameters)
        }
    }

    private func loadExample() {
        // TODO: Load example from ai_tool_examples table
        if let schema = server.definition.inputSchema,
           let properties = schema.properties {
            for (key, property) in properties {
                if let defaultValue = property.default {
                    parameters[key] = defaultValue.stringValue
                }
            }
        }
    }
}

// MARK: - Info Chip

struct InfoChip: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text("\(label): \(value)")
                .font(.system(size: 10, design: .monospaced))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(4)
    }
}
