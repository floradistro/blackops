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
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    // Chevron
                    if hasChildren {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .frame(width: 10)
                    } else {
                        Spacer().frame(width: 10)
                    }

                    Text(category.name)
                        .font(.system(size: 11))
                        .lineLimit(1)

                    Spacer()

                    if totalCount > 0 {
                        Text("\(totalCount)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .padding(.trailing, DesignSystem.Spacing.xxs)
                    }
                }
                .padding(.leading, DesignSystem.Spacing.sm + CGFloat(indentLevel) * 12)
                .padding(.trailing, DesignSystem.Spacing.xxs)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
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
        HStack(spacing: DesignSystem.Spacing.xxs) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            Image(systemName: category.icon ?? (isExpanded ? "folder.fill" : "folder"))
                .font(.system(size: 9))
                .foregroundStyle(.green)
                .frame(width: 14)

            Text(category.name)
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer()

            if itemCount > 0 {
                Text("\(itemCount)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, DesignSystem.Spacing.xxs)
            }
        }
        .padding(.leading, DesignSystem.Spacing.sm + CGFloat(indentLevel) * 16)
        .padding(.trailing, DesignSystem.Spacing.xxs)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}
