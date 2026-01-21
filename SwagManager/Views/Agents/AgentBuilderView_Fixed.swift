import SwiftUI
import UniformTypeIdentifiers

// MARK: - Agent Builder View (FIXED VERSION)
// Fixes: State persistence, dragging, emojis removed, model config added

struct AgentBuilderView: View {
    @ObservedObject var editorStore: EditorStore

    @State private var inspectorWidth: CGFloat = 280
    @State private var sourceListWidth: CGFloat = 240
    @State private var showingTestSheet = false

    private var builderStore: AgentBuilderStore {
        if editorStore.agentBuilderStore == nil {
            editorStore.agentBuilderStore = AgentBuilderStore()
        }
        return editorStore.agentBuilderStore!
    }

    var body: some View {
        HSplitView {
            // Left: Source List
            sourceListPane
                .frame(minWidth: 200, idealWidth: sourceListWidth, maxWidth: 400)

            // Center: Agent Canvas
            canvasPane
                .frame(minWidth: 400)

            // Right: Inspector
            inspectorPane
                .frame(minWidth: 240, idealWidth: inspectorWidth, maxWidth: 350)
        }
        .navigationTitle(builderStore.currentAgent?.name ?? "Agent Builder")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    showingTestSheet = true
                } label: {
                    Label("Test", systemImage: "play.circle")
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
        .task {
            await builderStore.loadResources(editorStore: editorStore)
        }
    }

    // MARK: - Source List Pane

