import Foundation
import Supabase

// MARK: - ProductSchemaService Field Schemas Extension
// Extracted from ProductSchemaService.swift following Apple engineering standards
// File size: ~180 lines (under Apple's 300 line "excellent" threshold)

extension ProductSchemaService {
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

    /// Fetches available field schemas using backend RPC (single filtered query)
    func fetchAvailableFieldSchemas(catalogId: UUID?, categoryName: String?) async throws -> [FieldSchema] {
        var params: [String: String] = [:]
        if let catalogId = catalogId {
            params["p_catalog_id"] = catalogId.uuidString
        }
        if let categoryName = categoryName {
            params["p_category_name"] = categoryName
        }

        let response = try await client
            .rpc("get_field_schemas", params: params)
            .execute()

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let schemas = try decoder.decode([FieldSchema].self, from: response.data)

        NSLog("[ProductSchemaService] Fetched \(schemas.count) field schemas via RPC for catalog \(catalogId?.uuidString ?? "nil"), category \(categoryName ?? "nil")")
        return schemas
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
}
