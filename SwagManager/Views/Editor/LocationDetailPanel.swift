import SwiftUI

// MARK: - Location Detail Panel
// Following Apple engineering standards

struct LocationDetailPanel: View {
    let location: Location
    @ObservedObject var store: EditorStore

    var locationOrders: [Order] {
        store.ordersForLocation(location.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 24))
                                .foregroundStyle(.purple)

                            Text(location.name)
                                .font(DesignSystem.Typography.title2)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }

                        if let city = location.city, let state = location.state {
                            Text("\(city), \(state)")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    // Active status
                    if location.isActive == true {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Active")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))

                // Contact Info
                if location.address != nil || location.phone != nil || location.email != nil {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("CONTACT")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .tracking(0.5)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            if let address = location.address {
                                LocationContactRow(icon: "location", value: address)
                            }
                            if let phone = location.phone {
                                LocationContactRow(icon: "phone", value: phone)
                            }
                            if let email = location.email {
                                LocationContactRow(icon: "envelope", value: email)
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                }

                // Orders at this location
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Text("ORDERS")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .tracking(0.5)

                        Spacer()

                        Text("\(locationOrders.count)")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(Capsule())
                    }

                    if locationOrders.isEmpty {
                        Text("No orders at this location")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(DesignSystem.Spacing.xl)
                    } else {
                        ForEach(locationOrders) { order in
                            Button {
                                store.openOrder(order)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                                        Text(order.displayTitle)
                                            .font(DesignSystem.Typography.body)
                                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                                        Text(order.statusLabel)
                                            .font(DesignSystem.Typography.caption1)
                                            .foregroundStyle(order.statusColor)
                                    }

                                    Spacer()

                                    Text(order.displayTotal)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(DesignSystem.Colors.surfaceTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))

                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.surfacePrimary)
    }
}

// MARK: - Supporting Views

private struct LocationContactRow: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .frame(width: 20)

            Text(value)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
}
