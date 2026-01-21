import SwiftUI

// MARK: - Category Tree Components
// Extracted from TreeItems.swift following Apple engineering standards
// Contains: CategoryHierarchyView, CategoryTreeItem
// File size: ~148 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Category Hierarchy View (Recursive)

struct CategoryHierarchyView: View {
    let category: Category
    @ObservedObject var store: EditorStore
    @Binding var expandedCategoryIds: Set<UUID>
    var indentLevel: Int = 0

    private var isExpanded: Bool {
        expandedCategoryIds.contains(category.id)
    }

    private var isSelected: Bool {
        store.selectedCategory?.id == category.id
    }

    private var childCategories: [Category] {
        store.childCategories(of: category.id)
    }

    private var directProducts: [Product] {
        store.productsForCategory(category.id)
    }

    private var hasChildren: Bool {
        !childCategories.isEmpty || !directProducts.isEmpty
    }

    private var totalCount: Int {
        store.totalProductCount(category.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header row
            Button {
                withAnimation(DesignSystem.Animation.fast) {
                    if expandedCategoryIds.contains(category.id) {
                        expandedCategoryIds.remove(category.id)
                    } else {
                        expandedCategoryIds.insert(category.id)
                    }
                }
                store.selectCategory(category)
            } label: {
                HStack(spacing: 8) {
                    // Chevron
                    if hasChildren {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 16)
                    } else {
                        Spacer().frame(width: 16)
                    }

                    Text(category.name)
                        .font(.system(size: 13))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if totalCount > 0 {
                        Text("\(totalCount)")
                            .font(.system(size: 11))
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
            }
            .buttonStyle(TreeItemButtonStyle())

            // Expanded content
            if isExpanded {
                ForEach(childCategories) { childCategory in
                    CategoryHierarchyView(
                        category: childCategory,
                        store: store,
                        expandedCategoryIds: $expandedCategoryIds,
                        indentLevel: indentLevel + 1
                    )
                }

                ForEach(directProducts) { product in
                    ProductTreeItem(
                        product: product,
                        isSelected: store.selectedProductIds.contains(product.id),
                        isActive: store.selectedProduct?.id == product.id,
                        indentLevel: indentLevel + 2,
                        onSelect: { store.selectProduct(product) }
                    )
                    .environmentObject(store)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            Task { await store.deleteProduct(product) }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Category Tree Item (Simple)

struct CategoryTreeItem: View {
    let category: Category
    let isExpanded: Bool
    var itemCount: Int = 0
    var indentLevel: Int = 0
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: DesignSystem.TreeSpacing.chevronSize))
                .foregroundStyle(.tertiary)
                .frame(width: 10)

            Image(systemName: category.icon ?? (isExpanded ? "folder.fill" : "folder"))
                .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                .foregroundStyle(.green)
                .frame(width: 14)

            Text(category.name)
                .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize))
                .lineLimit(1)

            Spacer(minLength: DesignSystem.TreeSpacing.elementSpacing)

            if itemCount > 0 {
                Text("\(itemCount)")
                    .font(.system(size: DesignSystem.TreeSpacing.secondaryTextSize))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: DesignSystem.TreeSpacing.itemHeight)
        .padding(.leading, DesignSystem.TreeSpacing.itemPaddingHorizontal + CGFloat(indentLevel) * DesignSystem.TreeSpacing.indentPerLevel)
        .padding(.trailing, DesignSystem.TreeSpacing.itemPaddingHorizontal)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}
