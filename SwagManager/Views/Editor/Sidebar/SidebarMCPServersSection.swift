import SwiftUI

// MARK: - Sidebar MCP Servers Section
// Following Apple engineering standards and existing patterns

struct SidebarMCPServersSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedTypes: Set<String> = ["node", "python"]
    @State private var searchQuery: String = ""
    @State private var showAddSheet = false

    var filteredServers: [MCPServer] {
        if searchQuery.isEmpty {
            return store.mcpServers
        }
        return store.mcpServers.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.description?.localizedCaseInsensitiveContains(searchQuery) ?? false
        }
    }

    var body: some View {
        TreeSectionHeader(
            title: "MCP SERVERS",
            isExpanded: $store.sidebarMCPExpanded,
            count: store.mcpServers.count
        )
        .padding(.top, DesignSystem.Spacing.xxs)

        if store.sidebarMCPExpanded {
            // Search bar
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                TextField("Search servers...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.Colors.surfaceSecondary.opacity(0.3))
            )
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.xs)

            // Quick filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    QuickFilterButton(title: "All", icon: "square.grid.2x2", isActive: searchQuery.isEmpty) {
                        searchQuery = ""
                    }

                    QuickFilterButton(title: "Running", icon: "play.circle.fill", isActive: false) {
                        searchQuery = ""
                        store.mcpServers = store.mcpServers.filter { $0.status == .running }
                    }

                    QuickFilterButton(title: "Enabled", icon: "checkmark.circle", isActive: false) {
                        searchQuery = ""
                        store.mcpServers = store.mcpServers.filter { $0.enabled }
                    }

                    QuickFilterButton(title: "Error", icon: "exclamationmark.triangle", isActive: false) {
                        searchQuery = ""
                        store.mcpServers = store.mcpServers.filter { $0.status == .error }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
            }
            .padding(.bottom, DesignSystem.Spacing.xs)

            // Stats overview
            if searchQuery.isEmpty {
                VStack(spacing: DesignSystem.Spacing.xxs) {
                    HStack {
                        StatsChip(
                            label: "Total",
                            value: "\(store.mcpServers.count)",
                            icon: "server.rack",
                            color: .blue
                        )
                        StatsChip(
                            label: "Running",
                            value: "\(store.mcpServers.filter { $0.status == .running }.count)",
                            icon: "play.circle",
                            color: .green
                        )
                    }
                    HStack {
                        StatsChip(
                            label: "Enabled",
                            value: "\(store.mcpServers.filter { $0.enabled }.count)",
                            icon: "checkmark.circle",
                            color: .purple
                        )
                        StatsChip(
                            label: "Errors",
                            value: "\(store.mcpServers.filter { $0.status == .error }.count)",
                            icon: "exclamationmark.triangle",
                            color: .red
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.sm)
            }

            // Server groups by type
            if searchQuery.isEmpty {
                // Node.js Servers
                let nodeServers = store.mcpServers.filter { $0.serverType == .node }
                if !nodeServers.isEmpty {
                    MCPServerTypeGroup(
                        title: "Node.js",
                        servers: nodeServers,
                        color: .green,
                        icon: "cube",
                        isExpanded: expandedTypes.contains("node"),
                        onToggle: { toggleType("node") },
                        store: store
                    )
                }

                // Python Servers
                let pythonServers = store.mcpServers.filter { $0.serverType == .python }
                if !pythonServers.isEmpty {
                    MCPServerTypeGroup(
                        title: "Python",
                        servers: pythonServers,
                        color: .blue,
                        icon: "snake",
                        isExpanded: expandedTypes.contains("python"),
                        onToggle: { toggleType("python") },
                        store: store
                    )
                }

                // Docker Servers
                let dockerServers = store.mcpServers.filter { $0.serverType == .docker }
                if !dockerServers.isEmpty {
                    MCPServerTypeGroup(
                        title: "Docker",
                        servers: dockerServers,
                        color: .cyan,
                        icon: "shippingbox",
                        isExpanded: expandedTypes.contains("docker"),
                        onToggle: { toggleType("docker") },
                        store: store
                    )
                }

                // Binary Servers
                let binaryServers = store.mcpServers.filter { $0.serverType == .binary }
                if !binaryServers.isEmpty {
                    MCPServerTypeGroup(
                        title: "Binary",
                        servers: binaryServers,
                        color: .purple,
                        icon: "terminal",
                        isExpanded: expandedTypes.contains("binary"),
                        onToggle: { toggleType("binary") },
                        store: store
                    )
                }

                // Custom Servers
                let customServers = store.mcpServers.filter { $0.serverType == .custom }
                if !customServers.isEmpty {
                    MCPServerTypeGroup(
                        title: "Custom",
                        servers: customServers,
                        color: .orange,
                        icon: "gear",
                        isExpanded: expandedTypes.contains("custom"),
                        onToggle: { toggleType("custom") },
                        store: store
                    )
                }
            } else {
                // Search results - flat list
                ForEach(filteredServers) { server in
                    MCPServerTreeItem(
                        server: server,
                        isSelected: store.selectedMCPServer?.id == server.id,
                        indentLevel: 1,
                        onSelect: { store.openMCPServerTab(server) },
                        onToggle: { Task { await store.toggleMCPServer(server) } }
                    )
                }
            }

            // Add new server button
            Button(action: { showAddSheet = true }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)

                    Text("Add MCP Server")
                        .font(DesignSystem.Typography.caption1Medium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .buttonStyle(.plain)

            // Empty state
            if store.mcpServers.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)
                        Text(searchQuery.isEmpty ? "No MCP servers yet" : "No results")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(.tertiary)
                        Text("Add your first server")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(.quaternary)
                    }
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
        }
    }

    private func toggleType(_ type: String) {
        withAnimation(DesignSystem.Animation.fast) {
            if expandedTypes.contains(type) {
                expandedTypes.remove(type)
            } else {
                expandedTypes.insert(type)
            }
        }
    }
}

