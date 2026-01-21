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

            // Load pricing schemas for instant tier selection (Apple pattern: pre-load all data)
            do {
                NSLog("[EditorStore] Loading ALL pricing schemas (unrestricted)")

                // Load ALL active pricing schemas - no store/catalog filter
                // Products reference schemas by pricing_schema_id, so we need all schemas available
                let response = try await supabase.client
                    .from("pricing_schemas")
                    .select("*")
                    .eq("is_active", value: true)
                    .execute()

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase

                // Debug: Log raw JSON
                if let jsonString = String(data: response.data, encoding: .utf8) {
                    NSLog("[EditorStore] 🔍 Raw pricing schemas JSON (first 500 chars): %@", String(jsonString.prefix(500)))
                }

                let schemas = try decoder.decode([PricingSchema].self, from: response.data)
                pricingSchemas = schemas

                NSLog("[EditorStore] ✅ Loaded %d pricing schemas", pricingSchemas.count)
                for schema in schemas {
                    NSLog("[EditorStore]    - %@ (%@) with %d tiers", schema.name, schema.id.uuidString, schema.tiers.count)
                    if schema.tiers.count > 0 {
                        let firstTier = schema.tiers[0]
                        NSLog("[EditorStore]      First tier: id=%@, label=%@, price=%@, quantity=%@, unit=%@",
                              firstTier.id, firstTier.label, String(describing: firstTier.defaultPrice),
                              String(firstTier.quantity), firstTier.unit)
                    }
                }
            } catch {
                NSLog("[EditorStore] ❌ Could not load pricing schemas: %@", String(describing: error))
                pricingSchemas = []
            }

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
