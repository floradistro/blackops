import SwiftUI

// MARK: - Category Config View (REFACTORED - Apple Standard)
//
// Previously 1,319 lines → 400 lines → now ~100 lines by extracting:
// - CategoryConfigView+Header.swift (70 lines) - Header section and error banner
// - CategoryConfigView+Sections.swift (140 lines) - Field/pricing schemas sections
// - CategoryConfigView+DataOperations.swift (80 lines) - Load/toggle/delete operations
//
// File size: ~100 lines (under Apple's 300 line "excellent" threshold)

struct CategoryConfigView: View {
    let category: Category
    @ObservedObject var store: EditorStore

    @State internal var assignedFieldSchemas: [FieldSchema] = []
    @State internal var assignedPricingSchemas: [PricingSchema] = []
    @State internal var availableFieldSchemas: [FieldSchema] = []
    @State internal var availablePricingSchemas: [PricingSchema] = []
    @State internal var isLoading = true
    @State internal var error: String?

    @State internal var editingFieldSchema: FieldSchema?
    @State internal var editingPricingSchema: PricingSchema?
    @State internal var showNewFieldSchema = false
    @State internal var showNewPricingSchema = false
    @State internal var expandedFieldSchemaId: UUID?
    @State internal var expandedPricingSchemaId: UUID?

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        headerSection

                        if let error = error {
                            errorBanner(error)
                        }

                        fieldSchemasSection
                        pricingSchemasSection
                        categoryDetailsSection
                    }
                    .padding(20)
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.automatic)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Materials.thin)
        .task { await loadData() }
        .onChange(of: category.id) { _, _ in Task { await loadData() } }
        .sheet(item: $editingFieldSchema) { schema in
            FieldSchemaEditor(schema: schema, catalogId: category.catalogId ?? store.selectedCatalog?.id) {
                await loadData()
            }
        }
        .sheet(item: $editingPricingSchema) { schema in
            PricingSchemaEditor(schema: schema, catalogId: category.catalogId ?? store.selectedCatalog?.id) {
                await loadData()
            }
        }
        .sheet(isPresented: $showNewFieldSchema) {
            NewFieldSchemaSheet(catalogId: category.catalogId ?? store.selectedCatalog?.id, categoryName: category.name) {
                await loadData()
            }
        }
        .sheet(isPresented: $showNewPricingSchema) {
            NewPricingSchemaSheet(catalogId: category.catalogId ?? store.selectedCatalog?.id, categoryName: category.name) {
                await loadData()
            }
        }
    }
}

// MARK: - Detail Row (Small Helper - Kept in main file)

internal struct DetailRow: View {
    let label: String
    let value: String
    var mono: Bool = false
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: mono ? .monospaced : .default))
                .foregroundStyle(color)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
