import SwiftUI

// MARK: - Sidebar Catalogs Section
// Minimal monochromatic theme

struct SidebarCatalogsSection: View {
    @ObservedObject var store: EditorStore
    @Binding var expandedCategoryIds: Set<UUID>

    var body: some View {
        TreeSectionHeader(
            title: "Catalogs",
            icon: "book",
            iconColor: nil,
            isExpanded: $store.sidebarCatalogExpanded,
            count: store.catalogs.count,
            isLoading: store.isLoadingCatalogs
        )
        .padding(.top, 2)

        if store.sidebarCatalogExpanded {
            if store.catalogs.isEmpty {
                Text("No catalogs")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            } else {
                ForEach(store.catalogs) { catalog in
                    let isExpanded = store.selectedCatalog?.id == catalog.id

                    CatalogRow(
                        catalog: catalog,
                        isExpanded: isExpanded,
                        itemCount: isExpanded ? store.categories.count : nil,
                        onTap: {
                            Task {
                                if store.selectedCatalog?.id == catalog.id {
                                    store.selectedCatalog = nil
                                } else {
                                    await store.selectCatalog(catalog)
                                }
                            }
                        }
                    )

                    if isExpanded {
                        ForEach(store.topLevelCategories) { category in
                            CategoryHierarchyView(
                                category: category,
                                store: store,
                                expandedCategoryIds: $expandedCategoryIds,
                                indentLevel: 1
                            )
                            .environmentObject(store)
                        }

                        if !store.uncategorizedProducts.isEmpty {
                            ForEach(store.uncategorizedProducts) { product in
                                ProductTreeItem(
                                    product: product,
                                    isSelected: store.selectedProductIds.contains(product.id),
                                    isActive: store.selectedProduct?.id == product.id,
                                    indentLevel: 1,
                                    onSelect: { store.selectProduct(product) }
                                )
                                .environmentObject(store)
                            }
                        }
                    }
                }
            }
        }
    }
}
