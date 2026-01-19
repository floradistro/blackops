import SwiftUI

// MARK: - Category Config View

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
        .background(Theme.glass)
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
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.bgElevated)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "folder.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                )

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
        .background(Theme.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
            .background(Theme.bgHover)

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
        .background(Theme.bgTertiary)
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
            .background(Theme.bgHover)

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
        .background(Theme.bgTertiary)
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
            .background(Theme.bgHover)

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
        .background(Theme.bgTertiary)
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

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        error = nil
        let catalogId = category.catalogId ?? store.selectedCatalog?.id

        do {
            async let f1 = SupabaseService.shared.fetchFieldSchemasForCategory(categoryId: category.id)
            async let f2 = SupabaseService.shared.fetchPricingSchemasForCategory(categoryId: category.id)
            async let f3 = SupabaseService.shared.fetchAvailableFieldSchemas(catalogId: catalogId, categoryName: category.name)
            async let f4 = SupabaseService.shared.fetchAvailablePricingSchemas(catalogId: catalogId, categoryName: category.name)

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

// MARK: - Detail Row

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

// MARK: - Field Schema Row

private struct FieldSchemaRow: View {
    let schema: FieldSchema
    let isAssigned: Bool
    let isExpanded: Bool
    let onToggle: () async -> Void
    let onEdit: () -> Void
    let onDelete: () async -> Void
    let onExpand: () -> Void

    @State private var isHovering = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Expand chevron
                Button(action: onExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                // Toggle
                Toggle("", isOn: Binding(
                    get: { isAssigned },
                    set: { _ in Task { await onToggle() } }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .scaleEffect(0.85)

                // Icon
                if let icon = schema.icon {
                    Text(icon)
                        .font(.system(size: 14))
                } else {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                // Name & count
                Text(schema.name)
                    .font(.system(size: 12))
                    .lineLimit(1)

                Text("\(schema.fields.count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                Spacer()

                // Actions (show on hover)
                if isHovering {
                    HStack(spacing: 8) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                        Button { showDeleteConfirm = true } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.8))
                    }
                }

                // Assigned indicator
                if isAssigned {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovering ? Theme.bgTertiary : Color.clear)
            .onHover { isHovering = $0 }

            // Expanded fields
            if isExpanded && !schema.fields.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(schema.fields, id: \.fieldId) { field in
                        HStack(spacing: 8) {
                            Image(systemName: field.typeIcon)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .frame(width: 14)

                            Text(field.displayLabel)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                            if field.required ?? false {
                                Text("*")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.orange)
                            }

                            Spacer()

                            Text(field.fieldType)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.leading, 34)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 6)
                .background(Theme.bgHover)
            }
        }
        .alert("Delete Schema", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { Task { await onDelete() } }
        } message: {
            Text("Delete \"\(schema.name)\"? It will be archived, not permanently removed.")
        }
    }
}

// MARK: - Pricing Schema Row

private struct PricingSchemaRow: View {
    let schema: PricingSchema
    let isAssigned: Bool
    let isExpanded: Bool
    let onToggle: () async -> Void
    let onEdit: () -> Void
    let onDelete: () async -> Void
    let onExpand: () -> Void

