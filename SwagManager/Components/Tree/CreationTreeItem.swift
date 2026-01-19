import SwiftUI

// MARK: - Creation Tree Item
// Extracted from TreeItems.swift following Apple engineering standards
// File size: ~48 lines (under Apple's 300 line "excellent" threshold)

struct CreationTreeItem: View {
    let creation: Creation
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

                Image(systemName: creation.creationType.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(creation.creationType.color)
                    .frame(width: 16)

                Text(creation.name)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()

                if let status = creation.status {
                    Circle()
                        .fill(status.color)
                        .frame(width: 6, height: 6)
                }
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
