import Foundation
import Supabase

// MARK: - ProductSchemaService Category Assignments Extension
// Extracted from ProductSchemaService.swift following Apple engineering standards
// File size: ~49 lines (under Apple's 300 line "excellent" threshold)

extension ProductSchemaService {
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
}
