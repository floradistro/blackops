import SwiftUI

// MARK: - Order Tree Item
// Minimal monochromatic theme

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
            HStack(spacing: 6) {
                // Indentation
                if indentLevel > 0 {
                    Color.clear.frame(width: CGFloat(indentLevel) * 14)
                }

                // Order type icon - monochromatic
                Image(systemName: order.orderTypeIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .frame(width: 14)

                // Order info
                VStack(alignment: .leading, spacing: 1) {
                    Text(order.displayTitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.primary.opacity(isActive ? 0.9 : 0.7))
                        .lineLimit(1)

                    Text(order.displayTotal)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }

                Spacer(minLength: 4)

                // Status indicator - monochromatic dot
                Circle()
                    .fill(Color.primary.opacity(statusOpacity))
                    .frame(width: 5, height: 5)
            }
            .frame(height: 28)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusOpacity: Double {
        switch order.status?.lowercased() {
        case "pending": return 0.3
        case "confirmed": return 0.5
        case "processing": return 0.6
        case "completed": return 0.7
        case "cancelled": return 0.2
        default: return 0.4
        }
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
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .frame(width: 14)

                Text(location.name)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.primary.opacity(isActive ? 0.9 : 0.7))
                    .lineLimit(1)

                Spacer(minLength: 4)

                if orderCount > 0 {
                    Text("\(orderCount)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                if location.isActive == true {
                    Circle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 26)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