// MARK: - MCP Server Type Group

struct MCPServerTypeGroup: View {
    let title: String
    let servers: [MCPServer]
    let color: Color
    let icon: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(color)
                        .frame(width: 16)

                    Text(title)
                        .font(DesignSystem.Typography.caption1Medium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("(\(servers.count))")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    Spacer()

                    // Running count indicator
                    let runningCount = servers.filter { $0.status == .running }.count
                    if runningCount > 0 {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("\(runningCount)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(servers) { server in
                    MCPServerTreeItem(
                        server: server,
                        isSelected: store.selectedMCPServer?.id == server.id,
                        indentLevel: 1,
                        onSelect: { store.openMCPServerTab(server) },
                        onToggle: { Task { await store.toggleMCPServer(server) } }
                    )
                }
            }
        }
    }
}

// MARK: - MCP Server Tree Item

struct MCPServerTreeItem: View {
    let server: MCPServer
    let isSelected: Bool
    let indentLevel: Int
    let onSelect: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                // Indent
                if indentLevel > 0 {
                    Spacer()
                        .frame(width: CGFloat(indentLevel * 16))
                }

                // Status indicator
                Circle()
                    .fill(server.statusColor)
                    .frame(width: 6, height: 6)

                // Server name
                Text(server.displayName)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()

                // Enabled toggle
                Button(action: onToggle) {
                    Image(systemName: server.enabled ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11))
                        .foregroundColor(server.enabled ? .green : DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                isSelected ?
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignSystem.Colors.surfaceSecondary.opacity(0.5)) :
                    nil
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onSelect) {
                Label("Open", systemImage: "arrow.up.forward.app")
            }

            Divider()

            Button(action: onToggle) {
                Label(server.enabled ? "Disable" : "Enable", systemImage: server.enabled ? "xmark.circle" : "checkmark.circle")
            }

            if server.canStart {
                Button(action: { /* TODO: Start server */ }) {
                    Label("Start Server", systemImage: "play.circle")
                }
            }

            if server.canStop {
                Button(action: { /* TODO: Stop server */ }) {
                    Label("Stop Server", systemImage: "stop.circle")
                }
            }

            Divider()

            Button(role: .destructive, action: { /* TODO: Delete server */ }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
