import SwiftUI

// MARK: - Catalog Row
// Extracted from TreeItems.swift following Apple engineering standards
// File size: ~34 lines (under Apple's 300 line "excellent" threshold)

struct CatalogRow: View {
    let catalog: Catalog
    let isExpanded: Bool
    let itemCount: Int?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)

                Text(catalog.name)
                    .font(.system(size: 11))
                    .lineLimit(1)

                Spacer()

                if let count = itemCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }
}
