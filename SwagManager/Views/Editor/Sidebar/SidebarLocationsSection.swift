import SwiftUI

// MARK: - Sidebar Locations & Orders Section
// Following Apple engineering standards
// Hierarchical tree: Location > Month > Day > Orders

struct SidebarLocationsSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedLocationIds: Set<UUID> = []
    @State private var expandedMonths: Set<String> = []
    @State private var expandedDays: Set<String> = []

    var body: some View {
        TreeSectionHeader(
            title: "LOCATIONS & ORDERS",
            isExpanded: $store.sidebarLocationsExpanded,
            count: store.orders.count
        )
        .padding(.top, DesignSystem.Spacing.xxs)

        if store.sidebarLocationsExpanded {
            // Show orders for each location
            ForEach(store.locations) { location in
                let isLocationExpanded = expandedLocationIds.contains(location.id)
                let locationOrders = store.ordersForLocation(location.id)

                // Location header
                Button {
                    toggleLocation(location.id)
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .rotationEffect(.degrees(isLocationExpanded ? 90 : 0))
                            .frame(width: 10)

                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
                            .foregroundStyle(.purple)
                            .frame(width: 16)

                        Text(location.name)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        if !locationOrders.isEmpty {
                            Text("\(locationOrders.count)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                        }

                        if location.isActive == true {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TreeItemButtonStyle())

                // Month > Day > Orders hierarchy
                if isLocationExpanded {
                    let ordersByMonth = groupOrdersByMonth(locationOrders)
                    ForEach(ordersByMonth.keys.sorted(by: >), id: \.self) { monthKey in
                        let monthOrders = ordersByMonth[monthKey] ?? []
                        let isMonthExpanded = expandedMonths.contains("\(location.id)-\(monthKey)")

                        // Month header
                        Button {
                            toggleMonth(location.id, monthKey)
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Spacer().frame(width: 10)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .rotationEffect(.degrees(isMonthExpanded ? 90 : 0))
                                    .frame(width: 10)

                                Image(systemName: "calendar")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.cyan)
                                    .frame(width: 16)

                                Text(formatMonthKey(monthKey))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                                Text("\(monthOrders.count)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .padding(.horizontal, DesignSystem.Spacing.xs)
                                    .padding(.vertical, 2)
                                    .background(DesignSystem.Colors.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))

                                Spacer()
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(TreeItemButtonStyle())

                        // Days within month
                        if isMonthExpanded {
                            let ordersByDay = groupOrdersByDay(monthOrders)
                            ForEach(ordersByDay.keys.sorted(by: >), id: \.self) { dayKey in
                                let dayOrders = ordersByDay[dayKey] ?? []
                                let isDayExpanded = expandedDays.contains("\(location.id)-\(monthKey)-\(dayKey)")

                                // Day header
                                Button {
                                    toggleDay(location.id, monthKey, dayKey)
                                } label: {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Spacer().frame(width: 20)

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                                            .rotationEffect(.degrees(isDayExpanded ? 90 : 0))
                                            .frame(width: 10)

                                        Text(formatDayKey(dayKey))
                                            .font(.system(size: 10))
                                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                                        Text("\(dayOrders.count)")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                                            .padding(.horizontal, DesignSystem.Spacing.xs)
                                            .padding(.vertical, 2)
                                            .background(DesignSystem.Colors.surfaceElevated)
                                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))

                                        Spacer()
                                    }
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                    .padding(.vertical, DesignSystem.Spacing.xs)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(TreeItemButtonStyle())

                                // Orders within day
                                if isDayExpanded {
                                    ForEach(dayOrders) { order in
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
                        }
                    }
                }
            }

            // Orders without location
            let ordersWithoutLocation = store.orders.filter { $0.locationId == nil && $0.pickupLocationId == nil }
            if !ordersWithoutLocation.isEmpty {
                let isExpanded = expandedLocationIds.contains(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)

                // "Unknown Location" header
                Button {
                    toggleLocation(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 10)

                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                            .frame(width: 16)

                        Text("No Location")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(ordersWithoutLocation.count)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .padding(.horizontal, DesignSystem.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TreeItemButtonStyle())

                // Month > Day > Orders hierarchy for orders without location
                if isExpanded {
                    let ordersByMonth = groupOrdersByMonth(ordersWithoutLocation)
                    ForEach(ordersByMonth.keys.sorted(by: >), id: \.self) { monthKey in
                        let monthOrders = ordersByMonth[monthKey] ?? []
                        let isMonthExpanded = expandedMonths.contains("unknown-\(monthKey)")

                        // Month header
                        Button {
                            toggleMonth(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, monthKey)
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Spacer().frame(width: 10)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .rotationEffect(.degrees(isMonthExpanded ? 90 : 0))
                                    .frame(width: 10)

                                Image(systemName: "calendar")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.cyan)
                                    .frame(width: 16)

                                Text(formatMonthKey(monthKey))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                                Text("\(monthOrders.count)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .padding(.horizontal, DesignSystem.Spacing.xs)
                                    .padding(.vertical, 2)
                                    .background(DesignSystem.Colors.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))

                                Spacer()
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(TreeItemButtonStyle())

                        // Days within month
                        if isMonthExpanded {
                            let ordersByDay = groupOrdersByDay(monthOrders)
                            ForEach(ordersByDay.keys.sorted(by: >), id: \.self) { dayKey in
                                let dayOrders = ordersByDay[dayKey] ?? []
                                let isDayExpanded = expandedDays.contains("unknown-\(monthKey)-\(dayKey)")

                                // Day header
                                Button {
                                    toggleDay(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, monthKey, dayKey)
                                } label: {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Spacer().frame(width: 20)

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                                            .rotationEffect(.degrees(isDayExpanded ? 90 : 0))
                                            .frame(width: 10)

                                        Text(formatDayKey(dayKey))
                                            .font(.system(size: 10))
                                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                                        Text("\(dayOrders.count)")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                                            .padding(.horizontal, DesignSystem.Spacing.xs)
                                            .padding(.vertical, 2)
                                            .background(DesignSystem.Colors.surfaceElevated)
                                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))

                                        Spacer()
                                    }
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                    .padding(.vertical, DesignSystem.Spacing.xs)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(TreeItemButtonStyle())

                                // Orders within day
                                if isDayExpanded {
                                    ForEach(dayOrders) { order in
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
                        }
                    }
                }
            }

            // Empty state
            if store.locations.isEmpty && store.orders.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("No locations or orders")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
    }

    private func toggleLocation(_ id: UUID) {
        withAnimation(DesignSystem.Animation.fast) {
            if expandedLocationIds.contains(id) {
                expandedLocationIds.remove(id)
            } else {
                expandedLocationIds.insert(id)
            }
        }
    }

    private func toggleMonth(_ locationId: UUID, _ monthKey: String) {
        withAnimation(DesignSystem.Animation.fast) {
            let key = "\(locationId)-\(monthKey)"
            if expandedMonths.contains(key) {
                expandedMonths.remove(key)
            } else {
                expandedMonths.insert(key)
            }
        }
    }

    private func toggleDay(_ locationId: UUID, _ monthKey: String, _ dayKey: String) {
        withAnimation(DesignSystem.Animation.fast) {
            let key = "\(locationId)-\(monthKey)-\(dayKey)"
            if expandedDays.contains(key) {
                expandedDays.remove(key)
            } else {
                expandedDays.insert(key)
            }
        }
    }

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
        formatter.dateFormat = "MMM d"
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = Calendar.current.date(from: components) else {
            return key
        }

        return formatter.string(from: date)
    }
}
