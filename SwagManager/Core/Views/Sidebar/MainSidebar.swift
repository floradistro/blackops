import SwiftUI
import SwiftData

// MARK: - Main Sidebar
// Simple flat navigation like macOS/iOS Settings
// No expandable trees - just top-level sections that open in main content

struct MainSidebar: View {
    @Binding var selection: SDSidebarItem?
    var store: EditorStore
    var syncService: SyncService

    // SwiftData queries
    @Query(sort: \SDLocation.name) private var allLocations: [SDLocation]
    @Query(filter: SDOrder.activePredicate, sort: \SDOrder.createdAt, order: .reverse)
    private var allActiveOrders: [SDOrder]

    // Cached counts (avoid filtering on every render)
    @State private var locationCount: Int = 0
    @State private var activeOrderCount: Int = 0

    var body: some View {
        List(selection: $selection) {
            // WORKSPACE
            Section("Workspace") {
                SidebarRow(
                    item: .orders,
                    icon: "shippingbox.fill",
                    title: "Orders",
                    badge: activeOrderCount
                )

                SidebarRow(
                    item: .locations,
                    icon: "building.2.fill",
                    title: "Locations",
                    badge: locationCount
                )

                SidebarRow(
                    item: .customers,
                    icon: "person.crop.circle.fill",
                    title: "Customers",
                    badge: store.customers.count
                )
            }

            // CONTENT
            Section("Content") {
                SidebarRow(
                    item: .catalogs,
                    icon: "folder.fill",
                    title: "Catalogs",
                    badge: store.categories.count
                )

                SidebarRow(
                    item: .creations,
                    icon: "paintbrush.pointed.fill",
                    title: "Creations",
                    badge: store.creations.count
                )

                SidebarRow(
                    item: .teamChat,
                    icon: "message.fill",
                    title: "Team Chat",
                    badge: store.conversations.count
                )
            }

            // OPERATIONS
            Section("Operations") {
                SidebarRow(
                    item: .browserSessions,
                    icon: "safari.fill",
                    title: "Browser",
                    badge: store.browserSessions.count
                )

                SidebarRow(
                    item: .emails,
                    icon: "envelope.fill",
                    title: "Emails",
                    badge: store.emailTotalCount
                )
            }

            // AI
            Section("AI") {
                SidebarRow(
                    item: .aiChat,
                    icon: "bubble.left.and.text.bubble.right.fill",
                    title: "AI Chat",
                    badge: 0
                )

                SidebarRow(
                    item: .agents,
                    icon: "gearshape.2.fill",
                    title: "Agents",
                    badge: store.aiAgents.count
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
        .navigationTitle("WhaleTools")
        .task(id: store.selectedStore?.id) {
            updateCounts()
        }
        .onChange(of: allLocations.count) { _, _ in updateCounts() }
        .onChange(of: allActiveOrders.count) { _, _ in updateCounts() }
    }

    private func updateCounts() {
        guard let storeId = store.selectedStore?.id else {
            locationCount = 0
            activeOrderCount = 0
            return
        }
        locationCount = allLocations.filter { $0.storeId == storeId }.count
        activeOrderCount = allActiveOrders.filter { $0.location?.storeId == storeId }.count
    }
}

// MARK: - Sidebar Row
// Simple flat row with icon, title, and optional badge

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
// Native macOS picker style - no custom styling

struct StoreDropdown: View {
    var store: EditorStore

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
