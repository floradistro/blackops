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
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 10)
    }
}

struct EditableRow: View {
    let label: String
    @Binding var text: String
    @Binding var hasChanges: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 12))

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignSystem.Colors.surfaceTertiary)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignSystem.Materials.thin)

                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isFocused ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.borderSubtle, lineWidth: 1)
                    }
                }
                .focused($isFocused)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
                .onChange(of: text) { _, _ in hasChanges = true }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ProductFieldRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12))
    }
}

struct GlassTextEditor: View {
    let label: String
    @Binding var text: String
    let minHeight: CGFloat
    @Binding var hasChanges: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .font(.system(size: 12))
                .padding(10)
                .scrollContentBackground(.hidden)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.surfaceTertiary)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Materials.thin)

                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.borderSubtle, lineWidth: 1)
                    }
                }
                .focused($isFocused)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
                .onChange(of: text) { _, _ in hasChanges = true }
        }
    }
}

// MARK: - Custom Fields Section

struct CustomFieldsSection: View {
    let schemas: [FieldSchema]
    let fieldValues: [String: AnyCodable]?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Custom Fields")

            VStack(alignment: .leading, spacing: 18) {
                ForEach(schemas, id: \.id) { schema in
                    // Only show fields that have actual values
                    let fieldsWithValues = schema.fields.filter { hasFieldValue($0) }

                    if !fieldsWithValues.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(schema.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.3)

                            VStack(spacing: 8) {
                                ForEach(fieldsWithValues, id: \.fieldId) { field in
                                    HStack(spacing: 12) {
                                        Text(field.displayLabel)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .leading)
                                            .font(.system(size: 12))
                                        Text(getFieldValue(field))
                                            .font(.system(size: 12))
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func hasFieldValue(_ field: FieldDefinition) -> Bool {
        guard let fieldKey = field.key,
              let fieldValues = fieldValues else {
            return false
        }
        return fieldValues[fieldKey] != nil
    }

    private func getFieldValue(_ field: FieldDefinition) -> String {
        // Try to get actual value from product's custom_fields
        if let fieldKey = field.key,
           let fieldValues = fieldValues,
           let actualValue = fieldValues[fieldKey] {
            return "\(actualValue.value)"
        }

        // Fall back to default value from schema if no actual value exists
        if let defaultValue = field.defaultValue {
            return "\(defaultValue.value)"
        }

        return "-"
    }
}

// MARK: - Pricing Schemas Section

struct ProductPricingSection: View {
    let pricingData: AnyCodable
    let schemaName: String?

    var body: some View {
        let tiers = extractTiers()

        if !tiers.isEmpty {
            let title = schemaName.map { "\($0) Pricing" } ?? "Pricing Tiers"
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: title)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(tiers.enumerated()), id: \.offset) { index, tierDict in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(extractLabel(from: tierDict))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)

                                if let qty = extractQuantity(from: tierDict) {
                                    let unit = tierDict["unit"] as? String ?? "units"
                                    Text("(\(formatQuantity(qty)) \(unit))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(extractPrice(from: tierDict))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.green)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DesignSystem.Colors.surfaceTertiary)

                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DesignSystem.Materials.thin)

                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func extractTiers() -> [[String: Any]] {
        // Case 1: pricing_data is an array of tiers
        if let tiersArray = pricingData.value as? [[String: Any]] {
            return tiersArray
        }

        // Case 2: pricing_data is an object with a "tiers" property
        if let pricingObject = pricingData.value as? [String: Any],
           let tiersArray = pricingObject["tiers"] as? [[String: Any]] {
            return tiersArray
        }

        return []
    }

    private func extractLabel(from dict: [String: Any]) -> String {
        if let label = dict["label"] as? String {
            return label
        }
        if let id = dict["id"] as? String {
            return id
        }
        return "Tier"
    }

    private func extractQuantity(from dict: [String: Any]) -> Double? {
        if let qty = dict["quantity"] as? Double {
            return qty
        }
        if let qty = dict["quantity"] as? Int {
            return Double(qty)
        }
        return nil
    }

    private func extractPrice(from dict: [String: Any]) -> String {
        // Try default_price first (various types for PostgreSQL numeric compatibility)
        if let price = dict["default_price"] as? Double {
            return String(format: "$%.2f", price)
        }
        if let price = dict["default_price"] as? Decimal {
            return String(format: "$%.2f", NSDecimalNumber(decimal: price).doubleValue)
        }
        if let price = dict["default_price"] as? Int {
            return String(format: "$%.2f", Double(price))
        }
        if let priceStr = dict["default_price"] as? String, let price = Double(priceStr) {
            return String(format: "$%.2f", price)
        }

        // Try price field
        if let price = dict["price"] as? Double {
            return String(format: "$%.2f", price)
        }
        if let price = dict["price"] as? Decimal {
            return String(format: "$%.2f", NSDecimalNumber(decimal: price).doubleValue)
        }
        if let price = dict["price"] as? Int {
            return String(format: "$%.2f", Double(price))
        }
        if let priceStr = dict["price"] as? String, let price = Double(priceStr) {
            return String(format: "$%.2f", price)
        }

        return "-"
    }

    private func formatQuantity(_ qty: Double) -> String {
        if qty.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", qty)
        } else {
            return String(format: "%.1f", qty)
        }
    }
}

// MARK: - Welcome View
