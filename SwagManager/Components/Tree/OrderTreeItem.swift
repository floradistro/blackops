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
            HStack(spacing: 8) {
                Image(systemName: order.orderTypeIcon)
                    .font(.system(size: 13))
                    .foregroundStyle(order.statusColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(order.displayTitle)
                        .font(.system(size: 13))
                        .foregroundStyle(isActive ? .primary : .secondary)
                        .lineLimit(1)

                    Text(order.displayTotal)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 4)

                Circle()
                    .fill(order.statusColor)
                    .frame(width: 6, height: 6)
            }
            .padding(.leading, 16 + CGFloat(indentLevel) * 16)
            .padding(.trailing, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13))
                    .foregroundStyle(.purple)
                    .frame(width: 16)

                Text(location.name)
                    .font(.system(size: 13))
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if orderCount > 0 {
                    Text("\(orderCount)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                if location.isActive == true {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
