import SwiftUI
import SwiftData

// MARK: - Main Sidebar
// Simple flat navigation like macOS/iOS Settings
// No expandable trees - just top-level sections that open in main content

struct MainSidebar: View {
    @Binding var selection: SDSidebarItem?
    var syncService: SyncService
    @Environment(\.editorStore) private var store

    // ALL counts are cached - no direct store property access in body
    @State private var conversationsCount: Int = 0
    @State private var locationsCount: Int = 0
    @State private var emailsCount: Int = 0
    @State private var inboxUnreadCount: Int = 0
    @State private var agentsCount: Int = 0

    var body: some View {
        List(selection: $selection) {
            // CONTENT
            Section("Content") {
                SidebarRow(
                    item: .teamChat,
                    icon: "message.fill",
                    title: "Team Chat",
                    badge: conversationsCount
                )
            }

            // OPERATIONS
            Section("Operations") {
                SidebarRow(
                    item: .locations,
                    icon: "mappin.and.ellipse",
                    title: "Locations",
                    badge: locationsCount
                )

                SidebarRow(
                    item: .emails,
                    icon: "envelope.fill",
                    title: "Emails",
                    badge: emailsCount
                )

                SidebarRow(
                    item: .inbox,
                    icon: "tray.full.fill",
                    title: "Inbox",
                    badge: inboxUnreadCount
                )
            }

            // AI
            Section("AI") {
                SidebarRow(
                    item: .agents,
                    icon: "gearshape.2.fill",
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
        .navigationTitle("WhaleTools")
        .task(id: store.selectedStore?.id) {
            updateAllCounts()
        }
        // Periodic refresh of counts (every 30 seconds) instead of observing store
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                updateStoreCounts()
            }
        }
        .freezeDebugLifecycle("MainSidebar")
    }

    private func updateAllCounts() {
        updateStoreCounts()
    }

    private func updateStoreCounts() {
        conversationsCount = store.conversations.count
        locationsCount = store.locations.count
        emailsCount = store.emailTotalCount
        inboxUnreadCount = store.inboxTotalUnread
        agentsCount = store.aiAgents.count
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
