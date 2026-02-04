// Extracted from SupabaseService.swift following Apple engineering standards

import Foundation
import Supabase

@MainActor
final class CatalogService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Catalogs

    func fetchCatalogs(storeId: UUID) async throws -> [Catalog] {
        return try await client.from("catalogs")
            .select("id, store_id, name, slug, description, vertical, is_active, is_default, settings, display_order, created_at, updated_at")
            .eq("store_id", value: storeId)
            .order("display_order", ascending: true)
            .execute()
            .value
    }

    func fetchCatalog(id: UUID) async throws -> Catalog {
        return try await client.from("catalogs")
            .select("id, store_id, name, slug, description, vertical, is_active, is_default, settings, display_order, created_at, updated_at")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createCatalog(_ catalog: CatalogInsert) async throws -> Catalog {
        return try await client.from("catalogs")
            .insert(catalog)
            .select("id, store_id, name, slug, description, vertical, is_active, is_default, settings, display_order, created_at, updated_at")
            .single()
            .execute()
            .value
    }

    func deleteCatalog(id: UUID) async throws {
        try await client.from("catalogs")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Categories

    func fetchCategories(storeId: UUID? = nil, catalogId: UUID? = nil) async throws -> [Category] {
        // Paginate to get ALL categories (Supabase default limit is 1000)
        var allCategories: [Category] = []
        let batchSize = 1000
        var offset = 0

        while true {
            var query = client.from("categories")
                .select("id, name, slug, description, parent_id, catalog_id, image_url, banner_url, display_order, is_active, featured, product_count, store_id, icon, featured_image, created_at, updated_at")

            if let storeId = storeId {
                query = query.eq("store_id", value: storeId)
            }

            if let catalogId = catalogId {
                query = query.eq("catalog_id", value: catalogId)
            }

            let batch: [Category] = try await query
                .order("display_order", ascending: true)
                .range(from: offset, to: offset + batchSize - 1)
                .execute()
                .value

            allCategories.append(contentsOf: batch)

            if batch.count < batchSize {
                break // No more categories
            }
            offset += batchSize
        }

        return allCategories
    }

    func fetchCategory(id: UUID) async throws -> Category {
        return try await client.from("categories")
            .select("id, name, slug, description, parent_id, catalog_id, image_url, banner_url, display_order, is_active, featured, product_count, store_id, icon, featured_image, created_at, updated_at")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createCategory(_ category: CategoryInsert) async throws -> Category {
        return try await client.from("categories")
            .insert(category)
            .select("id, name, slug, description, parent_id, catalog_id, image_url, banner_url, display_order, is_active, featured, product_count, store_id, icon, featured_image, created_at, updated_at")
            .single()
            .execute()
            .value
    }

    func deleteCategory(id: UUID) async throws {
        try await client.from("categories")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Assigns categories to a catalog using backend RPC (atomic batch operation)
    /// Uses backend RPC: assign_categories_to_catalog (replaces N+1 update loop)
    func assignCategoriesToCatalog(storeId: UUID, catalogId: UUID, onlyOrphans: Bool = true) async throws -> Int {
        let response = try await client
            .rpc("assign_categories_to_catalog", params: [
                "p_catalog_id": catalogId.uuidString,
                "p_store_id": storeId.uuidString,
                "p_orphans_only": onlyOrphans ? "true" : "false"
            ])
            .execute()

        // RPC returns the count of updated categories
        if let count = try? JSONDecoder().decode(Int.self, from: response.data) {
            return count
        }

        return 0
    }
}
