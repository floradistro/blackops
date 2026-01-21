import SwiftUI
import UniformTypeIdentifiers

// MARK: - Customer Tree Item
// Component for displaying customer in sidebar tree

struct CustomerTreeItem: View {
    let customer: Customer
    let isSelected: Bool
    var isActive: Bool = false
    let indentLevel: Int
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: customer.statusIcon)
                .font(.system(size: 13))
                .foregroundColor(Color(customer.statusColor))
                .frame(width: 16)

            Text(customer.displayName)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let tier = customer.loyaltyTier {
                Text(tier.prefix(1).uppercased())
                    .font(.system(size: 10))
                    .foregroundColor(Color(customer.loyaltyTierColor))
                    .opacity(0.7)
            }

            if let spent = customer.totalSpent, spent > 0 {
                Text(customer.formattedTotalSpent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 16 + CGFloat(indentLevel) * 16)
        .padding(.trailing, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onDrag {
            print("🚀 Starting drag for customer: \(customer.displayName) (\(customer.id))")
            let dragString = DragItemType.encode(.customer, uuid: customer.id)
            print("🔑 Drag data: \(dragString)")

            let provider = NSItemProvider(object: dragString as NSString)
            print("✅ NSItemProvider created successfully")
            return provider
        }
    }
}

// MARK: - Customer Tree Item with Details
// Extended version with more information

struct CustomerTreeItemDetailed: View {
    let customer: Customer
    let isSelected: Bool
    var isActive: Bool = false
    let indentLevel: Int
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Avatar or initials
                    if let avatarUrl = customer.avatarUrl {
                        AsyncImage(url: URL(string: avatarUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color(customer.statusColor).opacity(0.2))
                                .overlay(
                                    Text(customer.initials)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color(customer.statusColor))
                                )
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(customer.statusColor).opacity(0.2))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text(customer.initials)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(customer.statusColor))
                            )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        // Name
                        Text(customer.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                            .lineLimit(1)

                        // Contact info
                        if let email = customer.email {
                            Text(email)
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .lineLimit(1)
                        } else if let phone = customer.phone {
                            Text(phone)
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Status indicators
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            if customer.idVerified == true {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                            }

                            if customer.loyaltyTier != nil {
                                Image(systemName: customer.loyaltyTierIcon)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(customer.loyaltyTierColor))
                            }
                        }

                        Text(customer.formattedTotalSpent)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }

                // Order count
                if let orderCount = customer.totalOrders, orderCount > 0 {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary)

                        Text("\(orderCount) orders")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary)

                        if let points = customer.loyaltyPoints, points > 0 {
                            Text("•")
                                .foregroundColor(DesignSystem.Colors.textTertiary)

                            Text("\(points) pts")
                                .font(.system(size: 9))
                                .foregroundColor(Color(customer.loyaltyTierColor))
                        }
                    }
                    .padding(.leading, 32)
                }
            }
            .padding(.leading, CGFloat(indentLevel) * DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? DesignSystem.Colors.surfaceSecondary.opacity(0.3) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? DesignSystem.Colors.border : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
