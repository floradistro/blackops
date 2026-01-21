import SwiftUI

// MARK: - Sidebar Queues Section
// Following Apple engineering standards
// Shows expandable locations with queue entries (customers in line)
// Clicking a queue entry opens the cart panel

struct SidebarQueuesSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedLocationIds: Set<UUID> = []

    var body: some View {
        TreeSectionHeader(
            title: "QUEUES",
            isExpanded: $store.sidebarQueuesExpanded,
            count: store.locations.count
        )
        .padding(.top, DesignSystem.Spacing.xxs)

        if store.sidebarQueuesExpanded {
            ForEach(store.locations) { location in
                LocationQueueRow(
                    location: location,
                    isExpanded: expandedLocationIds.contains(location.id),
                    onToggleExpanded: {
                        if expandedLocationIds.contains(location.id) {
                            expandedLocationIds.remove(location.id)
                        } else {
                            expandedLocationIds.insert(location.id)
                        }
                    },
                    onSelectEntry: { queueEntry in
                        store.openTab(.cart(queueEntry))
                    }
                )
            }

            // Empty state
            if store.locations.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("No locations")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
    }
}

// MARK: - Location Queue Row

private struct LocationQueueRow: View {
    let location: Location
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onSelectEntry: (QueueEntry) -> Void

    @StateObject private var queueStore: LocationQueueStore

    init(
        location: Location,
        isExpanded: Bool,
        onToggleExpanded: @escaping () -> Void,
        onSelectEntry: @escaping (QueueEntry) -> Void
    ) {
        self.location = location
        self.isExpanded = isExpanded
        self.onToggleExpanded = onToggleExpanded
        self.onSelectEntry = onSelectEntry
        self._queueStore = StateObject(wrappedValue: LocationQueueStore.shared(for: location.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Location header (expandable)
            Button {
                onToggleExpanded()
            } label: {
                HStack(spacing: 6) {
                    Spacer().frame(width: 10)

                    // Chevron
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .font(.system(size: 9))
                        .frame(width: 10, alignment: .center)

                    // Icon
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                        .frame(width: 14, alignment: .center)

                    // Location name
                    Text(location.name)
                        .font(.system(size: 10.5))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    // Queue count
                    if queueStore.count > 0 {
                        Text("\(queueStore.count)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    // Active indicator
                    if location.isActive == true {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                    }

                    // Realtime indicator
                    if queueStore.connectionState == .connected {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                    }
                }
                .frame(height: 24)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)

            // Queue entries (when expanded)
            if isExpanded {
                ForEach(queueStore.queue) { entry in
                    QueueEntryRow(
                        entry: entry,
                        onSelect: { onSelectEntry(entry) }
                    )
                }

                // Empty queue state
                if queueStore.queue.isEmpty {
                    HStack {
                        Spacer().frame(width: 24 + 14) // Indent
                        Text("No customers in queue")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .frame(height: 24)
                    .padding(.horizontal, 12)
                }
            }
        }
        .task {
            await queueStore.loadQueue()
            queueStore.subscribeToRealtime()
        }
    }
}

// MARK: - Queue Entry Row

private struct QueueEntryRow: View {
    let entry: QueueEntry
    let onSelect: () -> Void

    private var customerName: String {
        if let firstName = entry.customerFirstName, let lastName = entry.customerLastName {
            return "\(firstName) \(lastName)"
        }
        return "Guest"
    }

    private var hasItems: Bool {
        entry.cartItemCount > 0
    }

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 6) {
                // Double indent for entry level
                Spacer().frame(width: 24 + 14)

                // Status indicator (green if has items, gray if empty)
                Circle()
                    .fill(hasItems ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)

                // Customer name
                Text(customerName)
                    .font(.system(size: 10))
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Cart info
                if hasItems {
                    HStack(spacing: 4) {
                        Text("\(entry.cartItemCount)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)

                        Text("·")
                            .foregroundStyle(.tertiary)

                        Text(formatCurrency(entry.cartTotal))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Empty")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}
