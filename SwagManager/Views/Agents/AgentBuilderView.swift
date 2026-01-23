import SwiftUI
import UniformTypeIdentifiers

// MARK: - Agent Builder View
// Minimal, monochromatic theme

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
        VStack(spacing: 0) {
            // Inline toolbar
            builderToolbar

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
        }
        .environmentObject(editorStore)
        .sheet(isPresented: $showingTestSheet) {
            if let agent = builderStore.currentAgent {
                AgentTestSheet(agent: agent)
            }
        }
        .onAppear {
            Task {
                await builderStore.loadResources(editorStore: editorStore)
                if builderStore.currentAgent == nil {
                    builderStore.createNewAgent()
                }
            }
        }
    }

    // MARK: - Toolbar

    private var builderToolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.4))

            Text(builderStore.currentAgent?.name ?? "Agent Builder")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.7))

            Spacer()

            ToolbarButton(
                icon: "play.circle",
                action: { showingTestSheet = true },
                disabled: builderStore.currentAgent == nil
            )

            ToolbarButton(
                icon: "square.and.arrow.down",
                action: { Task { await builderStore.saveAgent() } },
                disabled: builderStore.currentAgent == nil
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }


    // MARK: - Canvas Pane

    private var canvasPane: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                    // Loading state
                    VStack(spacing: 12) {
                        Text("···")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.3))
                        Text("Setting up agent...")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(24)
        }
    }

    private func systemPromptSection(agent: AgentConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    Text("System Prompt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.8))
                    Text("Define the agent's personality and behavior")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
                Spacer()
            }

            // Editor
            TextEditor(text: Binding(
                get: { agent.systemPrompt },
                set: { builderStore.updateSystemPrompt($0) }
            ))
            .font(.system(size: 12, design: .monospaced))
            .frame(minHeight: 120)
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .padding(16)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(12)
    }

    private func toolsPipelineSection(agent: AgentConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tool Pipeline")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.8))
                    Text("Drag MCP Servers here")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
                Spacer()
            }

            // Drop Zone
            MinimalDropZone(
                isActive: agent.enabledTools.isEmpty,
                emptyIcon: "plus.circle.dashed",
                emptyTitle: "Drop MCP Servers Here"
            ) {
                if !agent.enabledTools.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(agent.enabledTools) { toolRef in
                            if let tool = builderStore.getTool(toolRef.name) {
                                MinimalToolCard(tool: tool) {
                                    builderStore.removeTool(toolRef.name)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
            }
            .onDrop(of: [.utf8PlainText], isTargeted: .constant(false)) { providers in
                handleToolDrop(providers)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(12)
    }

    private func contextDataSection(agent: AgentConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "cylinder")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Context Data")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.8))
                    Text("Drag products, locations, or customers here")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
                Spacer()
            }

            // Drop Zone
            MinimalDropZone(
                isActive: agent.contextData.isEmpty,
                emptyIcon: "square.dashed",
                emptyTitle: "Drop Context Items Here"
            ) {
                if !agent.contextData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(agent.contextData) { context in
                            MinimalContextCard(context: context) {
                                builderStore.removeContext(context.id)
                            }
                        }
                    }
                    .padding(12)
                }
            }
            .onDrop(of: [.utf8PlainText], isTargeted: .constant(false)) { providers in
                handleContextDrop(providers)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(12)
    }

    private func testPromptSection(agent: AgentConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "play.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Test Prompt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.8))
                    Text("Try your agent with a sample prompt")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
                Spacer()
            }

            // Editor
            TextEditor(text: Binding(
                get: { builderStore.testPrompt },
                set: { builderStore.testPrompt = $0 }
            ))
            .font(.system(size: 12, design: .monospaced))
            .frame(height: 80)
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )

            // Run button
            HStack {
                Spacer()
                Button {
                    Task { await builderStore.runTest() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Run Test")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.primary.opacity(builderStore.testPrompt.isEmpty ? 0.3 : 0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(builderStore.testPrompt.isEmpty ? 0.03 : 0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(builderStore.testPrompt.isEmpty || builderStore.isRunningTest)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(12)
    }


    // MARK: - Inspector Pane

    private var inspectorPane: some View {
        VStack(spacing: 0) {
            // Inspector Header
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.4))

                Text("Inspector")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.7))

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.02))
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1),
                alignment: .bottom
            )

            // Inspector Content
            ScrollView {
                if let agent = builderStore.currentAgent {
                    inspectorContent(agent: agent)
                } else {
                    emptyInspectorState
                }
            }
        }
        .background(Color.primary.opacity(0.02))
    }

    private func inspectorContent(agent: AgentConfiguration) -> some View {
        VStack(spacing: 20) {
            // Basic Info
            MinimalInspectorSection(title: "Basic Info") {
                VStack(spacing: 12) {
                    MinimalInspectorField(label: "Name") {
                        TextField("Agent name", text: Binding(
                            get: { agent.name },
                            set: { builderStore.updateName($0) }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    }

                    MinimalInspectorField(label: "Description") {
                        TextField("Brief description", text: Binding(
                            get: { agent.description ?? "" },
                            set: { builderStore.updateDescription($0) }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    }

                    MinimalInspectorField(label: "Category") {
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
                        .font(.system(size: 12))
                    }
                }
            }

            Divider()

            // Model Configuration
            MinimalInspectorSection(title: "Model") {
                VStack(spacing: 12) {
                    MinimalInspectorField(label: "Model") {
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
                        .font(.system(size: 12))
                    }

                    MinimalInspectorField(label: "Temperature") {
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
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.primary.opacity(0.5))
                                    .frame(width: 32, alignment: .trailing)
                            }
                            HStack {
                                Text("Precise")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.primary.opacity(0.3))
                                Spacer()
                                Text("Creative")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.primary.opacity(0.3))
                            }
                        }
                    }
                }
            }

            Divider()

            // Behavior Settings
            MinimalInspectorSection(title: "Behavior") {
                VStack(spacing: 12) {
                    MinimalInspectorField(label: "Tone") {
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
                        .font(.system(size: 11))
                    }

                    MinimalInspectorField(label: "Verbosity") {
                        Picker("", selection: Binding(
                            get: { agent.personality?.verbosity ?? "moderate" },
                            set: { builderStore.updateVerbosity($0) }
                        )) {
                            Text("Concise").tag("concise")
                            Text("Moderate").tag("moderate")
                            Text("Detailed").tag("detailed")
                        }
                        .pickerStyle(.segmented)
                        .font(.system(size: 11))
                    }
                }
            }

            Divider()

            // Capabilities
            MinimalInspectorSection(title: "Capabilities") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Can Query Data", isOn: Binding(
                        get: { agent.capabilities.canQuery },
                        set: { builderStore.updateCanQuery($0) }
                    ))
                    .font(.system(size: 12))

                    Toggle("Can Send Messages", isOn: Binding(
                        get: { agent.capabilities.canSend },
                        set: { builderStore.updateCanSend($0) }
                    ))
                    .font(.system(size: 12))

                    Toggle("Can Modify Data", isOn: Binding(
                        get: { agent.capabilities.canModify },
                        set: { builderStore.updateCanModify($0) }
                    ))
                    .font(.system(size: 12))
                }
            }

            Divider()

            // Statistics
            MinimalInspectorSection(title: "Statistics") {
                VStack(alignment: .leading, spacing: 6) {
                    MinimalStatRow(label: "Tools", value: "\(agent.enabledTools.count)")
                    MinimalStatRow(label: "Context Items", value: "\(agent.contextData.count)")
                    MinimalStatRow(label: "Prompt Length", value: "\(agent.systemPrompt.count) chars")
                }
            }
        }
        .padding(16)
    }

    private var emptyInspectorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 32))
                .foregroundStyle(Color.primary.opacity(0.2))

            Text("No Selection")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.5))

            Text("Select an agent to view its properties")
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Drop Handlers

    private func handleToolDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { data, error in
            guard let data = data as? Data,
                  let dragString = String(data: data, encoding: .utf8),
                  let decoded = DragItemType.decode(dragString),
                  decoded.type == .mcpServer else { return }

            DispatchQueue.main.async {
                guard let server = self.editorStore.mcpServers.first(where: { $0.id == decoded.uuid }) else { return }
                self.builderStore.addTool(server)
            }
        }
        return true
    }

    private func handleContextDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { data, error in
            guard let data = data as? Data,
                  let dragString = String(data: data, encoding: .utf8),
                  let decoded = DragItemType.decode(dragString) else { return }

            DispatchQueue.main.async {
                switch decoded.type {
                case .product:
                    self.builderStore.addContext(.products)
                case .customer:
                    self.builderStore.addContext(.customers)
                case .location:
                    guard let location = self.editorStore.locations.first(where: { $0.id == decoded.uuid }) else { return }
                    self.builderStore.addContext(.location(StoreLocation(
                        id: location.id,
                        name: location.name,
                        address: location.address
                    )))
                case .mcpServer:
                    break
                }
            }
        }
        return true
    }
}

