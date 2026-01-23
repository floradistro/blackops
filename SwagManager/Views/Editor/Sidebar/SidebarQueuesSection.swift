import SwiftUI

// MARK: - Sidebar Queues Section
// Premium monochromatic design with smooth animations

struct SidebarQueuesSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedLocationIds: Set<UUID> = []

    var body: some View {
        TreeSectionHeader(
            title: "Queues",
            icon: "line.3.horizontal",
            iconColor: nil,
            isExpanded: $store.sidebarQueuesExpanded,
            count: store.locations.count
        )
        .padding(.top, 2)

        if store.sidebarQueuesExpanded {
            LazyVStack(spacing: 0) {
                ForEach(store.locations) { location in
                    LocationQueueRow(
                        location: location,
                        isExpanded: expandedLocationIds.contains(location.id),
                        onToggleExpanded: {
                            withAnimation(TreeAnimations.smoothSpring) {
                                if expandedLocationIds.contains(location.id) {
                                    expandedLocationIds.remove(location.id)
                                } else {
                                    expandedLocationIds.insert(location.id)
                                }
                            }
                        },
                        onSelectEntry: { queueEntry in
                            store.openTab(.cart(queueEntry))
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }
            }

            // Empty state
            if store.locations.isEmpty {
                HStack {
                    Spacer()
                    Text("No locations")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.4))
                    Spacer()
                }
                .padding(.vertical, 8)
                .transition(.opacity)
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
                    Spacer().frame(width: 8)

                    // Chevron
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .frame(width: 10)

                    // Icon
                    Image(systemName: "person.3")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .frame(width: 14)

                    // Location name
                    Text(location.name)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    // Queue count
                    if queueStore.count > 0 {
                        Text("\(queueStore.count)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }

                    // Active indicator
                    if location.isActive == true {
                        Circle()
                            .fill(Color.primary.opacity(0.3))
                            .frame(width: 5, height: 5)
                    }

                    // Realtime indicator
                    if queueStore.connectionState == .connected {
                        Circle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(width: 4, height: 4)
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
                        Spacer().frame(width: 38)
                        Text("No customers in queue")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.primary.opacity(0.35))
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

// MARK: - Queue Entry Row (Optimized with hover/press states)

private struct QueueEntryRow: View {
    let entry: QueueEntry
    let onSelect: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

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
                Spacer().frame(width: 38)

                // Status indicator with pulse for items
                Circle()
                    .fill(Color.primary.opacity(hasItems ? 0.4 : 0.15))
                    .frame(width: 5, height: 5)
                    .modifier(hasItems ? PulseModifier() : PulseModifier())

                // Customer name
                Text(customerName)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(isHovered ? 0.9 : 0.8))
                    .lineLimit(1)

                // Loyalty points badge (subtle)
                if let points = entry.customerLoyaltyPoints, points > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star")
                            .font(.system(size: 7))
                        Text("\(points)")
                            .font(.system(size: 8, weight: .medium))
                    }
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.05), in: .capsule)
                }

                Spacer(minLength: 4)

                // Cart info
                if hasItems {
                    HStack(spacing: 4) {
                        Text("\(entry.cartItemCount)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.5))

                        Text("·")
                            .foregroundStyle(Color.primary.opacity(0.3))

                        Text(formatCurrency(entry.cartTotal))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                } else {
                    Text("Empty")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.primary.opacity(0.3))
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(
                        isPressed ? 0.08 :
                        isHovered ? 0.04 : 0
                    ))
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.08)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
        )
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}
