import SwiftUI

// MARK: - Agent Config Panel
// Full-panel view for viewing/editing AI agents - similar to AgentBuilderView
// Displays in main content area when agent is selected from sidebar

struct AgentConfigPanel: View {
    @ObservedObject var store: EditorStore
    let agent: AIAgent

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
    @State private var hasChanges = false
    @State private var inspectorWidth: CGFloat = 300

    private var isNewAgent: Bool {
        agent.name == "New Agent" && agent.createdAt == agent.updatedAt
    }

    var body: some View {
        HSplitView {
            // Main content - scrollable config
            mainContent
                .frame(minWidth: 400)

            // Right inspector - agent info & actions
            inspectorPane
                .frame(minWidth: 260, idealWidth: inspectorWidth, maxWidth: 380)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if hasChanges {
                    Button {
                        Task { await saveAgent() }
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .disabled(name.isEmpty || isSaving)
                }

                Button {
                    // Test agent action
                } label: {
                    Label("Test", systemImage: "play.circle")
                }
            }
        }
        .onAppear {
            loadAgentData()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Identity Section
                configSection("Identity") {
                    configField("Name") {
                        TextField("Agent name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .onChange(of: name) { _, _ in hasChanges = true }
                    }

                    configField("Description") {
                        TextField("Brief description of what this agent does", text: $description)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .onChange(of: description) { _, _ in hasChanges = true }
                    }

                    configField("Icon") {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(width: 32, height: 32)

                                Image(systemName: icon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.primary.opacity(0.7))
                            }

                            Picker("", selection: $icon) {
                                Label("Sparkles", systemImage: "sparkles").tag("sparkles")
                                Label("Brain", systemImage: "brain.head.profile").tag("brain.head.profile")
                                Label("CPU", systemImage: "cpu").tag("cpu")
                                Label("Message", systemImage: "message").tag("message")
                                Label("Person", systemImage: "person.circle").tag("person.circle")
                                Label("Wand", systemImage: "wand.and.stars").tag("wand.and.stars")
                                Label("Gear", systemImage: "gearshape").tag("gearshape")
                                Label("Chart", systemImage: "chart.bar").tag("chart.bar")
                                Label("Bolt", systemImage: "bolt").tag("bolt")
                                Label("Target", systemImage: "target").tag("target")
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .onChange(of: icon) { _, _ in hasChanges = true }
                        }
                    }

                    configField("Status") {
                        Toggle("Active", isOn: $isActive)
                            .toggleStyle(.switch)
                            .onChange(of: isActive) { _, _ in hasChanges = true }
                    }
                }

                Divider()
                    .padding(.horizontal)

                // Model Configuration
                configSection("Model Configuration") {
                    configField("Model") {
                        Picker("", selection: $model) {
                            Text("Claude Opus 4.5").tag("claude-opus-4-5-20251101")
                            Text("Claude Sonnet 4").tag("claude-sonnet-4-20250514")
                            Text("Claude Haiku 3.5").tag("claude-3-5-haiku-20241022")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: model) { _, _ in hasChanges = true }
                    }

                    configField("Max Tokens") {
                        HStack(spacing: 12) {
                            TextField("", value: $maxTokens, format: .number)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, design: .monospaced))
                                .frame(width: 80)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(4)

                            Slider(value: Binding(
                                get: { Double(maxTokens) },
                                set: { maxTokens = Int($0) }
                            ), in: 1000...128000, step: 1000)

                            Text("\(maxTokens / 1000)K")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 40)
                        }
                        .onChange(of: maxTokens) { _, _ in hasChanges = true }
                    }

                    configField("Max Tool Calls") {
                        HStack(spacing: 12) {
                            TextField("", value: $maxToolCalls, format: .number)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, design: .monospaced))
                                .frame(width: 80)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(4)

                            Stepper("", value: $maxToolCalls, in: 1...500, step: 10)
                                .labelsHidden()
                        }
                        .onChange(of: maxToolCalls) { _, _ in hasChanges = true }
                    }
                }

                Divider()
                    .padding(.horizontal)

                // System Prompt - larger section
                configSection("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 300)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .onChange(of: systemPrompt) { _, _ in hasChanges = true }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Inspector Pane

    private var inspectorPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Agent Icon & Name
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 80, height: 80)

                        Image(systemName: icon)
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.7))
                    }

                    Text(name.isEmpty ? "New Agent" : name)
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)

                    if !description.isEmpty {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Status badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isActive ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)

                        Text(isActive ? "Active" : "Inactive")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isActive ? .green : .secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

                Divider()

                // Model Info
                inspectorSection("Model") {
                    inspectorRow("Type", value: model.contains("opus") ? "Opus 4.5" : model.contains("haiku") ? "Haiku 3.5" : "Sonnet 4")
                    inspectorRow("Max Tokens", value: "\(maxTokens.formatted())")
                    inspectorRow("Max Tools", value: "\(maxToolCalls)")
                }

                Divider()

                // Metadata
                inspectorSection("Info") {
                    inspectorRow("Version", value: "\(agent.version ?? 1)")
                    inspectorRow("Created", value: agent.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                    inspectorRow("Updated", value: agent.updatedAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                    inspectorRow("ID", value: String(agent.id.uuidString.prefix(8)))
                }

                Divider()

                // Actions
                VStack(spacing: 8) {
                    Button {
                        Task { await saveAgent() }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text(isNewAgent ? "Create Agent" : "Save Changes")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || isSaving)

                    if !isNewAgent {
                        Button(role: .destructive) {
                            // Delete agent
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Agent")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Helper Views

    private func configSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
    }

    private func configField(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            content()
        }
    }

    private func inspectorSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            content()
        }
    }

    private func inspectorRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Data

    private func loadAgentData() {
        name = agent.name ?? ""
        description = agent.description ?? ""
        systemPrompt = agent.systemPrompt ?? "You are a helpful AI assistant."
        model = agent.model ?? "claude-sonnet-4-20250514"
        maxTokens = agent.maxTokens ?? 32000
        maxToolCalls = agent.maxToolCalls ?? 200
        icon = agent.icon ?? "sparkles"
        accentColor = agent.accentColor ?? "blue"
        isActive = agent.isActive
        hasChanges = false
    }

    private func saveAgent() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let storeId = store.selectedStore?.id

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
                id: agent.id.uuidString.lowercased(),
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
            hasChanges = false

            // Reload agents list
            await store.loadAIAgents()
        } catch {
            print("[AgentConfig] Error saving: \(error)")
        }
    }
}

#Preview {
    AgentConfigPanel(
        store: EditorStore(),
        agent: AIAgent(
            id: UUID(),
            storeId: nil,
            name: "Lisa",
            description: "Customer service assistant",
            systemPrompt: "You are Lisa, a helpful assistant.",
            model: "claude-sonnet-4-20250514",
            maxTokens: 32000,
            maxToolCalls: 200,
            icon: "sparkles",
            accentColor: "blue",
            isActive: true,
            version: 1,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}
