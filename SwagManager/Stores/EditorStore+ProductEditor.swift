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
        } catch {
            // Error loading product data
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

    // MARK: - Bulk Product Operations

    /// Updates status for multiple products (archive, publish, draft)
    @MainActor
    func bulkUpdateProductStatus(ids: [UUID], status: String) async {
        guard !ids.isEmpty else {
            print("⚠️ bulkUpdateProductStatus called with empty ids")
            return
        }

        struct StatusUpdate: Encodable {
            let status: String
        }

        print("🔄 Updating \(ids.count) products to status: \(status)")
        print("   IDs: \(ids.map { $0.uuidString })")

        do {
            // Update all products with matching IDs
            let response = try await supabase.client
                .from("products")
                .update(StatusUpdate(status: status))
                .in("id", values: ids.map { $0.uuidString })
                .execute()

            print("✅ Supabase response status: \(response.status)")

            // Reload products to reflect changes
            await loadCatalogData()
            print("✅ Catalog data reloaded. Product count: \(products.count)")
        } catch {
            print("❌ Failed to bulk update products: \(error)")
        }
    }

    /// Archives multiple products
    @MainActor
    func bulkArchiveProducts(ids: [UUID]) async {
        await bulkUpdateProductStatus(ids: ids, status: "archived")
    }

    /// Restores archived products to published status
    @MainActor
    func bulkRestoreProducts(ids: [UUID]) async {
        await bulkUpdateProductStatus(ids: ids, status: "published")
    }
}
