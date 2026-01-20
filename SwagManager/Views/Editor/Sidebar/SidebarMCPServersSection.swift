import SwiftUI

// MARK: - Sidebar MCP Servers Section
// Following Apple engineering standards

struct SidebarMCPServersSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    store.sidebarMCPServersExpanded.toggle()
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: store.sidebarMCPServersExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Image(systemName: "server.rack")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.indigo)

                    Text("MCP Servers")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(store.mcpServers.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded Content
            if store.sidebarMCPServersExpanded {
                if store.mcpServers.isEmpty {
                    Text("No MCP servers available")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                } else {
                    // Group by category
                    ForEach(store.mcpServerCategories, id: \.self) { category in
                        categorySection(category)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func categorySection(_ category: String) -> some View {
        let servers = store.mcpServersByCategory(category)
        let isExpanded = expandedCategories.contains(category)

        VStack(alignment: .leading, spacing: 0) {
            // Category Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)

                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text(category.capitalized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(servers.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, DesignSystem.Spacing.lg)
                .padding(.trailing, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Category Servers
            if isExpanded {
                ForEach(servers) { server in
                    mcpServerRow(server)
                }
            }
        }
    }

    @ViewBuilder
    private func mcpServerRow(_ server: MCPServer) -> some View {
        Button(action: {
            store.openMCPServer(server)
        }) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: server.isActive ? "circle.fill" : "circle")
                    .font(.system(size: 8))
                    .foregroundStyle(server.isActive ? .green : .secondary)
                    .frame(width: 12)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(server.isReadOnly ? .secondary : Color.indigo)

                Text(server.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if server.isReadOnly {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, DesignSystem.Spacing.xl + DesignSystem.Spacing.sm)
            .padding(.trailing, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                store.selectedMCPServer?.id == server.id ?
                    Color.accentColor.opacity(0.15) : Color.clear
            )
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
