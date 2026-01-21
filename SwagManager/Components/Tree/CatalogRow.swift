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
            HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: DesignSystem.TreeSpacing.chevronSize))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)

                Text(catalog.name)
                    .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize))
                    .lineLimit(1)

                Spacer(minLength: DesignSystem.TreeSpacing.elementSpacing)

                if let count = itemCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: DesignSystem.TreeSpacing.itemHeight)
            .padding(.horizontal, DesignSystem.TreeSpacing.itemPaddingHorizontal)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}
