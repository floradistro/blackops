import SwiftUI

// MARK: - MCP Editor View
// Create and edit MCP servers/tools

struct MCPEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editor = MCPEditor()

    let server: MCPServer?
    let onSave: () -> Void

    init(server: MCPServer? = nil, onSave: @escaping () -> Void) {
        self.server = server
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header
                headerSection

                Divider()

                // Basic Info
                basicInfoSection

                Divider()

                // Execution Settings
                executionSection

                Divider()

                // Definition Editor
                definitionSection

                Divider()

                // Actions
                actionsSection
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
        .onAppear {
            if let server = server {
                editor.load(server)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Image(systemName: server == nil ? "plus.circle.fill" : "pencil.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.blue)

            Text(server == nil ? "Create MCP Server" : "Edit MCP Server")
                .font(.system(size: 20, weight: .semibold))

            Spacer()
        }
    }

    // MARK: - Basic Info

    @ViewBuilder
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Basic Information")
                .font(.system(size: 16, weight: .semibold))

            FormField(label: "Name", required: true) {
                TextField("tool_name", text: $editor.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }

            FormField(label: "Category", required: true) {
                HStack {
                    TextField("inventory", text: $editor.category)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))

                    Menu {
                        ForEach(["inventory", "orders", "customers", "products", "analytics", "admin", "browser", "build", "email"], id: \.self) { cat in
                            Button(cat) { editor.category = cat }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                    }
                }
            }

            FormField(label: "Description", required: false) {
                TextEditor(text: $editor.description)
                    .font(.system(size: 12))
                    .frame(height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
            }

            FormField(label: "Tool Mode", required: true) {
                Picker("", selection: $editor.toolMode) {
                    Text("ops").tag("ops")
                    Text("agentic").tag("agentic")
                    Text("auto").tag("auto")
                    Text("both").tag("both")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Execution

    @ViewBuilder
    private var executionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Execution Settings")
                .font(.system(size: 16, weight: .semibold))

            FormField(label: "RPC Function", required: false) {
                TextField("function_name_ai", text: $editor.rpcFunction)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }

            FormField(label: "Edge Function", required: false) {
                TextField("tools-gateway", text: $editor.edgeFunction)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Toggle("Requires User ID", isOn: $editor.requiresUserId)
                    .font(.system(size: 13))

                Toggle("Requires Store ID", isOn: $editor.requiresStoreId)
                    .font(.system(size: 13))

                Toggle("Read Only", isOn: $editor.isReadOnly)
                    .font(.system(size: 13))

                Toggle("Active", isOn: $editor.isActive)
                    .font(.system(size: 13))
            }
        }
    }

    // MARK: - Definition

    @ViewBuilder
    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Tool Definition (JSON)")
                .font(.system(size: 16, weight: .semibold))

            Text("Provide the complete tool definition in JSON format")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextEditor(text: $editor.definitionJSON)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 300)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))

            HStack {
                Button("Validate JSON", action: validateJSON)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button("Format", action: formatJSON)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Spacer()

                if editor.jsonValidationError != nil {
                    Label("Invalid JSON", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                } else if editor.jsonValidated {
                    Label("Valid JSON", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                }
            }

            if let error = editor.jsonValidationError {
                Text(error)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.red)
                    .padding(DesignSystem.Spacing.sm)
                    .background(VisualEffectBackground(material: .sidebar))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsSection: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: save) {
                Text(server == nil ? "Create Server" : "Save Changes")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!editor.isValid || editor.isSaving)

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Spacer()

            if editor.isSaving {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Actions

    private func validateJSON() {
        editor.validateJSON()
    }

    private func formatJSON() {
        editor.formatJSON()
    }

    private func save() {
        Task {
            if await editor.save() {
                onSave()
                dismiss()
            }
        }
    }
}

// MARK: - Form Field

struct FormField<Content: View>: View {
    let label: String
    let required: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))

                if required {
                    Text("*")
                        .foregroundStyle(.red)
                }
            }

            content()
        }
    }
}
