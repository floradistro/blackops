import SwiftUI
import UniformTypeIdentifiers

// MARK: - Customer Tree Item
// Minimal monochromatic theme

struct CustomerTreeItem: View {
    let customer: Customer
    let isSelected: Bool
    var isActive: Bool = false
    let indentLevel: Int
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Indentation
            if indentLevel > 0 {
                Color.clear.frame(width: CGFloat(indentLevel) * 14)
            }

            // Icon - monochromatic
            Image(systemName: "person.circle")
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 14)

            // Name
            Text(customer.displayName)
                .font(.system(size: 10.5))
                .foregroundStyle(Color.primary.opacity(isSelected ? 0.9 : 0.7))
                .lineLimit(1)

            Spacer(minLength: 4)

            // Loyalty tier indicator
            if let tier = customer.loyaltyTier {
                Text(tier.prefix(1).uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            // Total spent
            if let spent = customer.totalSpent, spent > 0 {
                Text(customer.formattedTotalSpent)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
        }
        .frame(height: 24)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onDrag {
            let dragString = DragItemType.encode(.customer, uuid: customer.id)
            let provider = NSItemProvider(object: dragString as NSString)
            return provider
        }
    }
}

// MARK: - Customer Tree Item with Details

struct CustomerTreeItemDetailed: View {
    let customer: Customer
    let isSelected: Bool
    var isActive: Bool = false
    let indentLevel: Int
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Avatar or initials
                    if let avatarUrl = customer.avatarUrl {
                        AsyncImage(url: URL(string: avatarUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            initialsCircle
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    } else {
                        initialsCircle
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(customer.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(isSelected ? 0.9 : 0.7))
                            .lineLimit(1)

                        if let email = customer.email {
                            Text(email)
                                .font(.system(size: 9))
                                .foregroundStyle(Color.primary.opacity(0.4))
                                .lineLimit(1)
                        } else if let phone = customer.phone {
                            Text(phone)
                                .font(.system(size: 9))
                                .foregroundStyle(Color.primary.opacity(0.4))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            if customer.idVerified == true {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.primary.opacity(0.5))
                            }

                            if customer.loyaltyTier != nil {
                                Image(systemName: customer.loyaltyTierIcon)
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.primary.opacity(0.5))
                            }
                        }

                        Text(customer.formattedTotalSpent)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.4))
                    }
                }

                // Order count
                if let orderCount = customer.totalOrders, orderCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.primary.opacity(0.35))

                        Text("\(orderCount) orders")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.primary.opacity(0.4))

                        if let points = customer.loyaltyPoints, points > 0 {
                            Text("·")
                                .foregroundStyle(Color.primary.opacity(0.3))

                            Text("\(points) pts")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.primary.opacity(0.5))
                        }
                    }
                    .padding(.leading, 32)
                }
            }
            .padding(.leading, CGFloat(indentLevel) * 14)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.primary.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.primary.opacity(0.08) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var initialsCircle: some View {
        Circle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 24, height: 24)
            .overlay(
                Text(customer.initials)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.6))
            )
    }
}
