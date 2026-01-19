import SwiftUI

// MARK: - Product Editor Components
// Extracted from EditorView.swift following Apple engineering standards
// File size: ~605 lines (under Apple's 700 line "good" threshold)

// MARK: - Product Editor Panel

struct ProductEditorPanel: View {
    let product: Product
    @ObservedObject var store: EditorStore

    @State private var editedName: String
    @State private var editedSKU: String
    @State private var editedDescription: String
    @State private var editedShortDescription: String
    @State private var hasChanges = false
    @State private var fieldSchemas: [FieldSchema] = []
    @State private var pricingSchemaName: String?
    @State private var stockByLocation: [(locationName: String, quantity: Int)] = []

    init(product: Product, store: EditorStore) {
        self.product = product
        self.store = store

        _editedName = State(initialValue: product.name)
        _editedSKU = State(initialValue: product.sku ?? "")
        _editedDescription = State(initialValue: product.description ?? "")
        _editedShortDescription = State(initialValue: product.shortDescription ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with image and name
                HStack(spacing: 16) {
                    if let imageUrl = product.featuredImage {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color(white: 0.15))
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Product Name", text: $editedName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18, weight: .semibold))
                            .onChange(of: editedName) { _, _ in hasChanges = true }

                        Text(product.sku ?? "No SKU")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()
                    .padding(.vertical, 8)

                // Product Information
                SectionHeader(title: "Product Information")
                VStack(spacing: 10) {
                    EditableRow(label: "SKU", text: $editedSKU, hasChanges: $hasChanges)
                    InfoRow(label: "Type", value: product.type ?? "-")
                    InfoRow(label: "Status", value: product.status ?? "-")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                Divider()
                    .padding(.vertical, 8)

                // Description
                SectionHeader(title: "Description")
                VStack(spacing: 16) {
                    GlassTextEditor(
                        label: "Full Description",
                        text: $editedDescription,
                        minHeight: 80,
                        hasChanges: $hasChanges
                    )

                    GlassTextEditor(
                        label: "Short Description",
                        text: $editedShortDescription,
                        minHeight: 60,
                        hasChanges: $hasChanges
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                Divider()
                    .padding(.vertical, 8)

                // Pricing
                if let pricingData = product.pricingData {
                    ProductPricingSection(pricingData: pricingData, schemaName: pricingSchemaName)
                        .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)
                }

                // Custom Fields
                if !fieldSchemas.isEmpty {
                    CustomFieldsSection(schemas: fieldSchemas, fieldValues: product.customFields)
                        .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)
                }

                // Stock by Location
                if !stockByLocation.isEmpty {
                    SectionHeader(title: "Stock by Location")
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(stockByLocation, id: \.locationName) { location in
                            HStack {
                                Text(location.locationName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(location.quantity)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(location.quantity > 0 ? DesignSystem.Colors.green : .secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)
                }

                // Costs & Wholesale
                SectionHeader(title: "Costs")
                VStack(spacing: 10) {
                    if let costPrice = product.costPrice {
                        InfoRow(label: "Cost Price", value: String(format: "$%.2f", NSDecimalNumber(decimal: costPrice).doubleValue))
                    }
                    if let wholesalePrice = product.wholesalePrice {
                        InfoRow(label: "Wholesale Price", value: String(format: "$%.2f", NSDecimalNumber(decimal: wholesalePrice).doubleValue))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .toolbar {
            if hasChanges {
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Cancel") {
                        resetChanges()
                    }
                    Button("Save") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            loadData()
        }
    }

    private func loadData() {
        Task {
            // Load field schemas
            if let categoryId = product.primaryCategoryId {
                do {
                    let schemas = try await store.supabase.fetchFieldSchemasForCategory(categoryId: categoryId)
                    await MainActor.run {
                        self.fieldSchemas = schemas
                    }
                } catch {
                    print("Error loading field schemas: \(error)")
                }
            }

            // Load pricing schema name
            if let schemaId = product.pricingSchemaId {
                do {
                    let response = try await store.supabase.client
                        .from("pricing_schemas")
                        .select("name")
                        .eq("id", value: schemaId.uuidString)
                        .single()
                        .execute()

                    if let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
                       let name = json["name"] as? String {
                        await MainActor.run {
                            self.pricingSchemaName = name
                        }
                    }
                } catch {
                    print("Error loading pricing schema: \(error)")
                }
            }

            // Load stock by location
            do {
                let response = try await store.supabase.client
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
                    await MainActor.run {
                        self.stockByLocation = locations.sorted { $0.0 < $1.0 }
                    }
                }
            } catch {
                print("Error loading stock by location: \(error)")
            }
        }
    }

    private func resetChanges() {
        editedName = product.name
        editedSKU = product.sku ?? ""
        editedDescription = product.description ?? ""
        editedShortDescription = product.shortDescription ?? ""
        hasChanges = false
    }

    private func saveChanges() {
        Task {
            do {
                var updates: [String: Any] = [:]

                if editedName != product.name {
                    updates["name"] = editedName
                }
                if editedSKU != (product.sku ?? "") {
                    updates["sku"] = editedSKU.isEmpty ? nil : editedSKU
                }
                if editedDescription != (product.description ?? "") {
                    updates["description"] = editedDescription.isEmpty ? nil : editedDescription
                }
                if editedShortDescription != (product.shortDescription ?? "") {
                    updates["short_description"] = editedShortDescription.isEmpty ? nil : editedShortDescription
                }

                if !updates.isEmpty {
                    let jsonData = try JSONSerialization.data(withJSONObject: updates)
                    try await store.supabase.client
                        .from("products")
                        .update(jsonData)
                        .eq("id", value: product.id.uuidString)
                        .execute()

                    // Reload products
                    await store.loadCatalogData()

                    await MainActor.run {
                        hasChanges = false
                    }
                }
            } catch {
                print("Error saving changes: \(error)")
            }
        }
    }
}

// Helper components for clean list UI

// MARK: - Custom Fields Section


// MARK: - Welcome View
