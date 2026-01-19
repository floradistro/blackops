import SwiftUI

// MARK: - Collection Tree Components
// Extracted from TreeItems.swift following Apple engineering standards
// Contains: CollectionTreeItem, CollectionListItem
// File size: ~71 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Collection Tree Item

struct CollectionTreeItem: View {
    let collection: CreationCollection
    let isExpanded: Bool
    var itemCount: Int = 0
    let onToggle: () -> Void

    var body: some View {
        Button {
            withAnimation(DesignSystem.Animation.spring) { onToggle() }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(DesignSystem.Animation.fast, value: isExpanded)
                    .frame(width: 10)

                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.warning)

                Text(collection.name)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                if itemCount > 0 {
                    Text("\(itemCount)")
                        .font(.system(size: 9))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}

// MARK: - Collection List Item

struct CollectionListItem: View {
    let collection: CreationCollection

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "folder.fill")
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(.orange)
                .frame(width: 16)

            Text(collection.name)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            if collection.isPublic == true {
                Image(systemName: "globe")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .cornerRadius(DesignSystem.Radius.sm)
    }
}
