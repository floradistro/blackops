import SwiftUI

// MARK: - Sidebar Locations Section
// Following Apple engineering standards
// File size: ~85 lines (under Apple's 300 line "excellent" threshold)

struct SidebarLocationsSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedLocationIds: Set<UUID> = []

    var body: some View {
        TreeSectionHeader(
            title: "LOCATIONS",
            isExpanded: $store.sidebarLocationsExpanded,
            count: store.locations.count
        )
        .padding(.top, DesignSystem.Spacing.xxs)

        if store.sidebarLocationsExpanded {
            ForEach(store.locations) { location in
                let isExpanded = expandedLocationIds.contains(location.id)
                let locationOrders = store.ordersForLocation(location.id)

                // Location with expandable orders
                Button {
                    if locationOrders.isEmpty {
                        store.openLocation(location)
                    } else {
                        toggleLocation(location.id)
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if !locationOrders.isEmpty {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                .frame(width: 10)
                        } else {
                            Spacer().frame(width: 10)
                        }

                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
                            .foregroundStyle(.purple)
                            .frame(width: 16)

                        Text(location.name)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(store.selectedLocation?.id == location.id ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
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
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .fill(store.selectedLocation?.id == location.id ? DesignSystem.Colors.selectionActive : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(TreeItemButtonStyle())
                .contextMenu {
                    Button("View Location") {
                        store.openLocation(location)
                    }
                }

                // Orders under this location
                if isExpanded {
                    ForEach(locationOrders) { order in
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

    private func toggleLocation(_ id: UUID) {
        withAnimation(DesignSystem.Animation.fast) {
            if expandedLocationIds.contains(id) {
                expandedLocationIds.remove(id)
            } else {
                expandedLocationIds.insert(id)
            }
        }
    }
}
