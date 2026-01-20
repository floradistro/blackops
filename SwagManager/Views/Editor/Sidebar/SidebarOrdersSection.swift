import SwiftUI

// MARK: - Sidebar Orders Section
// Following Apple engineering standards
// File size: ~120 lines (under Apple's 300 line "excellent" threshold)

struct SidebarOrdersSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedStatuses: Set<String> = ["pending", "processing"]

    var body: some View {
        TreeSectionHeader(
            title: "ORDERS",
            isExpanded: $store.sidebarOrdersExpanded,
            count: store.orders.count
        )
        .padding(.top, DesignSystem.Spacing.xxs)

        if store.sidebarOrdersExpanded {
            // Pending Orders
            if !store.pendingOrders.isEmpty {
                OrderStatusGroup(
                    title: "Pending",
                    orders: store.pendingOrders,
                    color: .orange,
                    isExpanded: expandedStatuses.contains("pending"),
                    onToggle: { toggleStatus("pending") },
                    store: store
                )
            }

            // Processing Orders
            if !store.processingOrders.isEmpty {
                OrderStatusGroup(
                    title: "Processing",
                    orders: store.processingOrders,
                    color: .purple,
                    isExpanded: expandedStatuses.contains("processing"),
                    onToggle: { toggleStatus("processing") },
                    store: store
                )
            }

            // Ready Orders
            if !store.readyOrders.isEmpty {
                OrderStatusGroup(
                    title: "Ready",
                    orders: store.readyOrders,
                    color: .cyan,
                    isExpanded: expandedStatuses.contains("ready"),
                    onToggle: { toggleStatus("ready") },
                    store: store
                )
            }

            // Shipped Orders
            if !store.shippedOrders.isEmpty {
                OrderStatusGroup(
                    title: "Shipped",
                    orders: store.shippedOrders,
                    color: .indigo,
                    isExpanded: expandedStatuses.contains("shipped"),
                    onToggle: { toggleStatus("shipped") },
                    store: store
                )
            }

            // Completed Orders (collapsed by default)
            if !store.completedOrders.isEmpty {
                OrderStatusGroup(
                    title: "Completed",
                    orders: store.completedOrders,
                    color: .green,
                    isExpanded: expandedStatuses.contains("completed"),
                    onToggle: { toggleStatus("completed") },
                    store: store
                )
            }

            // Empty state
            if store.orders.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("No orders yet")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
    }

    private func toggleStatus(_ status: String) {
        withAnimation(DesignSystem.Animation.fast) {
            if expandedStatuses.contains(status) {
                expandedStatuses.remove(status)
            } else {
                expandedStatuses.insert(status)
            }
        }
    }
}

// MARK: - Order Status Group

struct OrderStatusGroup: View {
    let title: String
    let orders: [Order]
    let color: Color
    let isExpanded: Bool
    let onToggle: () -> Void
    @ObservedObject var store: EditorStore

    var body: some View {
        // Status header
        Button(action: onToggle) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)

                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Text("\(orders.count)")
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

        // Order items
        if isExpanded {
            ForEach(orders) { order in
                OrderTreeItem(
                    order: order,
                    isSelected: false,
                    isActive: store.selectedOrder?.id == order.id,
                    indentLevel: 1,
                    onSelect: { store.openOrder(order) }
                )
            }
        }
    }
}
