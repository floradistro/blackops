import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sidebar MCP Servers Section
// Following Apple engineering standards

struct SidebarMCPServersSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(DesignSystem.Animation.spring) {
                    store.sidebarMCPServersExpanded.toggle()
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(store.sidebarMCPServersExpanded ? 90 : 0))
                        .frame(width: 16)

                    Image(systemName: "server.rack")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.35, green: 0.38, blue: 0.95))

                    Text("MCP Servers")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()

                    LoadingCountBadge(
                        count: store.mcpServers.count,
                        isLoading: store.isLoadingMCPServers
                    )
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded Content
            if store.sidebarMCPServersExpanded {
                if store.mcpServers.isEmpty {
                    Text("No MCP servers available")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
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
                withAnimation(DesignSystem.Animation.fast) {
                    if isExpanded {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)

                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(category.capitalized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()

                    Text("(\(servers.count))")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .padding(.leading, DesignSystem.Spacing.md)
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
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: (server.isActive ?? true) ? "circle.fill" : "circle")
                .font(.system(size: 8))
                .foregroundColor((server.isActive ?? true) ? DesignSystem.Colors.green : DesignSystem.Colors.textSecondary)
                .frame(width: 12)

            Image(systemName: "bolt.fill")
                .font(.system(size: 11))
                .foregroundColor((server.isReadOnly ?? false) ? DesignSystem.Colors.textSecondary : Color(red: 0.35, green: 0.38, blue: 0.95))

            Text(server.name)
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(1)

            Spacer()

            if server.isReadOnly ?? false {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.leading, 40)
        .padding(.trailing, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .background(
            store.selectedMCPServer?.id == server.id ?
                DesignSystem.Colors.selectionActive : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.openMCPServer(server)
        }
        .onDrag {
            print("🚀 Starting drag for MCP server: \(server.name) (\(server.id))")
            let dragString = DragItemType.encode(.mcpServer, uuid: server.id)
            print("🔑 Drag data: \(dragString)")

            let provider = NSItemProvider(object: dragString as NSString)
            print("✅ NSItemProvider created successfully")
            return provider
        }
    }
}
