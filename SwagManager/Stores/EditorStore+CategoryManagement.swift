import SwiftUI

// MARK: - EditorStore Category Management Extension
// Extracted from EditorStore+CatalogManagement.swift following Apple engineering standards
// File size: ~70 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Catalog Data Loading

    func loadCatalog() async {
        await loadCatalogs()
        await loadCatalogData()
        await loadConversations()
    }

    func loadCatalogData() async {
        do {
            categories = try await supabase.fetchCategories(storeId: currentStoreId, catalogId: selectedCatalog?.id)
            products = try await supabase.fetchProducts(storeId: currentStoreId)
            NSLog("[EditorStore] Loaded %d categories, %d products for store %@, catalog %@", categories.count, products.count, selectedStore?.storeName ?? "default", selectedCatalog?.name ?? "all")
        } catch {
            NSLog("[EditorStore] Error loading catalog data: %@", String(describing: error))
            if self.error == nil {
                self.error = "Failed to load catalog: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Category Operations

    func createCategory(name: String, parentId: UUID? = nil) async {
        do {
            let slug = name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

            let insert = CategoryInsert(
                name: name,
                slug: slug,
                description: nil,
                parentId: parentId,
                catalogId: selectedCatalog?.id,
                storeId: currentStoreId,
                displayOrder: categories.count,
                isActive: true
            )

            _ = try await supabase.createCategory(insert)
            await loadCatalogData()
            NSLog("[EditorStore] Created category: %@", name)
        } catch {
            NSLog("[EditorStore] Error creating category: %@", String(describing: error))
            self.error = "Failed to create category: \(error.localizedDescription)"
        }
    }

    func deleteCategory(_ category: Category) async {
        do {
            try await supabase.deleteCategory(id: category.id)
            await loadCatalogData()
            NSLog("[EditorStore] Deleted category: %@", category.name)
        } catch {
            NSLog("[EditorStore] Error deleting category: %@", String(describing: error))
            self.error = "Failed to delete category: \(error.localizedDescription)"
        }
    }

    func productsForCategory(_ categoryId: UUID) -> [Product] {
        products.filter { $0.primaryCategoryId == categoryId }
    }

    var uncategorizedProducts: [Product] {
        products.filter { $0.primaryCategoryId == nil }
    }
}
