import Foundation
import Supabase
import Auth

// MARK: - Supabase Configuration

enum SupabaseConfig {
    // Production: floradistro.com
    static let url = URL(string: "https://uaednwpxursknmwdeejn.supabase.co")!

    // Anon key - safe for client-side use (RLS protects data)
    // SECURITY: Never use service_role key in client apps
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg"
}

// MARK: - UserDefaults Auth Storage (avoids Keychain prompts during development)

final class UserDefaultsAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let defaults = UserDefaults.standard
    private let keyPrefix = "supabase.auth."

    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: keyPrefix + key)
    }

    func retrieve(key: String) throws -> Data? {
        defaults.data(forKey: keyPrefix + key)
    }

    func remove(key: String) throws {
        defaults.removeObject(forKey: keyPrefix + key)
    }
}

// MARK: - Supabase Service

@MainActor
class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        // Using anon key - RLS policies enforce security
        // Using UserDefaults storage to avoid Keychain password prompts during development
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(
                auth: .init(
                    storage: UserDefaultsAuthLocalStorage(),
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

    func assignCategoriesToCatalog(storeId: UUID, catalogId: UUID, onlyOrphans: Bool = true) async throws -> Int {
        // Simple struct just for getting IDs
        struct CategoryId: Codable {
            let id: UUID
        }

        // Get categories to update
        var query = client.from("categories")
            .select("id")
            .eq("store_id", value: storeId)

        if onlyOrphans {
            query = query.is("catalog_id", value: nil)
        } else {
            // Assign ALL categories for this store to the catalog
            query = query.neq("catalog_id", value: catalogId.uuidString)
        }

        let categoriesToUpdate: [CategoryId] = try await query.execute().value

        // Update each one
        for category in categoriesToUpdate {
            try await client.from("categories")
                .update(["catalog_id": catalogId.uuidString])
                .eq("id", value: category.id)
                .execute()
        }

        return categoriesToUpdate.count
    }

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

    // MARK: - Field Schemas

    func fetchFieldSchemas(catalogId: UUID? = nil) async throws -> [FieldSchema] {
        let allSchemas: [FieldSchema] = try await client.from("field_schemas")
            .select("*")
            .eq("is_active", value: true)
            .execute()
            .value

        // Filter by catalog: include schemas that either:
        // 1. Have no catalog_id (global/public schemas)
        // 2. Match the current catalog_id exactly
        return allSchemas.filter { schema in
            if let schemaCatalogId = schema.catalogId {
                return catalogId != nil && schemaCatalogId == catalogId
            } else {
                return true
            }
        }
    }

    func fetchFieldSchemasForCategory(categoryId: UUID) async throws -> [FieldSchema] {
        // First try to get assigned schemas from junction table
        struct CategoryFieldSchemaJoin: Codable {
            let fieldSchemaId: UUID
            let fieldSchema: FieldSchema

            enum CodingKeys: String, CodingKey {
                case fieldSchemaId = "field_schema_id"
                case fieldSchema = "field_schemas"
            }
        }

        let joins: [CategoryFieldSchemaJoin] = try await client.from("category_field_schemas")
            .select("field_schema_id, field_schemas(*)")
            .eq("category_id", value: categoryId)
            .eq("is_active", value: true)
            .order("sort_order", ascending: true)
            .execute()
            .value

        return joins.map { $0.fieldSchema }
    }

    func fetchAvailableFieldSchemas(catalogId: UUID?, categoryName: String?) async throws -> [FieldSchema] {
        // Fetch all active schemas
        let allSchemas: [FieldSchema] = try await client.from("field_schemas")
            .select("*")
            .eq("is_active", value: true)
            .execute()
            .value

        // Filter by catalog
        var filtered = allSchemas.filter { schema in
            if let schemaCatalogId = schema.catalogId {
                return catalogId == schemaCatalogId
            }
            return true
        }

        // Filter by applicable_categories if category name provided
        if let categoryName = categoryName {
            filtered = filtered.filter { $0.appliesTo(categoryName: categoryName) }
        }

        NSLog("[SupabaseService] Fetched \(filtered.count) available field schemas for catalog \(catalogId?.uuidString ?? "nil"), category \(categoryName ?? "nil")")
        return filtered
    }

    // MARK: - Pricing Schemas

    func fetchPricingSchemas(catalogId: UUID? = nil) async throws -> [PricingSchema] {
        let allSchemas: [PricingSchema] = try await client.from("pricing_schemas")
            .select("*")
            .eq("is_active", value: true)
            .execute()
            .value

        // Filter by catalog: include schemas that either:
        // 1. Have no catalog_id (global/public schemas)
        // 2. Match the current catalog_id exactly
        return allSchemas.filter { schema in
            if let schemaCatalogId = schema.catalogId {
                return catalogId != nil && schemaCatalogId == catalogId
            } else {
                return true
            }
        }
    }

    func fetchPricingSchemasForCategory(categoryId: UUID) async throws -> [PricingSchema] {
        // Fetch schemas assigned to this specific category via junction table
        struct CategoryPricingSchemaJoin: Codable {
            let pricingSchemaId: UUID
            let pricingSchema: PricingSchema

            enum CodingKeys: String, CodingKey {
                case pricingSchemaId = "pricing_schema_id"
                case pricingSchema = "pricing_schemas"
            }
        }

        let joins: [CategoryPricingSchemaJoin] = try await client.from("category_pricing_schemas")
            .select("pricing_schema_id, pricing_schemas(*)")
            .eq("category_id", value: categoryId)
            .eq("is_active", value: true)
            .order("sort_order", ascending: true)
            .execute()
            .value

        return joins.map { $0.pricingSchema }
    }

    func fetchAvailablePricingSchemas(catalogId: UUID?, categoryName: String?) async throws -> [PricingSchema] {
        // Fetch all active schemas
        let allSchemas: [PricingSchema] = try await client.from("pricing_schemas")
            .select("*")
            .eq("is_active", value: true)
            .execute()
            .value

        // Filter by catalog
        var filtered = allSchemas.filter { schema in
            if let schemaCatalogId = schema.catalogId {
                return catalogId == schemaCatalogId
            }
            return true
        }

        // Filter by applicable_categories if category name provided
        if let categoryName = categoryName {
            filtered = filtered.filter { $0.appliesTo(categoryName: categoryName) }
        }

        NSLog("[SupabaseService] Fetched \(filtered.count) available pricing schemas for catalog \(catalogId?.uuidString ?? "nil"), category \(categoryName ?? "nil")")
        return filtered
    }

    // MARK: - Category Schema Assignments

    func assignFieldSchemaToCategory(categoryId: UUID, fieldSchemaId: UUID) async throws {
        struct Assignment: Codable {
            let categoryId: UUID
            let fieldSchemaId: UUID

            enum CodingKeys: String, CodingKey {
                case categoryId = "category_id"
                case fieldSchemaId = "field_schema_id"
            }
        }

        try await client.from("category_field_schemas")
            .insert(Assignment(categoryId: categoryId, fieldSchemaId: fieldSchemaId))
            .execute()
    }

    func removeFieldSchemaFromCategory(categoryId: UUID, fieldSchemaId: UUID) async throws {
        try await client.from("category_field_schemas")
            .delete()
            .eq("category_id", value: categoryId)
            .eq("field_schema_id", value: fieldSchemaId)
            .execute()
    }

    func assignPricingSchemaToCategory(categoryId: UUID, pricingSchemaId: UUID) async throws {
        struct Assignment: Codable {
            let categoryId: UUID
            let pricingSchemaId: UUID

            enum CodingKeys: String, CodingKey {
                case categoryId = "category_id"
                case pricingSchemaId = "pricing_schema_id"
            }
        }

        try await client.from("category_pricing_schemas")
            .insert(Assignment(categoryId: categoryId, pricingSchemaId: pricingSchemaId))
            .execute()
    }

    func removePricingSchemaFromCategory(categoryId: UUID, pricingSchemaId: UUID) async throws {
        try await client.from("category_pricing_schemas")
            .delete()
            .eq("category_id", value: categoryId)
            .eq("pricing_schema_id", value: pricingSchemaId)
            .execute()
    }

    // MARK: - Field Schema CRUD

    func createFieldSchema(
        name: String,
        description: String?,
        icon: String?,
        fields: [FieldDefinition],
        catalogId: UUID?,
        applicableCategories: [String]?
    ) async throws -> FieldSchema {
        struct FieldSchemaInsert: Codable {
            let name: String
            let description: String?
            let icon: String?
            let fields: [FieldDefinition]
            let catalogId: UUID?
            let applicableCategories: [String]?
            let isActive: Bool
            let isPublic: Bool

            enum CodingKeys: String, CodingKey {
                case name, description, icon, fields
                case catalogId = "catalog_id"
                case applicableCategories = "applicable_categories"
                case isActive = "is_active"
                case isPublic = "is_public"
            }
        }

        let insert = FieldSchemaInsert(
            name: name,
            description: description,
            icon: icon,
            fields: fields,
            catalogId: catalogId,
            applicableCategories: applicableCategories,
            isActive: true,
            isPublic: false
        )

        return try await client.from("field_schemas")
            .insert(insert)
            .select("*")
            .single()
            .execute()
            .value
    }

    func updateFieldSchema(
        schemaId: UUID,
        name: String,
        description: String?,
        icon: String?,
        fields: [FieldDefinition]
    ) async throws {
        struct FieldSchemaUpdate: Codable {
            let name: String
            let description: String?
            let icon: String?
            let fields: [FieldDefinition]
        }

        let update = FieldSchemaUpdate(
            name: name,
            description: description,
            icon: icon,
            fields: fields
        )

        try await client.from("field_schemas")
            .update(update)
            .eq("id", value: schemaId)
            .execute()
    }

    func deleteFieldSchema(schemaId: UUID) async throws {
        // Soft delete - mark as inactive and record deletion time
        // Data is never truly deleted (Oracle/Apple/Mossad approach)
        struct SoftDelete: Codable {
            let isActive: Bool
            let deletedAt: String

            enum CodingKeys: String, CodingKey {
                case isActive = "is_active"
                case deletedAt = "deleted_at"
            }
        }

        let update = SoftDelete(
            isActive: false,
            deletedAt: ISO8601DateFormatter().string(from: Date())
        )

        try await client.from("field_schemas")
            .update(update)
            .eq("id", value: schemaId)
            .execute()

        // Remove category assignments (these can be hard deleted - just junction records)
        try await client.from("category_field_schemas")
            .delete()
            .eq("field_schema_id", value: schemaId)
            .execute()
    }

    // MARK: - Pricing Schema CRUD

    func createPricingSchema(
        name: String,
        description: String?,
        tiers: [PricingTier],
        catalogId: UUID?,
        applicableCategories: [String]?
    ) async throws -> PricingSchema {
        struct PricingSchemaInsert: Codable {
            let name: String
            let description: String?
            let tiers: [PricingTier]
            let catalogId: UUID?
            let applicableCategories: [String]?
            let isActive: Bool
            let isPublic: Bool

            enum CodingKeys: String, CodingKey {
                case name, description, tiers
                case catalogId = "catalog_id"
                case applicableCategories = "applicable_categories"
                case isActive = "is_active"
                case isPublic = "is_public"
            }
        }

        let insert = PricingSchemaInsert(
            name: name,
            description: description,
            tiers: tiers,
            catalogId: catalogId,
            applicableCategories: applicableCategories,
            isActive: true,
            isPublic: false
        )

        return try await client.from("pricing_schemas")
            .insert(insert)
            .select("*")
            .single()
            .execute()
            .value
    }

    func updatePricingSchema(
        schemaId: UUID,
        name: String,
        description: String?,
        tiers: [PricingTier]
    ) async throws {
        struct PricingSchemaUpdate: Codable {
            let name: String
            let description: String?
            let tiers: [PricingTier]
        }

        let update = PricingSchemaUpdate(
            name: name,
            description: description,
            tiers: tiers
        )

        try await client.from("pricing_schemas")
            .update(update)
            .eq("id", value: schemaId)
            .execute()
    }

    func deletePricingSchema(schemaId: UUID) async throws {
        // Soft delete - mark as inactive and record deletion time
        // Data is never truly deleted (Oracle/Apple/Mossad approach)
        struct SoftDelete: Codable {
            let isActive: Bool
            let deletedAt: String

            enum CodingKeys: String, CodingKey {
                case isActive = "is_active"
                case deletedAt = "deleted_at"
            }
        }

        let update = SoftDelete(
            isActive: false,
            deletedAt: ISO8601DateFormatter().string(from: Date())
        )

        try await client.from("pricing_schemas")
            .update(update)
            .eq("id", value: schemaId)
            .execute()

        // Remove category assignments (these can be hard deleted - just junction records)
        try await client.from("category_pricing_schemas")
            .delete()
            .eq("pricing_schema_id", value: schemaId)
            .execute()
    }

    // MARK: - Stores

    func fetchStores(limit: Int = 50) async throws -> [Store] {
        // RLS policies automatically filter to stores the user owns or is a member of
        // No explicit filter needed - auth token handles it
        return try await client.from("stores")
            .select("id, store_name, slug, email, owner_user_id, status, phone, address, city, state, zip, logo_url, banner_url, store_description, store_tagline, store_type, total_locations, created_at, updated_at")
            .order("store_name", ascending: true)
            .limit(limit)
            .execute()
            .value
    }

    func fetchStore(id: UUID) async throws -> Store {
        return try await client.from("stores")
            .select("id, store_name, slug, email, owner_user_id, status, phone, address, city, state, zip, logo_url, banner_url, store_description, store_tagline, store_type, total_locations, created_at, updated_at")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createStore(_ store: StoreInsert) async throws -> Store {
        return try await client.from("stores")
            .insert(store)
            .select("id, store_name, slug, email, owner_user_id, status, phone, address, city, state, zip, logo_url, banner_url, store_description, store_tagline, store_type, total_locations, created_at, updated_at")
            .single()
            .execute()
            .value
    }

    // MARK: - Locations

    func fetchLocations(storeId: UUID) async throws -> [Location] {
        NSLog("[SupabaseService] Fetching locations for store: \(storeId)")
        return try await client.from("locations")
            .select("*")
            .eq("store_id", value: storeId)
            .order("name", ascending: true)
            .execute()
            .value
    }

    // MARK: - Chat / Conversations

    func fetchConversations(storeId: UUID, chatType: String? = nil) async throws -> [Conversation] {
        NSLog("[SupabaseService] Fetching conversations for store: \(storeId), chatType: \(chatType ?? "all")")
        if let chatType = chatType {
            return try await client.from("lisa_conversations")
                .select("*")
                .eq("store_id", value: storeId)
                .eq("chat_type", value: chatType)
                .order("updated_at", ascending: false)
                .execute()
                .value
        } else {
            // Fetch ALL conversations for this store (don't filter by status)
            return try await client.from("lisa_conversations")
                .select("*")
                .eq("store_id", value: storeId)
                .order("updated_at", ascending: false)
                .execute()
                .value
        }
    }

    func fetchConversation(id: UUID) async throws -> Conversation {
        return try await client.from("lisa_conversations")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func fetchConversationsByLocation(locationId: UUID) async throws -> [Conversation] {
        NSLog("[SupabaseService] Fetching conversations for location: \(locationId)")
        return try await client.from("lisa_conversations")
            .select("*")
            .eq("location_id", value: locationId)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func fetchAllConversationsForStoreLocations(storeId: UUID) async throws -> [Conversation] {
        NSLog("[SupabaseService] Fetching all conversations for store locations: \(storeId)")
        // First get all locations for this store
        let locations = try await fetchLocations(storeId: storeId)
        NSLog("[SupabaseService] Found \(locations.count) locations")

        // Then get conversations for each location
        var allConversations: [Conversation] = []
        for location in locations {
            let convos = try await fetchConversationsByLocation(locationId: location.id)
            NSLog("[SupabaseService] Location '\(location.name)' has \(convos.count) conversations")
            allConversations.append(contentsOf: convos)
        }

        // Also try to get conversations directly by store_id
        let storeConvos = try await fetchConversations(storeId: storeId, chatType: nil)
        NSLog("[SupabaseService] Store has \(storeConvos.count) direct conversations")

        // Merge and deduplicate
        let existingIds = Set(allConversations.map { $0.id })
        for conv in storeConvos {
            if !existingIds.contains(conv.id) {
                allConversations.append(conv)
            }
        }

        NSLog("[SupabaseService] Total conversations: \(allConversations.count)")
        return allConversations.sorted { ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast) }
    }

    func createConversation(_ conversation: ConversationInsert) async throws -> Conversation {
        return try await client.from("lisa_conversations")
            .insert(conversation)
            .select("*")
            .single()
            .execute()
            .value
    }

    func getOrCreateTeamConversation(storeId: UUID, chatType: String = "dm", title: String? = nil) async throws -> Conversation {
        // Try to find existing conversation of this type
        let existing: [Conversation] = try await client.from("lisa_conversations")
            .select("*")
            .eq("store_id", value: storeId)
            .eq("chat_type", value: chatType)
            .eq("status", value: "active")
            .limit(1)
            .execute()
            .value

        if let first = existing.first {
            return first
        }

        // Create new conversation
        let insert = ConversationInsert(
            storeId: storeId,
            userId: nil,
            title: title ?? "Team Chat",
            chatType: chatType,
            locationId: nil
        )
        return try await createConversation(insert)
    }

    // MARK: - Messages

    func fetchMessages(conversationId: UUID, limit: Int = 50, before: Date? = nil) async throws -> [ChatMessage] {
        let messages: [ChatMessage]
        if let before = before {
            messages = try await client.from("lisa_messages")
                .select("*")
                .eq("conversation_id", value: conversationId)
                .lt("created_at", value: ISO8601DateFormatter().string(from: before))
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else {
            messages = try await client.from("lisa_messages")
                .select("*")
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        }
        return messages.reversed() // Return in chronological order
    }

    func sendMessage(_ message: ChatMessageInsert) async throws -> ChatMessage {
        return try await client.from("lisa_messages")
            .insert(message)
            .select("*")
            .single()
            .execute()
            .value
    }

    // MARK: - Chat Participants

    func fetchParticipants(conversationId: UUID) async throws -> [ChatParticipant] {
        return try await client.from("lisa_chat_participants")
            .select("*")
            .eq("conversation_id", value: conversationId)
            .is("left_at", value: nil)
            .execute()
            .value
    }

    func updateTypingStatus(conversationId: UUID, userId: UUID, isTyping: Bool) async throws {
        struct TypingUpdate: Codable {
            let isTyping: Bool
            let typingStartedAt: String?

            enum CodingKeys: String, CodingKey {
                case isTyping = "is_typing"
                case typingStartedAt = "typing_started_at"
            }
        }

        let update = TypingUpdate(
            isTyping: isTyping,
            typingStartedAt: isTyping ? ISO8601DateFormatter().string(from: Date()) : nil
        )

        try await client.from("lisa_chat_participants")
            .update(update)
            .eq("conversation_id", value: conversationId)
            .eq("user_id", value: userId)
            .execute()
    }

    func markMessagesRead(conversationId: UUID, userId: UUID, lastMessageId: UUID) async throws {
        try await client.from("lisa_chat_participants")
            .update(["last_read_at": ISO8601DateFormatter().string(from: Date()), "last_read_message_id": lastMessageId.uuidString])
            .eq("conversation_id", value: conversationId)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Realtime Channel

    func messagesChannel(conversationId: UUID) -> RealtimeChannelV2 {
        return client.realtimeV2.channel("messages:\(conversationId.uuidString)")
    }

    // MARK: - Browser Sessions

    func fetchBrowserSessions(storeId: UUID, limit: Int = 50) async throws -> [BrowserSession] {
        let sessions: [BrowserSession] = try await client.from("browser_sessions")
            .select()
            .eq("store_id", value: storeId)
            .order("last_activity", ascending: false)
            .limit(limit)
            .execute()
            .value

        return sessions
    }

    func fetchBrowserSession(id: UUID) async throws -> BrowserSession? {
        let sessions: [BrowserSession] = try await client.from("browser_sessions")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value

        return sessions.first
    }

    func fetchActiveBrowserSessions(storeId: UUID) async throws -> [BrowserSession] {
        let sessions: [BrowserSession] = try await client.from("browser_sessions")
            .select()
            .eq("store_id", value: storeId)
            .eq("status", value: "active")
            .order("last_activity", ascending: false)
            .execute()
            .value

        return sessions
    }

    func updateBrowserSessionStatus(id: UUID, status: String) async throws {
        try await client.from("browser_sessions")
            .update(["status": status, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id)
            .execute()
    }

    func createBrowserSession(storeId: UUID, name: String) async throws -> BrowserSession {
        let now = Date()
        let formatter = ISO8601DateFormatter()

        struct InsertData: Encodable {
            let store_id: String
            let name: String
            let status: String
            let created_at: String
            let updated_at: String
        }

        let insertData = InsertData(
            store_id: storeId.uuidString,
            name: name,
            status: "active",
            created_at: formatter.string(from: now),
            updated_at: formatter.string(from: now)
        )

        let session: BrowserSession = try await client.from("browser_sessions")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value

        return session
    }

    func deleteBrowserSession(id: UUID) async throws {
        try await client.from("browser_sessions")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func closeBrowserSession(id: UUID) async throws {
        struct UpdateData: Encodable {
            let status: String
            let updated_at: String
        }

        let updateData = UpdateData(
            status: "closed",
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await client.from("browser_sessions")
            .update(updateData)
            .eq("id", value: id)
            .execute()
    }
}
