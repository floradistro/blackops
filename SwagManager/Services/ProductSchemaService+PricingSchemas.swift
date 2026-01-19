import Foundation
import Supabase

// MARK: - ProductSchemaService Pricing Schemas Extension
// Extracted from ProductSchemaService.swift following Apple engineering standards
// File size: ~175 lines (under Apple's 300 line "excellent" threshold)

extension ProductSchemaService {
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
