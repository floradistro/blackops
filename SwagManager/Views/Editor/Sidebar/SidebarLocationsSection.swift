import SwiftUI

// MARK: - Sidebar Locations & Orders Section
// Premium monochromatic hierarchical tree

struct SidebarLocationsSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedLocationIds: Set<UUID> = []
    @State private var expandedMonths: Set<String> = []
    @State private var expandedDays: Set<String> = []

    // UUID for "No Location" section
    private static let nilLocationId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    var body: some View {
        TreeSectionHeader(
            title: "Locations",
            icon: "mappin.and.ellipse",
            iconColor: nil,
            isExpanded: $store.sidebarLocationsExpanded,
            count: store.orders.count,
            isLoading: store.isLoadingOrders || store.isLoadingLocations,
            realtimeConnected: store.ordersRealtimeConnected
        )
        .padding(.top, DesignSystem.TreeSpacing.sectionPaddingTop)

        if store.sidebarLocationsExpanded {
            VStack(spacing: 0) {
                // Locations
                ForEach(store.locations) { location in
                    locationSection(location)
                }

                // Orders without location
                if !ordersWithoutLocation.isEmpty {
                    noLocationSection()
                }
            }

            // Empty state
            if store.locations.isEmpty && store.orders.isEmpty {
                emptyState
            }
        }
    }

    // MARK: - Computed Properties

    private var ordersWithoutLocation: [Order] {
        store.orders.filter { $0.locationId == nil && $0.pickupLocationId == nil }
    }

    // MARK: - Location Section

    @ViewBuilder
    private func locationSection(_ location: Location) -> some View {
        let isExpanded = expandedLocationIds.contains(location.id)
        let orders = store.ordersForLocation(location.id)

        // Location header
        TreeRowButton(
            isExpanded: isExpanded,
            icon: "mappin.and.ellipse",
            title: location.name,
            count: orders.count,
            showActiveBadge: location.isActive == true,
            indentLevel: 0,
            action: { toggleLocation(location.id) }
        )

        // Expanded months
        if isExpanded {
            let ordersByMonth = groupOrdersByMonth(orders)
            ForEach(ordersByMonth.keys.sorted(by: >), id: \.self) { monthKey in
                monthSection(
                    locationId: location.id,
                    monthKey: monthKey,
                    orders: ordersByMonth[monthKey] ?? []
                )
            }
        }
    }

    // MARK: - No Location Section

    @ViewBuilder
    private func noLocationSection() -> some View {
        let isExpanded = expandedLocationIds.contains(Self.nilLocationId)

        TreeRowButton(
            isExpanded: isExpanded,
            icon: "questionmark.circle",
            title: "No Location",
            count: ordersWithoutLocation.count,
            indentLevel: 0,
            action: { toggleLocation(Self.nilLocationId) }
        )

        if isExpanded {
            let ordersByMonth = groupOrdersByMonth(ordersWithoutLocation)
            ForEach(ordersByMonth.keys.sorted(by: >), id: \.self) { monthKey in
                monthSection(
                    locationId: Self.nilLocationId,
                    monthKey: monthKey,
                    orders: ordersByMonth[monthKey] ?? []
                )
            }
        }
    }

    // MARK: - Month Section

    @ViewBuilder
    private func monthSection(locationId: UUID, monthKey: String, orders: [Order]) -> some View {
        let expandKey = "\(locationId)-\(monthKey)"
        let isExpanded = expandedMonths.contains(expandKey)

        TreeRowButton(
            isExpanded: isExpanded,
            icon: "calendar",
            title: formatMonthKey(monthKey),
            count: orders.count,
            indentLevel: 1,
            action: { toggleMonth(locationId, monthKey) }
        )

        if isExpanded {
            let ordersByDay = groupOrdersByDay(orders)
            ForEach(ordersByDay.keys.sorted(by: >), id: \.self) { dayKey in
                daySection(
                    locationId: locationId,
                    monthKey: monthKey,
                    dayKey: dayKey,
                    orders: ordersByDay[dayKey] ?? []
                )
            }
        }
    }

    // MARK: - Day Section

    @ViewBuilder
    private func daySection(locationId: UUID, monthKey: String, dayKey: String, orders: [Order]) -> some View {
        let expandKey = "\(locationId)-\(monthKey)-\(dayKey)"
        let isExpanded = expandedDays.contains(expandKey)

        TreeRowButton(
            isExpanded: isExpanded,
            icon: nil,
            title: formatDayKey(dayKey),
            count: orders.count,
            indentLevel: 2,
            action: { toggleDay(locationId, monthKey, dayKey) }
        )

        if isExpanded {
            ForEach(orders) { order in
                OrderTreeItem(
                    order: order,
                    isSelected: false,
                    isActive: store.selectedOrder?.id == order.id,
                    indentLevel: 3,
                    onSelect: { store.openOrder(order) }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack {
            Spacer()
            Text("No locations or orders")
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.4))
            Spacer()
        }
        .padding(.vertical, 12)
    }

    // MARK: - Toggle Functions

    private func toggleLocation(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedLocationIds.contains(id) {
                expandedLocationIds.remove(id)
            } else {
                expandedLocationIds.insert(id)
            }
        }
    }

    private func toggleMonth(_ locationId: UUID, _ monthKey: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            let key = "\(locationId)-\(monthKey)"
            if expandedMonths.contains(key) {
                expandedMonths.remove(key)
            } else {
                expandedMonths.insert(key)
            }
        }
    }

    private func toggleDay(_ locationId: UUID, _ monthKey: String, _ dayKey: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            let key = "\(locationId)-\(monthKey)-\(dayKey)"
            if expandedDays.contains(key) {
                expandedDays.remove(key)
            } else {
                expandedDays.insert(key)
            }
        }
    }

    // MARK: - Grouping Functions

    private func groupOrdersByMonth(_ orders: [Order]) -> [String: [Order]] {
        var grouped: [String: [Order]] = [:]
        let calendar = Calendar.current

        for order in orders {
            guard let date = order.createdAt else { continue }
            let components = calendar.dateComponents([.year, .month], from: date)
            let key = String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
            grouped[key, default: []].append(order)
        }

        return grouped
    }

    private func groupOrdersByDay(_ orders: [Order]) -> [String: [Order]] {
        var grouped: [String: [Order]] = [:]
        let calendar = Calendar.current

        for order in orders {
            guard let date = order.createdAt else { continue }
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            let key = String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
            grouped[key, default: []].append(order)
        }

        return grouped
    }

    // MARK: - Formatting Functions

    private func formatMonthKey(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else {
            return key
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else {
            return key
        }

        return formatter.string(from: date)
    }

    private func formatDayKey(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return key
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = Calendar.current.date(from: components) else {
            return key
        }

        return formatter.string(from: date)
    }
}

// MARK: - Tree Row Button (Monochromatic)

private struct TreeRowButton: View {
    let isExpanded: Bool
    let icon: String?
    let title: String
    let count: Int
    var showActiveBadge: Bool = false
    let indentLevel: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Indentation
                if indentLevel > 0 {
                    Color.clear.frame(width: CGFloat(indentLevel) * 14)
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)

                // Icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .frame(width: 14)
                }

                // Title
                Text(title)
                    .font(.system(size: indentLevel == 0 ? 11 : 10.5, weight: indentLevel == 0 ? .medium : .regular))
                    .foregroundStyle(Color.primary.opacity(indentLevel == 0 ? 0.85 : 0.75))
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Active badge
                if showActiveBadge {
                    Circle()
                        .fill(Color.primary.opacity(0.3))
                        .frame(width: 5, height: 5)
                }

                // Count
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.45))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