    @State private var isHovering = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Expand chevron
                Button(action: onExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                // Toggle
                Toggle("", isOn: Binding(
                    get: { isAssigned },
                    set: { _ in Task { await onToggle() } }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .scaleEffect(0.85)

                // Icon
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                // Name & count
                Text(schema.name)
                    .font(.system(size: 12))
                    .lineLimit(1)

                Text("\(schema.tiers.count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                Spacer()

                // Actions (show on hover)
                if isHovering {
                    HStack(spacing: 8) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                        Button { showDeleteConfirm = true } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.8))
                    }
                }

                // Assigned indicator
                if isAssigned {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovering ? Theme.bgTertiary : Color.clear)
            .onHover { isHovering = $0 }

            // Expanded tiers
            if isExpanded && !schema.tiers.isEmpty {
                HStack(spacing: 6) {
                    ForEach(schema.tiers.prefix(8), id: \.tierId) { tier in
                        VStack(spacing: 2) {
                            Text(tier.displayLabel)
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                            Text(tier.formattedPrice)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Theme.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if schema.tiers.count > 8 {
                        Text("+\(schema.tiers.count - 8)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.leading, 34)
                .padding(.vertical, 8)
                .background(Theme.bgHover)
            }
        }
        .alert("Delete Schema", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { Task { await onDelete() } }
        } message: {
            Text("Delete \"\(schema.name)\"? It will be archived, not permanently removed.")
        }
    }
}

// MARK: - Field Schema Editor

private struct FieldSchemaEditor: View {
    let schema: FieldSchema
    let catalogId: UUID?
    let onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var fields: [FieldDefinition]
    @State private var isSaving = false
    @State private var error: String?

    init(schema: FieldSchema, catalogId: UUID?, onSave: @escaping () async -> Void) {
        self.schema = schema
        self.catalogId = catalogId
        self.onSave = onSave
        _name = State(initialValue: schema.name)
        _description = State(initialValue: schema.description ?? "")
        _icon = State(initialValue: schema.icon ?? "")
        _fields = State(initialValue: schema.fields)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Field Schema")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider().opacity(0.3)

            // Form
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    // Basic info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DETAILS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)

                        TextField("Name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Theme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Description", text: $description)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Theme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Icon (emoji)", text: $icon)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Theme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .frame(width: 100)
                    }

                    // Fields
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("FIELDS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button {
                                fields.append(FieldDefinition(key: "new_field", name: "New Field", label: "New Field", type: "text", required: false))
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }

                        ForEach(fields.indices, id: \.self) { i in
                            FieldEditor(field: $fields[i]) {
                                fields.remove(at: i)
                            }
                        }
                    }

                    if let error = error {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.automatic)

            Divider().opacity(0.3)

            // Footer
            HStack {
                Spacer()
                Button("Save") {
                    Task { await save() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(name.isEmpty || isSaving)
            }
            .padding(16)
        }
        .frame(width: 420, height: 500)
        .background(Theme.bgTertiary)
    }

    private func save() async {
        isSaving = true
        do {
            try await SupabaseService.shared.updateFieldSchema(schemaId: schema.id, name: name, description: description.isEmpty ? nil : description, icon: icon.isEmpty ? nil : icon, fields: fields)
            await onSave()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Field Editor

private struct FieldEditor: View {
    @Binding var field: FieldDefinition
    let onDelete: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)

                Image(systemName: field.typeIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Text(field.displayLabel)
                    .font(.system(size: 11))

                if field.required ?? false {
                    Text("*")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                }

                Spacer()

                Text(field.fieldType)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(8)
            .background(Theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if isExpanded {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Key", text: Binding(get: { field.key ?? "" }, set: { field.key = $0 }))
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(6)
                            .background(Theme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        TextField("Label", text: Binding(get: { field.label ?? "" }, set: { field.label = $0 }))
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(6)
                            .background(Theme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    HStack(spacing: 8) {
                        Picker("", selection: Binding(get: { field.type ?? "text" }, set: { field.type = $0 })) {
                            Text("Text").tag("text")
                            Text("Number").tag("number")
                            Text("Select").tag("select")
                            Text("Boolean").tag("boolean")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 100)

                        Toggle("Required", isOn: Binding(get: { field.required ?? false }, set: { field.required = $0 }))
                            .toggleStyle(.checkbox)
                            .font(.system(size: 11))

                        Spacer()

                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.8))
                    }
                }
                .padding(8)
                .background(Theme.bgHover)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

// MARK: - Pricing Schema Editor

private struct PricingSchemaEditor: View {
    let schema: PricingSchema
    let catalogId: UUID?
    let onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var tiers: [PricingTier]
    @State private var isSaving = false
    @State private var error: String?

    init(schema: PricingSchema, catalogId: UUID?, onSave: @escaping () async -> Void) {
        self.schema = schema
        self.catalogId = catalogId
        self.onSave = onSave
        _name = State(initialValue: schema.name)
        _description = State(initialValue: schema.description ?? "")
        _tiers = State(initialValue: schema.tiers)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Pricing Schema")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider().opacity(0.3)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DETAILS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)

                        TextField("Name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Theme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Description", text: $description)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Theme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("TIERS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button {
                                tiers.append(PricingTier(id: UUID().uuidString, unit: "unit", label: "New", quantity: 1, sortOrder: tiers.count, defaultPrice: 0))
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }

                        ForEach(tiers.indices, id: \.self) { i in
                            TierEditor(tier: $tiers[i]) { tiers.remove(at: i) }
                        }
                    }

                    if let error = error {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.automatic)

            Divider().opacity(0.3)

            HStack {
                Spacer()
                Button("Save") { Task { await save() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(name.isEmpty || isSaving)
            }
            .padding(16)
        }
        .frame(width: 420, height: 500)
        .background(Theme.bgTertiary)
    }

    private func save() async {
        isSaving = true
        do {
            try await SupabaseService.shared.updatePricingSchema(schemaId: schema.id, name: name, description: description.isEmpty ? nil : description, tiers: tiers)
            await onSave()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Tier Editor

private struct TierEditor: View {
    @Binding var tier: PricingTier
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Label", text: Binding(get: { tier.label ?? "" }, set: { tier.label = $0 }))
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(6)
                .background(Theme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 80)

            TextField("Price", value: Binding(get: { tier.defaultPrice ?? 0 }, set: { tier.defaultPrice = $0 }), format: .currency(code: "USD"))
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(6)
                .background(Theme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 80)

            TextField("Unit", text: Binding(get: { tier.unit ?? "" }, set: { tier.unit = $0 }))
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(6)
                .background(Theme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 60)

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
        }
        .padding(8)
        .background(Theme.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - New Field Schema Sheet

private struct NewFieldSchemaSheet: View {
    let catalogId: UUID?
    let categoryName: String
    let onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var icon = ""
    @State private var fields: [FieldDefinition] = []
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Field Schema")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider().opacity(0.3)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DETAILS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)

                        TextField("Name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Theme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Description", text: $description)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Theme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Icon (emoji)", text: $icon)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Theme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .frame(width: 100)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("FIELDS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button {
                                fields.append(FieldDefinition(key: "new_field", name: "New Field", label: "New Field", type: "text", required: false))
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }

                        if fields.isEmpty {
                            Text("No fields yet")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(fields.indices, id: \.self) { i in
                                FieldEditor(field: $fields[i]) { fields.remove(at: i) }
                            }
                        }
                    }

                    if let error = error {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.automatic)

            Divider().opacity(0.3)

            HStack {
                Spacer()
                Button("Create") { Task { await save() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(name.isEmpty || isSaving)
            }
            .padding(16)
        }
        .frame(width: 420, height: 500)
        .background(Theme.bgTertiary)
    }

    private func save() async {
        isSaving = true
        do {
            _ = try await SupabaseService.shared.createFieldSchema(name: name, description: description.isEmpty ? nil : description, icon: icon.isEmpty ? nil : icon, fields: fields, catalogId: catalogId, applicableCategories: [categoryName])
            await onSave()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - New Pricing Schema Sheet

private struct NewPricingSchemaSheet: View {
    let catalogId: UUID?
    let categoryName: String
    let onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var tiers: [PricingTier] = []
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Pricing Schema")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider().opacity(0.3)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DETAILS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)

                        TextField("Name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Theme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Description", text: $description)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Theme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("TIERS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button {
                                tiers.append(PricingTier(id: UUID().uuidString, unit: "unit", label: "New", quantity: 1, sortOrder: tiers.count, defaultPrice: 0))
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }

                        if tiers.isEmpty {
                            Text("No tiers yet")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(tiers.indices, id: \.self) { i in
                                TierEditor(tier: $tiers[i]) { tiers.remove(at: i) }
                            }
                        }
                    }

                    if let error = error {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.automatic)

            Divider().opacity(0.3)

            HStack {
                Spacer()
                Button("Create") { Task { await save() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(name.isEmpty || isSaving)
            }
            .padding(16)
        }
        .frame(width: 420, height: 500)
        .background(Theme.bgTertiary)
    }

    private func save() async {
        isSaving = true
        do {
            _ = try await SupabaseService.shared.createPricingSchema(name: name, description: description.isEmpty ? nil : description, tiers: tiers, catalogId: catalogId, applicableCategories: [categoryName])
            await onSave()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
