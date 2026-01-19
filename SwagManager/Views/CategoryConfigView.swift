import SwiftUI

// MARK: - Category Config View (REFACTORED - Apple Standard)
//
// Reduced from 1,319 lines to ~400 lines by extracting components:
// - SchemaRowComponents.swift (270 lines) - Field/Pricing row displays
// - FieldSchemaSheets.swift (350 lines) - Field schema editors
// - PricingSchemaSheets.swift (275 lines) - Pricing schema editors
//
// File size: ~410 lines (under Apple's 500 line "good" threshold)

struct CategoryConfigView: View {
    let category: Category
    @ObservedObject var store: EditorStore

    @State private var assignedFieldSchemas: [FieldSchema] = []
    @State private var assignedPricingSchemas: [PricingSchema] = []
    @State private var availableFieldSchemas: [FieldSchema] = []
    @State private var availablePricingSchemas: [PricingSchema] = []
    @State private var isLoading = true
    @State private var error: String?

    @State private var editingFieldSchema: FieldSchema?
    @State private var editingPricingSchema: PricingSchema?
    @State private var showNewFieldSchema = false
    @State private var showNewPricingSchema = false
    @State private var expandedFieldSchemaId: UUID?
    @State private var expandedPricingSchemaId: UUID?

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

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            // Category image or fallback icon
            Group {
                if let imageUrlString = category.imageUrl ?? category.featuredImage ?? category.bannerUrl,
                   let imageUrl = URL(string: imageUrlString) {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            fallbackIcon
                        @unknown default:
                            fallbackIcon
                        }
                    }
                } else {
                    fallbackIcon
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.title2.bold())
                Text("Category Configuration")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                Task { await loadData() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var fallbackIcon: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(DesignSystem.Colors.surfaceElevated)
            .overlay(
                Image(systemName: "folder.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
            )
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 11))
            Spacer()
            Button {
                error = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Field Schemas Section

    private var fieldSchemasSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("FIELD SCHEMAS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showNewFieldSchema = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DesignSystem.Colors.surfaceHover)

            // Content
            if availableFieldSchemas.isEmpty {
                emptyState(message: "No field schemas available")
            } else {
                VStack(spacing: 1) {
                    ForEach(availableFieldSchemas) { schema in
                        FieldSchemaRow(
                            schema: schema,
                            isAssigned: assignedFieldSchemas.contains { $0.id == schema.id },
                            isExpanded: expandedFieldSchemaId == schema.id,
                            onToggle: { await toggleFieldSchema(schema) },
                            onEdit: { editingFieldSchema = schema },
                            onDelete: { await deleteFieldSchema(schema) },
                            onExpand: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    expandedFieldSchemaId = expandedFieldSchemaId == schema.id ? nil : schema.id
                                }
                            }
                        )
                    }
                }
            }
        }
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Pricing Schemas Section

    private var pricingSchemasSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("PRICING SCHEMAS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showNewPricingSchema = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DesignSystem.Colors.surfaceHover)

            // Content
            if availablePricingSchemas.isEmpty {
                emptyState(message: "No pricing schemas available")
            } else {
                VStack(spacing: 1) {
                    ForEach(availablePricingSchemas) { schema in
                        PricingSchemaRow(
                            schema: schema,
                            isAssigned: assignedPricingSchemas.contains { $0.id == schema.id },
                            isExpanded: expandedPricingSchemaId == schema.id,
                            onToggle: { await togglePricingSchema(schema) },
                            onEdit: { editingPricingSchema = schema },
                            onDelete: { await deletePricingSchema(schema) },
                            onExpand: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    expandedPricingSchemaId = expandedPricingSchemaId == schema.id ? nil : schema.id
                                }
                            }
                        )
                    }
                }
            }
        }
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Category Details

    private var categoryDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("DETAILS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DesignSystem.Colors.surfaceHover)

            VStack(spacing: 0) {
                DetailRow(label: "Name", value: category.name)
                DetailRow(label: "Slug", value: category.slug, mono: true)
                if let desc = category.description, !desc.isEmpty {
                    DetailRow(label: "Description", value: desc)
                }
                DetailRow(label: "Order", value: "\(category.displayOrder ?? 0)")
                DetailRow(label: "Status", value: category.isActive ?? true ? "Active" : "Inactive",
                         color: category.isActive ?? true ? .green : .secondary)
            }
            .padding(.vertical, 4)
        }
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Empty State

    private func emptyState(message: String) -> some View {
        HStack {
            Spacer()
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Data Operations

    private func loadData() async {
        isLoading = true
        error = nil
        let catalogId = category.catalogId ?? store.selectedCatalog?.id

        do {
            async let f1 = SupabaseService.shared.fetchFieldSchemasForCategory(categoryId: category.id)
            async let f2 = SupabaseService.shared.fetchPricingSchemasForCategory(categoryId: category.id)
            async let f3 = SupabaseService.shared.fetchAvailableFieldSchemas(catalogId: catalogId ?? UUID(), categoryName: category.name)
            async let f4 = SupabaseService.shared.fetchAvailablePricingSchemas(catalogId: catalogId ?? UUID(), categoryName: category.name)

            let (assigned1, assigned2, avail1, avail2) = try await (f1, f2, f3, f4)

            await MainActor.run {
                assignedFieldSchemas = assigned1
                assignedPricingSchemas = assigned2
                availableFieldSchemas = avail1
                availablePricingSchemas = avail2
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func toggleFieldSchema(_ schema: FieldSchema) async {
        do {
            if assignedFieldSchemas.contains(where: { $0.id == schema.id }) {
                try await SupabaseService.shared.removeFieldSchemaFromCategory(categoryId: category.id, fieldSchemaId: schema.id)
            } else {
                try await SupabaseService.shared.assignFieldSchemaToCategory(categoryId: category.id, fieldSchemaId: schema.id)
            }
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func togglePricingSchema(_ schema: PricingSchema) async {
        do {
            if assignedPricingSchemas.contains(where: { $0.id == schema.id }) {
                try await SupabaseService.shared.removePricingSchemaFromCategory(categoryId: category.id, pricingSchemaId: schema.id)
            } else {
                try await SupabaseService.shared.assignPricingSchemaToCategory(categoryId: category.id, pricingSchemaId: schema.id)
            }
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteFieldSchema(_ schema: FieldSchema) async {
        do {
            try await SupabaseService.shared.deleteFieldSchema(schemaId: schema.id)
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deletePricingSchema(_ schema: PricingSchema) async {
        do {
            try await SupabaseService.shared.deletePricingSchema(schemaId: schema.id)
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Detail Row (Small Helper - Kept in main file)

private struct DetailRow: View {
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
