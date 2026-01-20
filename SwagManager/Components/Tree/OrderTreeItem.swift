import SwiftUI

// MARK: - Order Tree Item
// Following Apple engineering standards
// File size: ~65 lines (under Apple's 300 line "excellent" threshold)

struct OrderTreeItem: View {
    let order: Order
    let isSelected: Bool
    let isActive: Bool
    var indentLevel: Int = 0
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if indentLevel > 0 {
                    Spacer().frame(width: CGFloat(indentLevel * 16))
                }

                Image(systemName: order.orderTypeIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(order.statusColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(order.displayTitle)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                        .lineLimit(1)

                    Text(order.displayTotal)
                        .font(.system(size: 9))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                // Status indicator
                Circle()
                    .fill(order.statusColor)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isActive ? DesignSystem.Colors.selectionActive :
                          isSelected ? DesignSystem.Colors.selection : Color.clear)
            )
            .animation(DesignSystem.Animation.fast, value: isActive)
            .animation(DesignSystem.Animation.fast, value: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}

// MARK: - Location Tree Item

struct LocationTreeItem: View {
    let location: Location
    let isActive: Bool
    let orderCount: Int
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 10))
                    .foregroundStyle(.purple)
                    .frame(width: 16)

                Text(location.name)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()

                if orderCount > 0 {
                    Text("\(orderCount)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                }

                // Active indicator
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
                    .fill(isActive ? DesignSystem.Colors.selectionActive : Color.clear)
            )
            .animation(DesignSystem.Animation.fast, value: isActive)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}
