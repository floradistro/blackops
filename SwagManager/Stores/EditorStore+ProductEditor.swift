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

    /// Loads all data needed for the product editor panel via single RPC call
    /// Uses backend RPC: get_product_editor_data (replaces 3 sequential queries)
    func loadProductEditorData(for product: Product) async -> ProductEditorData {
        var data = ProductEditorData()

        do {
            let response = try await supabase.client
                .rpc("get_product_editor_data", params: ["p_product_id": product.id.uuidString])
                .execute()

            guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
                NSLog("[EditorStore] RPC returned invalid JSON")
                return data
            }

            // Parse field schemas
            if let schemasArray = json["field_schemas"] as? [[String: Any]] {
                let schemasData = try JSONSerialization.data(withJSONObject: schemasArray)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                data.fieldSchemas = (try? decoder.decode([FieldSchema].self, from: schemasData)) ?? []
            }

            // Parse pricing schema name
            data.pricingSchemaName = json["pricing_schema_name"] as? String

            // Parse stock by location
            if let stockArray = json["stock_by_location"] as? [[String: Any]] {
                data.stockByLocation = stockArray.compactMap { item in
                    guard let name = item["location_name"] as? String,
                          let qty = item["quantity"] as? Int else { return nil }
                    return (name, qty)
                }
            }

            NSLog("[EditorStore] Loaded product editor data via RPC: %d schemas, %d locations",
                  data.fieldSchemas.count, data.stockByLocation.count)
        } catch {
            NSLog("[EditorStore] Error loading product editor data: %@", String(describing: error))
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
