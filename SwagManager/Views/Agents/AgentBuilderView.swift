import SwiftUI
import UniformTypeIdentifiers

// MARK: - Agent Builder View
// Apple-native three-pane agent builder with drag-and-drop

struct AgentBuilderView: View {
    @ObservedObject var editorStore: EditorStore

    @State private var selectedAgent: AgentConfiguration?
    @State private var inspectorWidth: CGFloat = 280
    @State private var showingTestSheet = false

    private var builderStore: AgentBuilderStore {
        if editorStore.agentBuilderStore == nil {
            editorStore.agentBuilderStore = AgentBuilderStore()
        }
        return editorStore.agentBuilderStore!
    }

    var body: some View {
        GeometryReader { geometry in
            HSplitView {
                // Left: Agent Canvas (main content)
                canvasPane
                    .frame(minWidth: 400)

                // Right: Inspector
                inspectorPane
                    .frame(minWidth: 240, idealWidth: inspectorWidth, maxWidth: 350)
            }
        }
        .environmentObject(editorStore)
        .navigationTitle(builderStore.currentAgent?.name ?? "Agent Builder")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    showingTestSheet = true
                } label: {
                    Label("Test Agent", systemImage: "play.circle")
                }
                .disabled(builderStore.currentAgent == nil)

                Button {
                    Task {
                        await builderStore.saveAgent()
                    }
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(builderStore.currentAgent == nil)
            }
        }
        .sheet(isPresented: $showingTestSheet) {
            if let agent = builderStore.currentAgent {
                AgentTestSheet(agent: agent)
            }
        }
        .onAppear {
            Task {
                await builderStore.loadResources(editorStore: editorStore)

                // Auto-create agent immediately if none exists
                if builderStore.currentAgent == nil {
                    builderStore.createNewAgent()
                }
            }
        }
    }


    // MARK: - Canvas Pane

    private var canvasPane: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                if let agent = builderStore.currentAgent {
                    // System Prompt Section
                    systemPromptSection(agent: agent)

                    // Tools Pipeline Section
                    toolsPipelineSection(agent: agent)

                    // Context Data Section
                    contextDataSection(agent: agent)

                    // Test Prompt Section
                    testPromptSection(agent: agent)

                } else {
                    // Loading state while agent is being created
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Setting up agent...")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
    }

    private func systemPromptSection(agent: AgentConfiguration) -> some View {
        GlassSection(
            title: "System Prompt",
            subtitle: "Define the agent's personality and behavior",
            icon: "text.bubble.fill"
        ) {
            TextEditor(text: Binding(
                get: { agent.systemPrompt },
                set: { builderStore.updateSystemPrompt($0) }
            ))
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 120)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }

    private func toolsPipelineSection(agent: AgentConfiguration) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tool Pipeline")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("Drag MCP Servers here")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Drop Zone
            DropZone(
                isActive: agent.enabledTools.isEmpty,
                emptyIcon: "plus.circle.dashed",
                emptyTitle: "Drop MCP Servers Here"
            ) {
                if !agent.enabledTools.isEmpty {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 140, maximum: 180), spacing: DesignSystem.Spacing.md)
                        ],
                        spacing: DesignSystem.Spacing.md
                    ) {
                        ForEach(agent.enabledTools) { toolRef in
                            if let tool = builderStore.getTool(toolRef.name) {
                                ToolCard(tool: tool) {
                                    builderStore.removeTool(toolRef.name)
                                }
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                }
            }
            .onDrop(of: [.utf8PlainText], isTargeted: .constant(false)) { providers in
                print("🎯 Tool drop zone activated")
                let result = handleToolDrop(providers)
                print("🔄 Tool drop handler returned: \(result)")
                return result
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(12)
    }

    private func contextDataSection(agent: AgentConfiguration) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "cylinder.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Context Data")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("Drag products, locations, or customers here")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Drop Zone
            DropZone(
                isActive: agent.contextData.isEmpty,
                emptyIcon: "square.dashed",
                emptyTitle: "Drop Context Items Here"
            ) {
                if !agent.contextData.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        ForEach(agent.contextData) { context in
                            ContextDataCard(context: context) {
                                builderStore.removeContext(context.id)
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                }
            }
            .onDrop(of: [.utf8PlainText], isTargeted: .constant(false)) { providers in
                print("🎯 Context drop zone activated")
                let result = handleContextDrop(providers)
                print("🔄 Context drop handler returned: \(result)")
                return result
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(12)
    }

    private func testPromptSection(agent: AgentConfiguration) -> some View {
        GlassSection(
            title: "Test Prompt",
            subtitle: "Try your agent with a sample prompt",
            icon: "play.circle.fill"
        ) {
            VStack(spacing: DesignSystem.Spacing.md) {
                TextEditor(text: Binding(
                    get: { builderStore.testPrompt },
                    set: { builderStore.testPrompt = $0 }
                ))
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)

                HStack {
                    Spacer()

                    Button {
                        Task {
                            await builderStore.runTest()
                        }
                    } label: {
                        Label("Run Test", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(builderStore.testPrompt.isEmpty || builderStore.isRunningTest)
                }
            }
        }
    }


    // MARK: - Inspector Pane

    private var inspectorPane: some View {
        VStack(spacing: 0) {
            // Inspector Header
            HStack {
                Text("Inspector")
                    .font(DesignSystem.Typography.headline)
                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(VisualEffectBackground(material: .sidebar))

            Divider()

            // Inspector Content
            ScrollView {
                if let agent = builderStore.currentAgent {
                    inspectorContent(agent: agent)
                } else {
                    emptyInspectorState
                }
            }
        }
        .background(VisualEffectBackground(material: .sidebar))
    }

    private func inspectorContent(agent: AgentConfiguration) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Basic Info
            InspectorSection(title: "Basic Info") {
                VStack(spacing: DesignSystem.Spacing.md) {
                    InspectorField(label: "Name") {
                        TextField("Agent name", text: Binding(
                            get: { agent.name },
                            set: { builderStore.updateName($0) }
                        ))
                        .textFieldStyle(.plain)
                    }

                    InspectorField(label: "Description") {
                        TextField("Brief description", text: Binding(
                            get: { agent.description ?? "" },
                            set: { builderStore.updateDescription($0) }
                        ))
                        .textFieldStyle(.plain)
                    }

                    InspectorField(label: "Category") {
                        Picker("", selection: Binding(
                            get: { agent.category ?? "general" },
                            set: { builderStore.updateCategory($0) }
                        )) {
                            Text("General").tag("general")
                            Text("Support").tag("support")
                            Text("Sales").tag("sales")
                            Text("Operations").tag("operations")
                        }
                        .pickerStyle(.menu)
                    }
                }
            }

            Divider()

            // Model Configuration
            InspectorSection(title: "Model") {
                VStack(spacing: DesignSystem.Spacing.md) {
                    InspectorField(label: "Model") {
                        Picker("", selection: Binding(
                            get: { agent.model ?? "claude-sonnet-4" },
                            set: { builderStore.updateModel($0) }
                        )) {
                            Text("Claude Sonnet 4").tag("claude-sonnet-4")
                            Text("Claude Opus 4").tag("claude-opus-4")
                            Text("Claude Haiku 4").tag("claude-haiku-4")
                            Text("Claude Sonnet 3.5").tag("claude-sonnet-3.5")
                        }
                        .pickerStyle(.menu)
                    }

                    InspectorField(label: "Temperature") {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Slider(
                                    value: Binding(
                                        get: { agent.temperature ?? 0.7 },
                                        set: { builderStore.updateTemperature($0) }
                                    ),
                                    in: 0...1
                                )

                                Text(String(format: "%.2f", agent.temperature ?? 0.7))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 35, alignment: .trailing)
                            }

                            HStack {
                                Text("Precise")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Text("Creative")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            Divider()

            // Behavior Settings
            InspectorSection(title: "Behavior") {
                VStack(spacing: DesignSystem.Spacing.md) {
                    InspectorField(label: "Tone") {
                        Picker("", selection: Binding(
                            get: { agent.personality?.tone ?? "professional" },
                            set: { builderStore.updateTone($0) }
                        )) {
                            Text("Friendly").tag("friendly")
                            Text("Professional").tag("professional")
                            Text("Formal").tag("formal")
                            Text("Casual").tag("casual")
                        }
                        .pickerStyle(.segmented)
                    }

                    InspectorField(label: "Creativity") {
                        VStack(alignment: .leading, spacing: 4) {
                            Slider(
                                value: Binding(
                                    get: { Double(agent.personality?.creativity ?? 0.7) },
                                    set: { builderStore.updateCreativity($0) }
                                ),
                                in: 0...1
                            )

                            HStack {
                                Text("Conservative")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Text("Creative")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    InspectorField(label: "Verbosity") {
                        Picker("", selection: Binding(
                            get: { agent.personality?.verbosity ?? "moderate" },
                            set: { builderStore.updateVerbosity($0) }
                        )) {
                            Text("Concise").tag("concise")
                            Text("Moderate").tag("moderate")
                            Text("Detailed").tag("detailed")
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }

            Divider()

            // Capabilities
            InspectorSection(title: "Capabilities") {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Toggle("Can Query Data", isOn: Binding(
                        get: { agent.capabilities.canQuery },
                        set: { builderStore.updateCanQuery($0) }
                    ))

                    Toggle("Can Send Messages", isOn: Binding(
                        get: { agent.capabilities.canSend },
                        set: { builderStore.updateCanSend($0) }
                    ))

                    Toggle("Can Modify Data", isOn: Binding(
                        get: { agent.capabilities.canModify },
                        set: { builderStore.updateCanModify($0) }
                    ))
                }
                .font(DesignSystem.Typography.body)
            }

            Divider()

            // Limits
            InspectorSection(title: "Limits") {
                VStack(spacing: DesignSystem.Spacing.md) {
                    InspectorField(label: "Max Tokens") {
                        TextField("4096", value: Binding(
                            get: { agent.maxTokensPerResponse ?? 4096 },
                            set: { builderStore.updateMaxTokens($0) }
                        ), format: .number)
                        .textFieldStyle(.plain)
                    }

                    InspectorField(label: "Max Turns") {
                        TextField("50", value: Binding(
                            get: { agent.maxTurnsPerConversation ?? 50 },
                            set: { builderStore.updateMaxTurns($0) }
                        ), format: .number)
                        .textFieldStyle(.plain)
                    }
                }
            }

            Divider()

            // Statistics
            InspectorSection(title: "Statistics") {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    StatRow(label: "Tools", value: "\(agent.enabledTools.count)")
                    StatRow(label: "Context Items", value: "\(agent.contextData.count)")
                    StatRow(label: "Prompt Length", value: "\(agent.systemPrompt.count) chars")
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
    }

    private var emptyInspectorState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "info.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Selection")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(.secondary)

            Text("Select an agent to view its properties")
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.xl)
    }

    // MARK: - Drop Handlers

    private func handleToolDrop(_ providers: [NSItemProvider]) -> Bool {
        print("🎯 Tool drop detected - checking providers: \(providers.count)")

        guard let provider = providers.first else {
            print("❌ No provider found")
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { data, error in
            if let error = error {
                print("❌ Error loading text data: \(error)")
                return
            }

            guard let data = data as? Data,
                  let dragString = String(data: data, encoding: .utf8) else {
                print("❌ Failed to decode text data")
                return
            }

            print("📦 Received drag string: \(dragString)")

            guard let decoded = DragItemType.decode(dragString),
                  decoded.type == .mcpServer else {
                print("❌ Not an MCP server drag item")
                return
            }

            print("🔍 Looking for server with UUID: \(decoded.uuid)")

            DispatchQueue.main.async {
                guard let server = self.editorStore.mcpServers.first(where: { $0.id == decoded.uuid }) else {
                    print("❌ Server not found in store")
                    return
                }

                print("✅ Found server: \(server.name)")
                self.builderStore.addTool(server)
                print("✅ Tool added to builder")
            }
        }

        return true
    }

    private func handleContextDrop(_ providers: [NSItemProvider]) -> Bool {
        print("🎯 Context drop detected - checking providers: \(providers.count)")

        guard let provider = providers.first else {
            print("❌ No provider found")
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { data, error in
            if let error = error {
                print("❌ Error loading text data: \(error)")
                return
            }

            guard let data = data as? Data,
                  let dragString = String(data: data, encoding: .utf8) else {
                print("❌ Failed to decode text data")
                return
            }

            print("📦 Received drag string: \(dragString)")

            guard let decoded = DragItemType.decode(dragString) else {
                print("❌ Failed to decode drag item")
                return
            }

            print("✅ Decoded type: \(decoded.type), UUID: \(decoded.uuid)")

            DispatchQueue.main.async {
                switch decoded.type {
                case .product:
                    print("➕ Adding products context")
                    self.builderStore.addContext(.products)
                    print("✅ Products context added")

                case .customer:
                    print("➕ Adding customers context")
                    self.builderStore.addContext(.customers)
                    print("✅ Customers context added")

                case .location:
                    guard let location = self.editorStore.locations.first(where: { $0.id == decoded.uuid }) else {
                        print("❌ Location not found in store")
                        return
                    }
                    print("✅ Found location: \(location.name)")
                    self.builderStore.addContext(.location(StoreLocation(
                        id: location.id,
                        name: location.name,
                        address: location.address
                    )))
                    print("✅ Location context added")

                case .mcpServer:
                    print("⚠️ MCP server dropped in context area (should be in tool area)")
                }
            }
        }

        return true
    }

}

// MARK: - Supporting Views

struct DropZone<Content: View>: View {
    let isActive: Bool
    let emptyIcon: String
    let emptyTitle: String
    @ViewBuilder let content: () -> Content
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            // Empty state
            if isActive {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: emptyIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(isTargeted ? .primary : .tertiary)

                    Text(emptyTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isTargeted ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                        .foregroundStyle(isTargeted ? .blue : Color.gray.opacity(0.3))
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.blue.opacity(0.05) : Color.clear)
                )
            } else {
                content()
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
    }
}

struct InspectorField<Content: View>: View {
    let label: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(.secondary)

            content()
                .padding(DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.surfaceTertiary)
                .cornerRadius(DesignSystem.Radius.sm)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(.primary)
                .fontWeight(.medium)
        }
    }
}
