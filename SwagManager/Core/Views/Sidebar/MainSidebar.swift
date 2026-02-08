import SwiftUI

// MARK: - Main Sidebar
// Flat navigation — agents and telemetry only

struct MainSidebar: View {
    @Binding var selection: SDSidebarItem?
    @Environment(\.editorStore) private var store

    @State private var agentsCount: Int = 0

    var body: some View {
        List(selection: $selection) {
            Section("AI") {
                SidebarRow(
                    item: .agents,
                    icon: "cpu",
                    title: "Agents",
                    badge: agentsCount
                )

                SidebarRow(
                    item: .telemetry,
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Telemetry",
                    badge: 0
                )
            }
        }
        .listStyle(.sidebar)
        .task(id: store.selectedStore?.id) {
            agentsCount = store.aiAgents.count
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                agentsCount = store.aiAgents.count
            }
        }
        .freezeDebugLifecycle("MainSidebar")
    }
}

// MARK: - Sidebar Row

struct SidebarRow: View {
    let item: SDSidebarItem
    let icon: String
    let title: String
    var badge: Int = 0

    var body: some View {
        NavigationLink(value: item) {
            Label {
                HStack {
                    Text(title)
                    Spacer()
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

// MARK: - Store Dropdown

struct StoreDropdown: View {
    @Environment(\.editorStore) private var store

    var body: some View {
        Menu {
            ForEach(store.stores) { s in
                Button {
                    Task { await store.selectStore(s) }
                } label: {
                    Text(s.storeName)
                }
            }

            if store.stores.isEmpty {
                Text("Loading stores...")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button {
                store.showNewStoreSheet = true
            } label: {
                Label("Add Store...", systemImage: "plus")
            }
        } label: {
            Text(store.selectedStore?.storeName ?? "Select Store")
        }
        .menuStyle(.borderedButton)
        .fixedSize()
    }
}

// MARK: - Count Badge

struct CountBadge: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color, in: Capsule())
    }
}
