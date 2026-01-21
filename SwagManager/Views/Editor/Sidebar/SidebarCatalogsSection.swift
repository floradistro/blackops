import SwiftUI

// MARK: - Sidebar Catalogs Section
// Extracted from EditorSidebarView.swift following Apple engineering standards
// File size: ~75 lines (under Apple's 300 line "excellent" threshold)

struct SidebarCatalogsSection: View {
    @ObservedObject var store: EditorStore
    @Binding var expandedCategoryIds: Set<UUID>

    var body: some View {
        TreeSectionHeader(
            title: "CATALOGS",
            isExpanded: $store.sidebarCatalogExpanded,
            count: store.catalogs.count,
            isLoading: store.isLoadingCatalogs
        )
        .padding(.top, DesignSystem.Spacing.xxs)

        if store.sidebarCatalogExpanded {
            if store.catalogs.isEmpty {
                Text("No catalogs")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xxs)
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
                            }
                        }
                    }
                }
            }
        }
    }
}