// MARK: - Supporting Views

private struct MinimalDropZone<Content: View>: View {
    let isActive: Bool
    let emptyIcon: String
    let emptyTitle: String
    @ViewBuilder let content: () -> Content
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            if isActive {
                VStack(spacing: 16) {
                    Image(systemName: emptyIcon)
                        .font(.system(size: 32))
                        .foregroundStyle(Color.primary.opacity(isTargeted ? 0.5 : 0.2))

                    Text(emptyTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(isTargeted ? 0.7 : 0.4))
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1, dash: [6, 3])
                        )
                        .foregroundStyle(Color.primary.opacity(isTargeted ? 0.3 : 0.1))
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(isTargeted ? 0.03 : 0))
                )
            } else {
                content()
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
    }
}

private struct MinimalToolCard: View {
    let tool: MCPServer
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.system(size: 14))
                .foregroundStyle(Color.primary.opacity(0.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .lineLimit(1)
                Text(tool.category)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
    }
}

private struct MinimalContextCard: View {
    let context: AgentContextData
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconForType(context.type))
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.5))

            Text(context.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.8))

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "products": return "leaf"
        case "customers": return "person.2"
        case "location": return "mappin"
        default: return "cylinder"
        }
    }
}

private struct MinimalInspectorSection<Content: View>: View {
    let title: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.4))
                .textCase(.uppercase)

            content()
        }
    }
}

private struct MinimalInspectorField<Content: View>: View {
    let label: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.5))

            content()
                .padding(8)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(4)
        }
    }
}

private struct MinimalStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.7))
        }
    }
}

// MARK: - Legacy Support

struct DropZone<Content: View>: View {
    let isActive: Bool
    let emptyIcon: String
    let emptyTitle: String
    @ViewBuilder let content: () -> Content
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            if isActive {
                VStack(spacing: 16) {
                    Image(systemName: emptyIcon)
                        .font(.system(size: 32))
                        .foregroundStyle(Color.primary.opacity(isTargeted ? 0.5 : 0.2))
                    Text(emptyTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(isTargeted ? 0.7 : 0.4))
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 3]))
                        .foregroundStyle(Color.primary.opacity(isTargeted ? 0.3 : 0.1))
                )
            } else {
                content()
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.4))
                .textCase(.uppercase)
            content()
        }
    }
}

struct InspectorField<Content: View>: View {
    let label: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.5))
            content()
                .padding(8)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(4)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.7))
        }
    }
}
