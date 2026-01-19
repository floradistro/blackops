import Foundation
import Supabase

// MARK: - ProductSchemaService Products Extension
// Extracted from ProductSchemaService.swift following Apple engineering standards
// File size: ~70 lines (under Apple's 300 line "excellent" threshold)

extension ProductSchemaService {
    // MARK: - Products

    func fetchProducts(
        storeId: UUID? = nil,
        categoryId: UUID? = nil,
        search: String? = nil
    ) async throws -> [Product] {
        // Paginate to get ALL products (Supabase default limit is 1000)
        var allProducts: [Product] = []
        let batchSize = 1000
        var offset = 0

        while true {
            var query = client.from("products")
                .select("id, name, slug, description, short_description, sku, type, status, primary_category_id, store_id, featured_image, image_gallery, has_variations, manage_stock, stock_quantity, stock_status, weight, length, width, height, cost_price, wholesale_price, is_wholesale, wholesale_only, product_visibility, custom_fields, pricing_schema_id, pricing_data, created_at, updated_at")

            if let storeId = storeId {
                query = query.eq("store_id", value: storeId)
            }

            if let categoryId = categoryId {
                query = query.eq("primary_category_id", value: categoryId)
            }

            if let search = search, !search.isEmpty {
                query = query.ilike("name", pattern: "%\(search)%")
            }

            let batch: [Product] = try await query
                .order("name", ascending: true)
                .range(from: offset, to: offset + batchSize - 1)
                .execute()
                .value

            allProducts.append(contentsOf: batch)

            if batch.count < batchSize {
                break // No more products
            }
            offset += batchSize
        }

        return allProducts
    }

    func fetchProduct(id: UUID) async throws -> Product {
        return try await client.from("products")
            .select("id, name, slug, description, short_description, sku, type, status, primary_category_id, store_id, featured_image, image_gallery, has_variations, manage_stock, stock_quantity, stock_status, weight, length, width, height, cost_price, wholesale_price, is_wholesale, wholesale_only, product_visibility, custom_fields, pricing_schema_id, pricing_data, created_at, updated_at")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func updateProduct(id: UUID, update: ProductUpdate) async throws -> Product {
        return try await client.from("products")
            .update(update)
            .eq("id", value: id)
            .select("id, name, slug, description, short_description, sku, type, status, primary_category_id, store_id, featured_image, image_gallery, has_variations, manage_stock, stock_quantity, stock_status, weight, length, width, height, cost_price, wholesale_price, is_wholesale, wholesale_only, product_visibility, created_at, updated_at")
            .single()
            .execute()
            .value
    }

    func deleteProduct(id: UUID) async throws {
        try await client.from("products")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
