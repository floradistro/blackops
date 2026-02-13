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
    @State private var icon: String = "cpu"
    @State private var accentColor: String = "blue"
    @State private var systemPrompt: String = ""
    @State private var model: String = "claude-sonnet-4-20250514"
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Int = 32000
    @State private var maxToolCalls: Int = 50
    @State private var isActive: Bool = true
    @State private var status: String = "draft"
    @State private var enabledTools: Set<String> = []
    @State private var tone: String = "professional"
    @State private var verbosity: String = "moderate"
    @State private var canQuery: Bool = true
    @State private var canSend: Bool = false
    @State private var canModify: Bool = false
    @State private var apiKey: String = ""

    // Context window limits
    @State private var maxHistoryChars: Int = 400_000
    @State private var maxToolResultChars: Int = 40_000
    @State private var maxMessageChars: Int = 20_000

    @State private var hasChanges = false
    @State private var isSaving = false
    @State private var saveError: String?

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
                        icon: icon,
                        accentColor: accentColor,
                        status: status,
                        isActive: isActive
                    )

                    if let saveError {
                        HStack(spacing: DesignSystem.Spacing.xs + 2) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(DesignSystem.font(10))
                            Text(saveError)
                                .font(DesignSystem.monoFont(10))
                        }
                        .foregroundStyle(DesignSystem.Colors.error)
                        .padding(DesignSystem.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.Colors.error.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xs))
                    }

                    Divider()

                    identitySection

                    Divider()

                    modelSection

                    Divider()

                    permissionsSection

                    Divider()

                    contextWindowSection

                    Divider()

                    apiKeySection

                    Divider()

                    AgentToolsSection(enabledTools: $enabledTools, hasChanges: $hasChanges, isGlobalAgent: agent.storeId == nil)

                    Divider()

                    CustomToolsSection()

                    Divider()

                    TriggersSection()

                    Divider()

                    systemPromptSection
                }
                .padding(DesignSystem.Spacing.lg)
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
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text("CONFIG")
                .font(DesignSystem.monoFont(9, weight: .bold))
                .foregroundStyle(.tertiary)

            Spacer()

            if hasChanges {
                Button {
                    discardChanges()
                } label: {
                    Text("Discard")
                        .font(DesignSystem.font(11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    Task { await saveAgent() }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xxs + 1) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 10, height: 10)
                        } else {
                            Text("Save")
                                .font(DesignSystem.font(11, weight: .semibold))
                        }
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 5, height: 5)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xxs + 1)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xs))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }

            Button {
                toolbarState.showConfig = false
            } label: {
                Image(systemName: "xmark")
                    .font(DesignSystem.font(10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Close inspector")
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    // MARK: - Sections

    // MARK: - Identity

    private let agentIcons = [
        "cpu", "brain", "sparkles", "bolt.fill", "wand.and.stars",
        "person.fill", "bubble.left.fill", "terminal", "gear",
        "chart.bar.fill", "cart.fill", "envelope.fill", "shippingbox.fill",
        "tag.fill", "doc.text.fill", "cube.fill", "network"
    ]

    private let agentColors = [
        ("blue", Color.blue),
        ("purple", Color.purple),
        ("green", Color.green),
        ("orange", Color.orange),
        ("red", Color.red),
        ("cyan", Color.cyan),
        ("pink", Color.pink),
        ("yellow", Color.yellow)
    ]

    private let statuses = [
        ("draft", "Draft"),
        ("published", "Published"),
        ("archived", "Archived")
    ]

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("IDENTITY")
                .font(DesignSystem.Typography.monoHeader)
                .foregroundStyle(.tertiary)

            VStack(spacing: DesignSystem.Spacing.sm + 2) {
                // Icon + Color row
                HStack(spacing: DesignSystem.Spacing.lg) {
                    // Icon picker
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("icon")
                            .font(DesignSystem.monoFont(9))
                            .foregroundStyle(.tertiary)
                        Menu {
                            ForEach(agentIcons, id: \.self) { iconName in
                                Button {
                                    icon = iconName
                                    hasChanges = true
                                } label: {
                                    Label(iconName, systemImage: iconName)
                                }
                            }
                        } label: {
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundStyle(colorForName(accentColor))
                                .frame(width: 36, height: 36)
                                .background(colorForName(accentColor).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        }
                        .buttonStyle(.plain)
                    }

                    // Color picker
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("color")
                            .font(DesignSystem.monoFont(9))
                            .foregroundStyle(.tertiary)
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(agentColors, id: \.0) { name, color in
                                Button {
                                    accentColor = name
                                    hasChanges = true
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: accentColor == name ? 2 : 0)
                                                .frame(width: 22, height: 22)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Name
                HStack {
                    Text("name")
                        .font(DesignSystem.monoFont(11))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    TextField("", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced, weight: .medium))
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surfaceTertiary)
                        .frame(maxWidth: 300)
                        .onChange(of: name) { _, _ in hasChanges = true }
                }

                // Description
                HStack {
                    Text("description")
                        .font(DesignSystem.monoFont(11))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    TextField("", text: $description)
                        .textFieldStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surfaceTertiary)
                        .frame(maxWidth: 300)
                        .onChange(of: description) { _, _ in hasChanges = true }
                }

                // Status (deployment lifecycle)
                HStack {
                    Text("status")
                        .font(DesignSystem.monoFont(11))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(statuses, id: \.0) { value, label in
                            Button {
                                status = value
                                hasChanges = true
                            } label: {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Circle()
                                        .fill(statusColor(value))
                                        .frame(width: 5, height: 5)
                                    Text(label)
                                        .font(DesignSystem.monoFont(10))
                                }
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(status == value ? statusColor(value).opacity(0.12) : Color.primary.opacity(0.03))
                                .foregroundStyle(status == value ? .primary : .tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                }

                // Active toggle
                HStack {
                    Text("enabled")
                        .font(DesignSystem.monoFont(11))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    HStack(spacing: DesignSystem.Spacing.xs + 2) {
                        Circle()
                            .fill(isActive ? DesignSystem.Colors.success : DesignSystem.Colors.textQuaternary)
                            .frame(width: 6, height: 6)
                        Text(isActive ? "active" : "inactive")
                            .font(DesignSystem.monoFont(11))
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

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "cyan": return .cyan
        case "pink": return .pink
        case "yellow": return .yellow
        default: return .blue
        }
    }

    private func statusColor(_ value: String) -> Color {
        switch value {
        case "published": return DesignSystem.Colors.success
        case "archived": return DesignSystem.Colors.textQuaternary
        default: return DesignSystem.Colors.warning
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("MODEL")
                .font(DesignSystem.Typography.monoHeader)
                .foregroundStyle(.tertiary)

            VStack(spacing: DesignSystem.Spacing.sm + 2) {
                // Model picker
                HStack {
                    Text("model")
                        .font(DesignSystem.monoFont(11))
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
                        .font(DesignSystem.monoFont(11))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $temperature, in: 0...1, step: 0.1)
                        .frame(width: 150)
                        .onChange(of: temperature) { _, _ in hasChanges = true }
                    Text(String(format: "%.1f", temperature))
                        .font(DesignSystem.monoFont(11))
                        .foregroundStyle(.tertiary)
                        .frame(width: 30)
                    Spacer()
                }

                // Max Tokens
                HStack {
                    Text("max tokens")
                        .font(DesignSystem.monoFont(11))
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

                // Max Tool Calls (loop limit)
                HStack {
                    Text("max tools")
                        .font(DesignSystem.monoFont(11))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    MonoOptionSelector(
                        options: [10, 25, 50, 100, 200],
                        selection: $maxToolCalls,
                        labels: [10: "10", 25: "25", 50: "50", 100: "100", 200: "200"]
                    )
                    .onChange(of: maxToolCalls) { _, _ in hasChanges = true }
                    Spacer()
                }

                // Tone
                HStack {
                    Text("tone")
                        .font(DesignSystem.monoFont(11))
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
                        .font(DesignSystem.monoFont(11))
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

    private var contextWindowSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("CONTEXT WINDOW")
                .font(DesignSystem.Typography.monoHeader)
                .foregroundStyle(.tertiary)

            VStack(spacing: DesignSystem.Spacing.sm + 2) {
                // History budget
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text("history budget")
                            .font(DesignSystem.monoFont(11))
                            .foregroundStyle(.secondary)
                        Text("~\(maxHistoryChars / 4_000)K tokens")
                            .font(DesignSystem.monoFont(9))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 110, alignment: .leading)
                    MonoOptionSelector(
                        options: [100_000, 200_000, 400_000, 600_000],
                        selection: $maxHistoryChars,
                        labels: [100_000: "25K", 200_000: "50K", 400_000: "100K", 600_000: "150K"]
                    )
                    .onChange(of: maxHistoryChars) { _, _ in hasChanges = true }
                    Spacer()
                }

                // Tool result cap
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text("tool result cap")
                            .font(DesignSystem.monoFont(11))
                            .foregroundStyle(.secondary)
                        Text("~\(maxToolResultChars / 4_000)K tokens")
                            .font(DesignSystem.monoFont(9))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 110, alignment: .leading)
                    MonoOptionSelector(
                        options: [10_000, 20_000, 40_000, 80_000],
                        selection: $maxToolResultChars,
                        labels: [10_000: "2.5K", 20_000: "5K", 40_000: "10K", 80_000: "20K"]
                    )
                    .onChange(of: maxToolResultChars) { _, _ in hasChanges = true }
                    Spacer()
                }

                // Message cap
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text("message cap")
                            .font(DesignSystem.monoFont(11))
                            .foregroundStyle(.secondary)
                        Text("~\(maxMessageChars / 4_000)K tokens")
                            .font(DesignSystem.monoFont(9))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 110, alignment: .leading)
                    MonoOptionSelector(
                        options: [8_000, 12_000, 20_000, 40_000],
                        selection: $maxMessageChars,
                        labels: [8_000: "2K", 12_000: "3K", 20_000: "5K", 40_000: "10K"]
                    )
                    .onChange(of: maxMessageChars) { _, _ in hasChanges = true }
                    Spacer()
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("PERMISSIONS")
                .font(DesignSystem.Typography.monoHeader)
                .foregroundStyle(.tertiary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                // Can Query (read-only data access)
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text("can query")
                            .font(DesignSystem.monoFont(11))
                            .foregroundStyle(.secondary)
                        Text("Read data, run analytics, search")
                            .font(DesignSystem.monoFont(9))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $canQuery)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                        .onChange(of: canQuery) { _, _ in hasChanges = true }
                }

                Divider()

                // Can Send (outbound comms)
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text("can send")
                            .font(DesignSystem.monoFont(11))
                            .foregroundStyle(.secondary)
                        Text("Send emails, notifications, webhooks")
                            .font(DesignSystem.monoFont(9))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $canSend)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                        .onChange(of: canSend) { _, _ in hasChanges = true }
                }

                Divider()

                // Can Modify (write access)
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text("can modify")
                            .font(DesignSystem.monoFont(11))
                            .foregroundStyle(canModify ? DesignSystem.Colors.warning : .secondary)
                        Text("Create, update, delete records")
                            .font(DesignSystem.monoFont(9))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $canModify)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                        .onChange(of: canModify) { _, _ in hasChanges = true }
                }

                if canModify {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(DesignSystem.font(9))
                        Text("Agent can modify store data")
                            .font(DesignSystem.monoFont(9))
                    }
                    .foregroundStyle(DesignSystem.Colors.warning)
                    .padding(DesignSystem.Spacing.xs + 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.Colors.warning.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xs))
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("API KEY")
                    .font(DesignSystem.Typography.monoHeader)
                    .foregroundStyle(.tertiary)
                Spacer()
                if !apiKey.isEmpty {
                    Text("configured")
                        .font(DesignSystem.monoFont(9))
                        .foregroundStyle(DesignSystem.Colors.success)
                }
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                SecureField("sk-ant-...", text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.surfaceTertiary)
                    .onChange(of: apiKey) { _, _ in hasChanges = true }

                Text("Per-agent Anthropic API key. Falls back to store default if empty.")
                    .font(DesignSystem.monoFont(9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    // MARK: - System Prompt

    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("SYSTEM PROMPT")
                .font(DesignSystem.Typography.monoHeader)
                .foregroundStyle(.tertiary)

            TextEditor(text: $systemPrompt)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
                .padding(DesignSystem.Spacing.sm + 2)
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
        icon = agent.icon ?? "cpu"
        accentColor = agent.accentColor ?? "blue"
        systemPrompt = agent.systemPrompt ?? ""
        model = agent.model ?? "claude-sonnet-4-20250514"
        temperature = agent.temperature ?? 0.7
        maxTokens = agent.maxTokens ?? 32000
        maxToolCalls = agent.maxToolCalls ?? 50
        isActive = agent.isActive
        status = agent.status ?? "draft"
        enabledTools = Set(agent.enabledTools ?? [])
        tone = agent.tone ?? "professional"
        verbosity = agent.verbosity ?? "moderate"
        canQuery = agent.canQuery ?? true
        canSend = agent.canSend ?? false
        canModify = agent.canModify ?? false
        apiKey = agent.apiKey ?? ""
        maxHistoryChars = agent.contextConfig?.maxHistoryChars ?? 400_000
        maxToolResultChars = agent.contextConfig?.maxToolResultChars ?? 40_000
        maxMessageChars = agent.contextConfig?.maxMessageChars ?? 20_000
        hasChanges = false
        saveError = nil
    }

    private func saveAgent() async {
        isSaving = true
        saveError = nil

        var updated = agent
        updated.name = name
        updated.description = description
        updated.icon = icon
        updated.accentColor = accentColor
        updated.systemPrompt = systemPrompt
        updated.model = model
        updated.temperature = temperature
        updated.maxTokens = maxTokens
        updated.maxToolCalls = maxToolCalls
        updated.isActive = isActive
        updated.status = status
        updated.enabledTools = Array(enabledTools)
        updated.tone = tone
        updated.verbosity = verbosity
        updated.canQuery = canQuery
        updated.canSend = canSend
        updated.canModify = canModify
        updated.apiKey = apiKey.isEmpty ? nil : apiKey
        updated.contextConfig = AgentContextConfig(
            maxHistoryChars: maxHistoryChars,
            maxToolResultChars: maxToolResultChars,
            maxMessageChars: maxMessageChars
        )

        await store.updateAgent(updated)

        // Only clear changes if save succeeded (no error shown)
        if store.showError {
            saveError = store.error
        } else {
            hasChanges = false
        }
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
            HStack(spacing: DesignSystem.Spacing.xs + 2) {
                Text(isEnabled ? "✓" : "○")
                    .font(DesignSystem.monoFont(10))
                    .foregroundStyle(isEnabled ? .primary : .tertiary)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(DesignSystem.monoFont(11, weight: .medium))
                        .foregroundStyle(isEnabled ? .primary : .secondary)
                    Text(description)
                        .font(DesignSystem.monoFont(9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, DesignSystem.Spacing.xs + 2)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .background(isEnabled ? Color.primary.opacity(0.04) : Color.primary.opacity(0.01))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Agent Header Section

private struct AgentHeaderSection: View {
    let name: String
    let description: String
    let icon: String
    let accentColor: String
    let status: String
    let isActive: Bool

    private var color: Color {
        switch accentColor {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "cyan": return .cyan
        case "pink": return .pink
        case "yellow": return .yellow
        default: return .blue
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Agent icon
            Image(systemName: icon)
                .font(DesignSystem.font(20))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm + 2))

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(name.isEmpty ? "Untitled" : name)
                    .font(.system(.title2, design: .monospaced, weight: .medium))
                if !description.isEmpty {
                    Text(description)
                        .font(DesignSystem.monoFont(12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Circle()
                        .fill(isActive ? DesignSystem.Colors.success : DesignSystem.Colors.textQuaternary)
                        .frame(width: 5, height: 5)
                    Text(isActive ? "active" : "inactive")
                        .font(DesignSystem.monoFont(10))
                        .foregroundStyle(.tertiary)
                }
                Text(status.capitalized)
                    .font(DesignSystem.monoFont(9))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

