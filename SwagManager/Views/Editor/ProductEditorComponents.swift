import SwiftUI

// MARK: - Product Editor Components
// Business logic moved to EditorStore+ProductEditor.swift

// MARK: - Product Editor Panel

struct ProductEditorPanel: View {
    let product: Product
    @ObservedObject var store: EditorStore

    @State private var editedName: String
    @State private var editedSKU: String
    @State private var editedDescription: String
    @State private var editedShortDescription: String
    @State private var hasChanges = false
    @State private var editorData = ProductEditorData()

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
                    ProductPricingSection(pricingData: pricingData, schemaName: editorData.pricingSchemaName)
                        .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)
                }

                // Custom Fields
                if !editorData.fieldSchemas.isEmpty {
                    CustomFieldsSection(schemas: editorData.fieldSchemas, fieldValues: product.customFields)
                        .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)
                }

                // Stock by Location
                if !editorData.stockByLocation.isEmpty {
                    SectionHeader(title: "Stock by Location")
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(editorData.stockByLocation, id: \.locationName) { location in
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
            let data = await store.loadProductEditorData(for: product)
            await MainActor.run {
                self.editorData = data
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
                try await store.updateProduct(
                    id: product.id,
                    name: editedName != product.name ? editedName : nil,
                    sku: editedSKU != (product.sku ?? "") ? editedSKU : nil,
                    description: editedDescription != (product.description ?? "") ? editedDescription : nil,
                    shortDescription: editedShortDescription != (product.shortDescription ?? "") ? editedShortDescription : nil
                )
                await MainActor.run {
                    hasChanges = false
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
