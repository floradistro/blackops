// Extracted from SupabaseService.swift following Apple engineering standards

import Foundation
import Supabase

@MainActor
final class ProductSchemaService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
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
}
