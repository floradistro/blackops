import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sidebar MCP Servers Section
// Premium monochromatic design

struct SidebarMCPServersSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.sidebarMCPServersExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .rotationEffect(.degrees(store.sidebarMCPServersExpanded ? 90 : 0))
                        .frame(width: 12)

                    Image(systemName: "server.rack")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))

                    Text("MCP Servers")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.85))

                    Spacer()

                    LoadingCountBadge(
                        count: store.mcpServers.count,
                        isLoading: store.isLoadingMCPServers
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded Content
            if store.sidebarMCPServersExpanded {
                if store.mcpServers.isEmpty {
                    Text("No MCP servers available")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
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
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isExpanded {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.35))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)

                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.45))

                    Text(category.capitalized)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.7))

                    Spacer()

                    Text("(\(servers.count))")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
                .padding(.leading, 20)
                .padding(.trailing, 12)
                .padding(.vertical, 4)
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
        HStack(spacing: 6) {
            // Active indicator
            Circle()
                .fill(Color.primary.opacity((server.isActive ?? true) ? 0.4 : 0.15))
                .frame(width: 5, height: 5)

            // Icon
            Image(systemName: "bolt")
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity((server.isReadOnly ?? false) ? 0.35 : 0.5))

            // Name
            Text(server.name)
                .font(.system(size: 10.5))
                .foregroundStyle(Color.primary.opacity(0.8))
                .lineLimit(1)

            Spacer()

            // Read-only indicator
            if server.isReadOnly ?? false {
                Image(systemName: "lock")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.primary.opacity(0.35))
            }
        }
        .padding(.leading, 40)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(
            store.selectedMCPServer?.id == server.id ?
                Color.primary.opacity(0.08) : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.openMCPServer(server)
        }
        .onDrag {
            let dragString = DragItemType.encode(.mcpServer, uuid: server.id)
            let provider = NSItemProvider(object: dragString as NSString)
            return provider
        }
    }
}
