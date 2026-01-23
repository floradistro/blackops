import SwiftUI

// MARK: - Agent Config Sheet
// Unified sheet for viewing/editing AI agents - works for existing and new agents
// Simple, Apple-like design

struct AgentConfigSheet: View {
    @ObservedObject var store: EditorStore
    let agent: AIAgent?  // nil = creating new agent
    @Environment(\.dismiss) private var dismiss

    // Editable state
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var systemPrompt: String = ""
    @State private var model: String = "claude-sonnet-4-20250514"
    @State private var maxTokens: Int = 32000
    @State private var maxToolCalls: Int = 200
    @State private var icon: String = "sparkles"
    @State private var accentColor: String = "blue"
    @State private var isActive: Bool = true

    @State private var isSaving = false
    @State private var showingIconPicker = false

    private var isNewAgent: Bool { agent == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with icon
                    agentHeader

                    Divider()

                    // Basic Info
                    configSection("Identity") {
                        configField("Name") {
                            TextField("Agent name", text: $name)
                                .textFieldStyle(.plain)
                        }

                        configField("Description") {
                            TextField("Brief description", text: $description)
                                .textFieldStyle(.plain)
                        }

                        configField("Icon") {
                            HStack {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)

                                Picker("", selection: $icon) {
                                    Label("Sparkles", systemImage: "sparkles").tag("sparkles")
                                    Label("Brain", systemImage: "brain.head.profile").tag("brain.head.profile")
                                    Label("CPU", systemImage: "cpu").tag("cpu")
                                    Label("Message", systemImage: "message").tag("message")
                                    Label("Person", systemImage: "person.circle").tag("person.circle")
                                    Label("Wand", systemImage: "wand.and.stars").tag("wand.and.stars")
                                    Label("Gear", systemImage: "gearshape").tag("gearshape")
                                    Label("Chart", systemImage: "chart.bar").tag("chart.bar")
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                        }

                        configField("Status") {
                            Toggle("Active", isOn: $isActive)
                                .toggleStyle(.switch)
                        }
                    }

                    Divider()

                    // Model Configuration
                    configSection("Model") {
                        configField("Model") {
                            Picker("", selection: $model) {
                                Text("Claude Opus 4.5").tag("claude-opus-4-5-20251101")
                                Text("Claude Sonnet 4").tag("claude-sonnet-4-20250514")
                                Text("Claude Haiku 3.5").tag("claude-3-5-haiku-20241022")
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }

                        configField("Max Tokens") {
                            HStack {
                                TextField("", value: $maxTokens, format: .number)
                                    .textFieldStyle(.plain)
                                    .frame(width: 80)

                                Stepper("", value: $maxTokens, in: 1000...128000, step: 1000)
                                    .labelsHidden()
                            }
                        }

                        configField("Max Tool Calls") {
                            HStack {
                                TextField("", value: $maxToolCalls, format: .number)
                                    .textFieldStyle(.plain)
                                    .frame(width: 80)

                                Stepper("", value: $maxToolCalls, in: 1...500, step: 10)
                                    .labelsHidden()
                            }
                        }
                    }

                    Divider()

                    // System Prompt
                    configSection("System Prompt") {
                        TextEditor(text: $systemPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 200)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(8)
                    }

                    // Stats (for existing agents)
                    if let agent = agent {
                        Divider()

                        configSection("Info") {
                            HStack {
                                statItem("Version", value: "\(agent.version ?? 1)")
                                Spacer()
                                statItem("Created", value: agent.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                                Spacer()
                                statItem("Updated", value: agent.updatedAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(VisualEffectBackground(material: .sidebar))
            .navigationTitle(isNewAgent ? "New Agent" : name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isNewAgent ? "Create" : "Save") {
                        Task {
                            await saveAgent()
                        }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            loadAgentData()
        }
    }

    // MARK: - Header

    private var agentHeader: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "New Agent" : name)
                    .font(.system(size: 20, weight: .semibold))

                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(model.contains("opus") ? "Opus" : model.contains("haiku") ? "Haiku" : "Sonnet", systemImage: "cpu")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if isActive {
                        Text("Active")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Config Section

    private func configSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
    }

    private func configField(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func statItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Data

    private func loadAgentData() {
        if let agent = agent {
            name = agent.name ?? ""
            description = agent.description ?? ""
            systemPrompt = agent.systemPrompt ?? ""
            model = agent.model ?? "claude-sonnet-4-20250514"
            maxTokens = agent.maxTokens ?? 32000
            maxToolCalls = agent.maxToolCalls ?? 200
            icon = agent.icon ?? "sparkles"
            accentColor = agent.accentColor ?? "blue"
            isActive = agent.isActive
        } else {
            // Defaults for new agent
            name = ""
            description = ""
            systemPrompt = "You are a helpful AI assistant."
            model = "claude-sonnet-4-20250514"
            maxTokens = 32000
            maxToolCalls = 200
            icon = "sparkles"
            accentColor = "blue"
            isActive = true
        }
    }

    private func saveAgent() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let agentId = agent?.id ?? UUID()
            let storeId = store.selectedStore?.id

            // Build the update/insert payload
            struct AgentUpsert: Encodable {
                let id: String
                let store_id: String?
                let name: String
                let description: String?
                let system_prompt: String
                let model: String
                let max_tokens: Int
                let max_tool_calls: Int
                let icon: String
                let accent_color: String
                let is_active: Bool
            }

            let payload = AgentUpsert(
                id: agentId.uuidString.lowercased(),
                store_id: storeId?.uuidString.lowercased(),
                name: name,
                description: description.isEmpty ? nil : description,
                system_prompt: systemPrompt,
                model: model,
                max_tokens: maxTokens,
                max_tool_calls: maxToolCalls,
                icon: icon,
                accent_color: accentColor,
                is_active: isActive
            )

            try await SupabaseService.shared.client
                .from("ai_agent_config")
                .upsert(payload)
                .execute()

            print("[AgentConfig] Saved agent: \(name)")

            // Reload agents list
            await store.loadAIAgents()

            dismiss()
        } catch {
            print("[AgentConfig] Error saving: \(error)")
        }
    }
}

#Preview {
    AgentConfigSheet(store: EditorStore(), agent: nil)
}
