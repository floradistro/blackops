import SwiftUI

// MARK: - Agent Config Panel (Full Editor)
// Comprehensive agent configuration with all settings
// PERFORMANCE: Uses child views with @StateObject to isolate reactive updates

struct AgentConfigPanel: View {
    @Environment(\.editorStore) private var store
    @Environment(\.toolbarState) private var toolbarState
    let agent: AIAgent

    // Editable state (copy of agent)
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var systemPrompt: String = ""
    @State private var model: String = "claude-sonnet-4-20250514"
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Int = 32000
    @State private var isActive: Bool = true
    @State private var enabledTools: Set<String> = []
    @State private var tone: String = "professional"
    @State private var verbosity: String = "moderate"

    @State private var hasChanges = false
    @State private var isSaving = false

    private let models = [
        ("claude-opus-4-6", "Claude Opus 4.6", "Most powerful"),
        ("claude-sonnet-4-5-20250929", "Claude Sonnet 4.5", "Fast & intelligent"),
        ("claude-opus-4-5-20251101", "Claude Opus 4.5", "Previous flagship"),
        ("claude-sonnet-4-20250514", "Claude Sonnet 4", "Fast & capable"),
        ("claude-haiku-4-5-20251001", "Claude Haiku 4.5", "Fastest")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Inline inspector toolbar
            inspectorToolbar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AgentHeaderSection(
                        name: name,
                        description: description,
                        isActive: isActive
                    )

                    Divider()

                    basicInfoSection

                    Divider()

                    modelSection

                    Divider()

                    AgentToolsSection(enabledTools: $enabledTools, hasChanges: $hasChanges)

                    Divider()

                    CustomToolsSection()

                    Divider()

                    TriggersSection()

                    Divider()

                    systemPromptSection
                }
                .padding(16)
            }
        }
        .background(VibrancyBackground())
        .onAppear { loadAgent(); wireToolbarState() }
        .onChange(of: agent.id) { _, _ in loadAgent(); wireToolbarState() }
        .onChange(of: hasChanges) { _, newValue in toolbarState.agentHasChanges = newValue }
        .onChange(of: isSaving) { _, newValue in toolbarState.agentIsSaving = newValue }
        .onDisappear { toolbarState.reset() }
    }

    // MARK: - Inspector Toolbar

    private var inspectorToolbar: some View {
        HStack(spacing: 8) {
            Text("CONFIG")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)

            Spacer()

            if hasChanges {
                Button {
                    discardChanges()
                } label: {
                    Text("Discard")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    Task { await saveAgent() }
                } label: {
                    HStack(spacing: 3) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 10, height: 10)
                        } else {
                            Text("Save")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 5, height: 5)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }

            Button {
                toolbarState.showConfig = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Close inspector")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Sections

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BASIC INFO")
                .font(DesignSystem.Typography.monoHeader)
                .foregroundStyle(.tertiary)

            VStack(spacing: 10) {
                HStack {
                    Text("name")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    TextField("", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced, weight: .medium))
                        .padding(8)
                        .background(DesignSystem.Colors.surfaceTertiary)
                        .frame(maxWidth: 300)
                        .onChange(of: name) { _, _ in hasChanges = true }
                }

                HStack {
                    Text("description")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    TextField("", text: $description)
                        .textFieldStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(DesignSystem.Colors.surfaceTertiary)
                        .frame(maxWidth: 300)
                        .onChange(of: description) { _, _ in hasChanges = true }
                }

                HStack {
                    Text("status")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isActive ? DesignSystem.Colors.success : DesignSystem.Colors.textQuaternary)
                            .frame(width: 6, height: 6)
                        Text(isActive ? "active" : "inactive")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $isActive)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                        .onChange(of: isActive) { _, _ in hasChanges = true }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MODEL")
                .font(DesignSystem.Typography.monoHeader)
                .foregroundStyle(.tertiary)

            VStack(spacing: 10) {
                // Model picker
                HStack {
                    Text("model")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: $model) {
                        ForEach(models, id: \.0) { id, name, _ in
                            Text(name).tag(id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: model) { _, _ in hasChanges = true }
                    Spacer()
                }

                // Temperature
                HStack {
                    Text("temperature")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $temperature, in: 0...1, step: 0.1)
                        .frame(width: 150)
                        .onChange(of: temperature) { _, _ in hasChanges = true }
                    Text(String(format: "%.1f", temperature))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 30)
                    Spacer()
                }

                // Max Tokens
                HStack {
                    Text("max tokens")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    MonoOptionSelector(
                        options: [4096, 8192, 16384, 32000],
                        selection: $maxTokens,
                        labels: [4096: "4K", 8192: "8K", 16384: "16K", 32000: "32K"]
                    )
                    .onChange(of: maxTokens) { _, _ in hasChanges = true }
                    Spacer()
                }

                // Tone
                HStack {
                    Text("tone")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    MonoOptionSelector(
                        options: ["professional", "friendly", "concise", "detailed"],
                        selection: $tone
                    )
                    .onChange(of: tone) { _, _ in hasChanges = true }
                    Spacer()
                }

                // Verbosity
                HStack {
                    Text("verbosity")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    MonoOptionSelector(
                        options: ["minimal", "moderate", "verbose"],
                        selection: $verbosity
                    )
                    .onChange(of: verbosity) { _, _ in hasChanges = true }
                    Spacer()
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SYSTEM PROMPT")
                .font(DesignSystem.Typography.monoHeader)
                .foregroundStyle(.tertiary)

            TextEditor(text: $systemPrompt)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(DesignSystem.Colors.surfaceTertiary)
                .onChange(of: systemPrompt) { _, _ in hasChanges = true }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    // MARK: - Actions

    private func discardChanges() {
        loadAgent()
        hasChanges = false
    }

    private func wireToolbarState() {
        toolbarState.saveAction = { await saveAgent() }
        toolbarState.discardAction = { discardChanges() }
    }

    private func loadAgent() {
        name = agent.name ?? ""
        description = agent.description ?? ""
        systemPrompt = agent.systemPrompt ?? ""
        model = agent.model ?? "claude-sonnet-4-20250514"
        temperature = agent.temperature ?? 0.7
        maxTokens = agent.maxTokens ?? 32000
        isActive = agent.isActive
        enabledTools = Set(agent.enabledTools ?? [])
        tone = agent.tone ?? "professional"
        verbosity = agent.verbosity ?? "moderate"
        hasChanges = false
    }

    private func saveAgent() async {
        isSaving = true

        var updated = agent
        updated.name = name
        updated.description = description
        updated.systemPrompt = systemPrompt
        updated.model = model
        updated.temperature = temperature
        updated.maxTokens = maxTokens
        updated.isActive = isActive
        updated.enabledTools = Array(enabledTools)
        updated.tone = tone
        updated.verbosity = verbosity

        await store.updateAgent(updated)

        hasChanges = false
        isSaving = false
    }
}

// MARK: - Tool Toggle Component

struct ToolToggle: View {
    let id: String
    let name: String
    let description: String
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(!isEnabled)
        } label: {
            HStack(spacing: 6) {
                Text(isEnabled ? "✓" : "○")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isEnabled ? .primary : .tertiary)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(isEnabled ? .primary : .secondary)
                    Text(description)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isEnabled ? Color.primary.opacity(0.04) : Color.primary.opacity(0.01))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Agent Header Section

private struct AgentHeaderSection: View {
    let name: String
    let description: String
    let isActive: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Untitled" : name)
                    .font(.system(.title2, design: .monospaced, weight: .medium))
                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(isActive ? DesignSystem.Colors.success : DesignSystem.Colors.textQuaternary)
                    .frame(width: 5, height: 5)
                Text(isActive ? "active" : "inactive")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

