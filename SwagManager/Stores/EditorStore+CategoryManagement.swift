import SwiftUI

// MARK: - EditorStore Category Management Extension
// Extracted from EditorStore+CatalogManagement.swift following Apple engineering standards
// File size: ~70 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Catalog Data Loading

    func loadCatalog() async {
        // PERF: Run catalogs + data in parallel; conversations are unrelated — don't block
        async let catalogsTask: () = loadCatalogs()
        async let dataTask: () = loadCatalogData()
        _ = await (catalogsTask, dataTask)

        // Conversations loaded separately — don't block catalog rendering
        Task { await loadConversations() }
    }

    func loadCatalogData() async {
        // Capture values for concurrent access (services are now nonisolated/Sendable)
        let catalogService = supabase.catalogs
        let productService = supabase.products
        let client = supabase.client
        let storeId = currentStoreId
        let catalogId = selectedCatalog?.id

        do {
            // PERF: Fetch ALL data in PARALLEL — network + JSON decode runs off main thread
            // (CatalogService and ProductSchemaService are no longer @MainActor)
            async let fetchedCategories = catalogService.fetchCategories(storeId: storeId, catalogId: catalogId)
            async let fetchedProducts = productService.fetchProducts(storeId: storeId)
            async let fetchedSchemas: [PricingSchema] = {
                do {
                    let response = try await client
                        .from("pricing_schemas")
                        .select("*")
                        .eq("is_active", value: true)
                        .execute()
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    return try decoder.decode([PricingSchema].self, from: response.data)
                } catch {
                    return []
                }
            }()

            let (cats, prods, schemas) = try await (fetchedCategories, fetchedProducts, fetchedSchemas)

            // SINGLE synchronous batch update on main thread
            // @Observable coalesces notifications within the same run loop tick
            categories = cats
            products = prods
            pricingSchemas = schemas
        } catch {
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
        } catch {
            self.error = "Failed to create category: \(error.localizedDescription)"
        }
    }

    func deleteCategory(_ category: Category) async {
        do {
            try await supabase.deleteCategory(id: category.id)
            await loadCatalogData()
        } catch {
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
