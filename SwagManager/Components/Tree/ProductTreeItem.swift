import SwiftUI

// MARK: - Product Tree Item
// Extracted from TreeItems.swift following Apple engineering standards
// File size: ~47 lines (under Apple's 300 line "excellent" threshold)

struct ProductTreeItem: View {
    let product: Product
    let isSelected: Bool
    let isActive: Bool
    var indentLevel: Int = 0
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignSystem.Colors.success)
                    .frame(width: 14)

                Text(product.name)
                    .font(.system(size: 11))
                    .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()

                Text(product.displayPrice)
                    .font(.system(size: 9))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Circle()
                    .fill(product.stockStatusColor)
                    .frame(width: 6, height: 6)
            }
            .padding(.leading, DesignSystem.Spacing.sm + CGFloat(min(indentLevel, 2)) * 12)
            .padding(.trailing, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
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
