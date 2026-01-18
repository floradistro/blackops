import Foundation
import Supabase

// MARK: - Supabase Configuration

enum SupabaseConfig {
    // Production: floradistro.com
    static let url = URL(string: "https://uaednwpxursknmwdeejn.supabase.co")!

    // Anon key - safe for client-side use (RLS protects data)
    // SECURITY: Never use service_role key in client apps
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg"
}

// MARK: - Supabase Service

@MainActor
class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        // Using anon key - RLS policies enforce security
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(
                auth: .init(
                    flowType: .implicit,
                    autoRefreshToken: true
                )
            )
        )
    }

    // MARK: - Creations

    func fetchCreations(
        type: CreationType? = nil,
        status: CreationStatus? = nil,
        search: String? = nil,
        limit: Int = 100
    ) async throws -> [Creation] {
        // Fetch all creations and filter client-side for soft deletes
        var creations: [Creation]

        if let type = type, let status = status, let search = search, !search.isEmpty {
            creations = try await client.from("creations")
                .select()
                .eq("creation_type", value: type.rawValue)
                .eq("status", value: status.rawValue)
                .ilike("name", pattern: "%\(search)%")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else if let type = type, let status = status {
            creations = try await client.from("creations")
                .select()
                .eq("creation_type", value: type.rawValue)
                .eq("status", value: status.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else if let type = type, let search = search, !search.isEmpty {
            creations = try await client.from("creations")
                .select()
                .eq("creation_type", value: type.rawValue)
                .ilike("name", pattern: "%\(search)%")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else if let status = status, let search = search, !search.isEmpty {
            creations = try await client.from("creations")
                .select()
                .eq("status", value: status.rawValue)
                .ilike("name", pattern: "%\(search)%")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else if let type = type {
            creations = try await client.from("creations")
                .select()
                .eq("creation_type", value: type.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else if let status = status {
            creations = try await client.from("creations")
                .select()
                .eq("status", value: status.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else if let search = search, !search.isEmpty {
            creations = try await client.from("creations")
                .select()
                .ilike("name", pattern: "%\(search)%")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else {
            creations = try await client.from("creations")
                .select("id, creation_type, name, slug, description, status, is_public, version, created_at, updated_at, thumbnail_url, deployed_url, react_code, visibility, view_count, install_count, deleted_at")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        }

        // Filter out soft-deleted creations
        return creations.filter { $0.deletedAt == nil }
    }

    func fetchCreation(id: UUID) async throws -> Creation {
        return try await client.from("creations")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createCreation(_ creation: CreationInsert) async throws -> Creation {
        return try await client.from("creations")
            .insert(creation)
            .select()
            .single()
            .execute()
            .value
    }

    func updateCreation(id: UUID, update: CreationUpdate) async throws -> Creation {
        return try await client.from("creations")
            .update(update)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteCreation(id: UUID) async throws {
        // Soft delete: set deleted_at instead of hard delete
        try await client.from("creations")
            .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Collections

    func fetchCollections(limit: Int = 100) async throws -> [CreationCollection] {
        // Explicitly select columns to avoid decoding issues with design_system JSONB
        return try await client.from("creation_collections")
            .select("id, store_id, location_id, name, slug, description, launcher_style, background_color, accent_color, logo_url, is_public, requires_auth, created_at, updated_at, visibility, is_pinned, pinned_at, pin_order, is_template")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchCollection(id: UUID) async throws -> CreationCollection {
        return try await client.from("creation_collections")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createCollection(_ collection: CollectionInsert) async throws -> CreationCollection {
        return try await client.from("creation_collections")
            .insert(collection)
            .select()
            .single()
            .execute()
            .value
    }

    func updateCollection(id: UUID, update: CollectionUpdate) async throws -> CreationCollection {
        return try await client.from("creation_collections")
            .update(update)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteCollection(id: UUID) async throws {
        try await client.from("creation_collections")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Collection Items

    func fetchCollectionItems(collectionId: UUID) async throws -> [CreationCollectionItem] {
        return try await client.from("creation_collection_items")
            .select()
            .eq("collection_id", value: collectionId)
            .order("position", ascending: true)
            .execute()
            .value
    }

    func addToCollection(_ item: CollectionItemInsert) async throws -> CreationCollectionItem {
        return try await client.from("creation_collection_items")
            .insert(item)
            .select()
            .single()
            .execute()
            .value
    }

    func removeFromCollection(itemId: UUID) async throws {
        try await client.from("creation_collection_items")
            .delete()
            .eq("id", value: itemId)
            .execute()
    }

    func updateCollectionItemPosition(itemId: UUID, position: Int) async throws {
        try await client.from("creation_collection_items")
            .update(["position": position])
            .eq("id", value: itemId)
            .execute()
    }

    // MARK: - Fetch collection with creations

    func fetchCollectionWithCreations(id: UUID) async throws -> CollectionWithItems {
        let collection = try await fetchCollection(id: id)
        let items = try await fetchCollectionItems(collectionId: id)

        var creations: [Creation] = []
        for item in items {
            if let creation = try? await fetchCreation(id: item.creationId) {
                creations.append(creation)
            }
        }

        return CollectionWithItems(collection: collection, items: items, creations: creations)
    }

    // MARK: - Stats

    func fetchCreationStats() async throws -> (total: Int, byType: [CreationType: Int], byStatus: [CreationStatus: Int]) {
        let creations: [Creation] = try await client.from("creations")
            .select("id, creation_type, status")
            .execute()
            .value

        var byType: [CreationType: Int] = [:]
        var byStatus: [CreationStatus: Int] = [:]

        for creation in creations {
            byType[creation.creationType, default: 0] += 1
            if let status = creation.status {
                byStatus[status, default: 0] += 1
            }
        }

        return (creations.count, byType, byStatus)
    }

    // MARK: - Categories

    func fetchCategories(storeId: UUID? = nil, limit: Int = 100) async throws -> [Category] {
        if let storeId = storeId {
            return try await client.from("categories")
                .select("id, name, slug, description, parent_id, image_url, banner_url, display_order, is_active, featured, product_count, store_id, icon, featured_image, created_at, updated_at")
                .eq("store_id", value: storeId)
                .order("display_order", ascending: true)
                .limit(limit)
                .execute()
                .value
        } else {
            return try await client.from("categories")
                .select("id, name, slug, description, parent_id, image_url, banner_url, display_order, is_active, featured, product_count, store_id, icon, featured_image, created_at, updated_at")
                .order("display_order", ascending: true)
                .limit(limit)
                .execute()
                .value
        }
    }

    func fetchCategory(id: UUID) async throws -> Category {
        return try await client.from("categories")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    // MARK: - Products

    func fetchProducts(
        storeId: UUID? = nil,
        categoryId: UUID? = nil,
        search: String? = nil,
        limit: Int = 100
    ) async throws -> [Product] {
        var query = client.from("products")
            .select("id, name, slug, description, short_description, sku, type, status, regular_price, sale_price, on_sale, price, primary_category_id, store_id, featured_image, image_gallery, has_variations, manage_stock, stock_quantity, stock_status, weight, length, width, height, cost_price, wholesale_price, is_wholesale, wholesale_only, product_visibility, created_at, updated_at")

        if let storeId = storeId {
            query = query.eq("store_id", value: storeId)
        }

        if let categoryId = categoryId {
            query = query.eq("primary_category_id", value: categoryId)
        }

        if let search = search, !search.isEmpty {
            query = query.ilike("name", pattern: "%\(search)%")
        }

        return try await query
            .order("name", ascending: true)
            .limit(limit)
            .execute()
            .value
    }

    func fetchProduct(id: UUID) async throws -> Product {
        return try await client.from("products")
            .select("id, name, slug, description, short_description, sku, type, status, regular_price, sale_price, on_sale, price, primary_category_id, store_id, featured_image, image_gallery, has_variations, manage_stock, stock_quantity, stock_status, weight, length, width, height, cost_price, wholesale_price, is_wholesale, wholesale_only, product_visibility, created_at, updated_at")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func updateProduct(id: UUID, update: ProductUpdate) async throws -> Product {
        return try await client.from("products")
            .update(update)
            .eq("id", value: id)
            .select("id, name, slug, description, short_description, sku, type, status, regular_price, sale_price, on_sale, price, primary_category_id, store_id, featured_image, image_gallery, has_variations, manage_stock, stock_quantity, stock_status, weight, length, width, height, cost_price, wholesale_price, is_wholesale, wholesale_only, product_visibility, created_at, updated_at")
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

    // MARK: - Stores

    func fetchStores(limit: Int = 50) async throws -> [Store] {
        // RLS policies automatically filter to stores the user owns or is a member of
        // No explicit filter needed - auth token handles it
        return try await client.from("stores")
            .select("id, store_name, slug, email, status, phone, address, city, state, zip, logo_url, banner_url, store_description, store_tagline, store_type, total_locations, created_at, updated_at")
            .order("store_name", ascending: true)
            .limit(limit)
            .execute()
            .value
    }

    func fetchStore(id: UUID) async throws -> Store {
        return try await client.from("stores")
            .select("id, store_name, slug, email, status, phone, address, city, state, zip, logo_url, banner_url, store_description, store_tagline, store_type, total_locations, created_at, updated_at")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createStore(_ store: StoreInsert) async throws -> Store {
        return try await client.from("stores")
            .insert(store)
            .select("id, store_name, slug, email, status, phone, address, city, state, zip, logo_url, banner_url, store_description, store_tagline, store_type, total_locations, created_at, updated_at")
            .single()
            .execute()
            .value
    }
}