    private var sourceListPane: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))

                TextField("Search", text: $builderStore.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !builderStore.searchQuery.isEmpty {
                    Button {
                        builderStore.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Source tree
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    // MCP Tools Section
                    SourceSection(title: "MCP TOOLS", isExpanded: $builderStore.toolsSectionExpanded) {
                        mcpToolsTree
                    }

                    Divider().padding(.vertical, 4)

                    // Context Data Section
                    SourceSection(title: "CONTEXT DATA", isExpanded: $builderStore.contextSectionExpanded) {
                        contextDataTree
                    }

                    Divider().padding(.vertical, 4)

                    // Prompt Templates Section
                    SourceSection(title: "PROMPTS", isExpanded: $builderStore.templatesSectionExpanded) {
                        promptTemplatesTree
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var mcpToolsTree: some View {
        ForEach(builderStore.filteredToolCategories, id: \.self) { category in
            DisclosureGroup(
                isExpanded: Binding(
                    get: { builderStore.expandedCategories.contains(category) },
                    set: { isExpanded in
                        if isExpanded {
                            builderStore.expandedCategories.insert(category)
                        } else {
                            builderStore.expandedCategories.remove(category)
                        }
                    }
                )
            ) {
                ForEach(builderStore.tools(for: category)) { tool in
                    ToolRowView(tool: tool, builderStore: builderStore)
                        .padding(.leading, 16)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: categoryIcon(category))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text(category.capitalized)
                        .font(.system(size: 11))

                    Spacer()

                    Text("\(builderStore.tools(for: category).count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .disclosureGroupStyle(CompactDisclosureStyle())
        }
    }

    private var contextDataTree: some View {
        Group {
            ContextRowView(
                title: "Products",
                count: builderStore.products.count,
                icon: "cube",
                action: {
                    builderStore.addProductsContext()
                }
            )

            ContextRowView(
                title: "Locations",
                count: builderStore.locations.count,
                icon: "mappin.circle",
                action: {
                    builderStore.addLocationsContext()
                }
            )

            ContextRowView(
                title: "Customers",
                count: builderStore.customerSegments.count,
                icon: "person.2",
                action: {
                    builderStore.addCustomersContext()
                }
            )
        }
    }

    private var promptTemplatesTree: some View {
        ForEach(builderStore.promptTemplates) { template in
            Button {
                builderStore.appendToSystemPrompt(template)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)

                    Text(template.name)
                        .font(.system(size: 11))

                    Spacer()
                }
                .frame(height: 24)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Canvas Pane

    private var canvasPane: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let agent = builderStore.currentAgent {
                    // System Prompt Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SYSTEM PROMPT")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)

                        TextEditor(text: Binding(
                            get: { agent.systemPrompt },
                            set: { builderStore.updateSystemPrompt($0) }
                        ))
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }

                    // Tools Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TOOLS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)

                        if agent.enabledTools.isEmpty {
                            dropZonePlaceholder(text: "Drag tools from sidebar")
                        } else {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 140), spacing: 12)],
                                spacing: 12
                            ) {
                                ForEach(agent.enabledTools) { toolRef in
                                    if let tool = builderStore.getTool(toolRef.name) {
                                        CompactToolCard(tool: tool) {
                                            builderStore.removeTool(toolRef.name)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Context Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONTEXT")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)

                        if agent.contextData.isEmpty {
                            dropZonePlaceholder(text: "Add context data")
                        } else {
                            VStack(spacing: 8) {
                                ForEach(agent.contextData) { context in
                                    CompactContextCard(context: context) {
                                        builderStore.removeContext(context.id)
                                    }
                                }
                            }
                        }
                    }

                } else {
                    emptyCanvasState
                }
            }
            .padding(24)
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    private var emptyCanvasState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Create Agent")
                .font(.system(size: 18, weight: .semibold))

            Text("Start building your AI agent")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Button {
                builderStore.createNewAgent()
            } label: {
                Text("Create")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dropZonePlaceholder(text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.tertiary)
            )
    }

    // MARK: - Inspector Pane

    private var inspectorPane: some View {
        ScrollView {
            if let agent = builderStore.currentAgent {
                VStack(spacing: 20) {
                    // Basic Info
                    InspectorSection(title: "BASIC INFO") {
                        VStack(spacing: 12) {
                            InspectorField(label: "Name") {
                                TextField("", text: Binding(
                                    get: { agent.name },
                                    set: { builderStore.updateName($0) }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                            }

                            InspectorField(label: "Description") {
                                TextField("", text: Binding(
                                    get: { agent.description ?? "" },
                                    set: { builderStore.updateDescription($0) }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                            }
                        }
                    }

                    Divider()

                    // Model Configuration
                    InspectorSection(title: "MODEL") {
                        VStack(spacing: 12) {
                            InspectorField(label: "Model") {
                                Picker("", selection: Binding(
                                    get: { agent.model ?? "claude-3-5-sonnet-20241022" },
                                    set: { builderStore.updateModel($0) }
                                )) {
                                    Text("Claude 3.5 Sonnet").tag("claude-3-5-sonnet-20241022")
                                    Text("Claude 3 Opus").tag("claude-3-opus-20240229")
                                    Text("Claude 3 Haiku").tag("claude-3-haiku-20240307")
                                }
                                .pickerStyle(.menu)
                                .font(.system(size: 13))
                            }

                            InspectorField(label: "Temperature") {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Slider(
                                            value: Binding(
                                                get: { agent.temperature ?? 0.7 },
                                                set: { builderStore.updateTemperature($0) }
                                            ),
                                            in: 0...1,
                                            step: 0.1
                                        )

                                        Text(String(format: "%.1f", agent.temperature ?? 0.7))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 32)
                                    }

                                    HStack {
                                        Text("Precise")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.tertiary)
                                        Spacer()
                                        Text("Creative")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }

                            InspectorField(label: "Max Tokens") {
                                TextField("", value: Binding(
                                    get: { agent.maxTokensPerResponse ?? 4096 },
                                    set: { builderStore.updateMaxTokens($0) }
                                ), format: .number)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                            }
                        }
                    }

                    Divider()

                    // Behavior
                    InspectorSection(title: "BEHAVIOR") {
                        VStack(spacing: 12) {
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
                                .font(.system(size: 11))
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
                                .font(.system(size: 11))
                            }
                        }
                    }

                    Divider()

                    // Capabilities
                    InspectorSection(title: "CAPABILITIES") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Can Query Data", isOn: Binding(
                                get: { agent.capabilities.canQuery },
                                set: { builderStore.updateCanQuery($0) }
                            ))
                            .font(.system(size: 13))

                            Toggle("Can Send Messages", isOn: Binding(
                                get: { agent.capabilities.canSend },
                                set: { builderStore.updateCanSend($0) }
                            ))
                            .font(.system(size: 13))

                            Toggle("Can Modify Data", isOn: Binding(
                                get: { agent.capabilities.canModify },
                                set: { builderStore.updateCanModify($0) }
                            ))
                            .font(.system(size: 13))
                        }
                    }

                    Divider()

                    // Statistics
                    InspectorSection(title: "STATISTICS") {
                        VStack(alignment: .leading, spacing: 6) {
                            StatRow(label: "Tools", value: "\(agent.enabledTools.count)")
                            StatRow(label: "Context Items", value: "\(agent.contextData.count)")
                            StatRow(label: "Prompt Length", value: "\(agent.systemPrompt.count) chars")
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Helpers

    private func categoryIcon(_ category: String) -> String {
        switch category.lowercased() {
        case "crm": return "person.2"
        case "orders": return "cart"
        case "products": return "cube"
        case "inventory": return "archivebox"
        case "customers": return "person.crop.circle"
        case "email": return "envelope"
        case "analytics": return "chart.bar"
        default: return "folder"
        }
    }
}

// MARK: - Supporting Views

struct SourceSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            if isExpanded {
                content()
            }
        }
    }
}

struct ToolRowView: View {
    let tool: MCPServer
    let builderStore: AgentBuilderStore
    @State private var isHovered = false

    var body: some View {
        Button {
            builderStore.addTool(tool)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "wrench")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text(tool.name)
                    .font(.system(size: 11))
                    .lineLimit(1)

                Spacer()
            }
            .frame(height: 24)
            .padding(.horizontal, 8)
            .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct ContextRowView: View {
    let title: String
    let count: Int
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 11))

                Spacer()

                Text("\(count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .frame(height: 24)
            .padding(.horizontal, 8)
            .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct CompactToolCard: View {
    let tool: MCPServer
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tool.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                Spacer()

                if isHovered {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let description = tool.description {
                Text(description)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}

struct CompactContextCard: View {
    let context: AgentContextData
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: context.icon)
                .font(.system(size: 14))
                .foregroundStyle(context.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.title)
                    .font(.system(size: 11, weight: .medium))

                Text(context.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

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
                .foregroundStyle(.secondary)

            content()
                .padding(6)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
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
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}

struct CompactDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))

                    configuration.label
                }
                .frame(height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}
