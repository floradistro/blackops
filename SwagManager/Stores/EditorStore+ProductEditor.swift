import SwiftUI

// MARK: - EditorStore Product Editor Extension
// Business logic extracted from ProductEditorComponents.swift
// File size: ~80 lines (under Apple's 300 line "excellent" threshold)

/// Data container for product editor panel
struct ProductEditorData {
    var fieldSchemas: [FieldSchema] = []
    var pricingSchemaName: String?
    var stockByLocation: [(locationName: String, quantity: Int)] = []
}

extension EditorStore {
    // MARK: - Product Editor Data Loading

    /// Loads all data needed for the product editor panel
    func loadProductEditorData(for product: Product) async -> ProductEditorData {
        var data = ProductEditorData()

        // Load field schemas
        if let categoryId = product.primaryCategoryId {
            do {
                data.fieldSchemas = try await supabase.fetchFieldSchemasForCategory(categoryId: categoryId)
            } catch {
                NSLog("[EditorStore] Error loading field schemas: %@", String(describing: error))
            }
        }

        // Load pricing schema name
        if let schemaId = product.pricingSchemaId {
            do {
                let response = try await supabase.client
                    .from("pricing_schemas")
                    .select("name")
                    .eq("id", value: schemaId.uuidString)
                    .single()
                    .execute()

                if let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
                   let name = json["name"] as? String {
                    data.pricingSchemaName = name
                }
            } catch {
                NSLog("[EditorStore] Error loading pricing schema: %@", String(describing: error))
            }
        }

        // Load stock by location
        do {
            let response = try await supabase.client
                .from("inventory_products")
                .select("quantity, location:locations(name)")
                .eq("product_id", value: product.id.uuidString)
                .execute()

            if let items = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                var locations: [(String, Int)] = []
                for item in items {
                    if let locationDict = item["location"] as? [String: Any],
                       let locationName = locationDict["name"] as? String,
                       let quantity = item["quantity"] as? Int {
                        locations.append((locationName, quantity))
                    }
                }
                data.stockByLocation = locations.sorted { $0.0 < $1.0 }
            }
        } catch {
            NSLog("[EditorStore] Error loading stock by location: %@", String(describing: error))
        }

        return data
    }

    // MARK: - Product Updates

    /// Updates product fields and reloads catalog data
    func updateProduct(id: UUID, name: String?, sku: String?, description: String?, shortDescription: String?) async throws {
        var updates: [String: Any] = [:]

        if let name = name { updates["name"] = name }
        if let sku = sku { updates["sku"] = sku.isEmpty ? NSNull() : sku }
        if let description = description { updates["description"] = description.isEmpty ? NSNull() : description }
        if let shortDescription = shortDescription { updates["short_description"] = shortDescription.isEmpty ? NSNull() : shortDescription }

        guard !updates.isEmpty else { return }

        let jsonData = try JSONSerialization.data(withJSONObject: updates)
        try await supabase.client
            .from("products")
            .update(jsonData)
            .eq("id", value: id.uuidString)
            .execute()

        // Reload products to reflect changes
        await loadCatalogData()
    }
}
