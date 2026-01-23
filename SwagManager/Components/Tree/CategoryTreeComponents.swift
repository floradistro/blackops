import SwiftUI

// MARK: - Category Tree Components
// Minimal monochromatic theme

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
                withAnimation(.easeInOut(duration: 0.15)) {
                    if expandedCategoryIds.contains(category.id) {
                        expandedCategoryIds.remove(category.id)
                    } else {
                        expandedCategoryIds.insert(category.id)
                    }
                }
                store.selectCategory(category)
            } label: {
                HStack(spacing: 6) {
                    // Indentation
                    if indentLevel > 0 {
                        Color.clear.frame(width: CGFloat(indentLevel) * 14)
                    }

                    // Chevron
                    if hasChildren {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.4))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 10)
                    } else {
                        Spacer().frame(width: 10)
                    }

                    // Icon
                    Image(systemName: category.icon ?? "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .frame(width: 14)

                    // Name
                    Text(category.name)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.primary.opacity(isSelected ? 0.9 : 0.75))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    // Count
                    if totalCount > 0 {
                        Text("\(totalCount)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.35))
                    }
                }
                .frame(height: 24)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
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
        HStack(spacing: 6) {
            // Indentation
            if indentLevel > 0 {
                Color.clear.frame(width: CGFloat(indentLevel) * 14)
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.4))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 10)

            // Icon
            Image(systemName: category.icon ?? (isExpanded ? "folder.fill" : "folder"))
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 14)

            // Name
            Text(category.name)
                .font(.system(size: 10.5))
                .foregroundStyle(Color.primary.opacity(0.75))
                .lineLimit(1)

            Spacer(minLength: 4)

            // Count
            if itemCount > 0 {
                Text("\(itemCount)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.35))
            }
        }
        .frame(height: 24)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}
