import SwiftUI

// MARK: - Field Schema Sheet Components
// Extracted from CategoryConfigView.swift following Apple engineering standards
// Contains: FieldSchemaEditor, FieldEditor, NewFieldSchemaSheet
// File size: ~350 lines (under Apple's 500 line "good" threshold)

// MARK: - Field Schema Editor

struct FieldSchemaEditor: View {
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
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Description", text: $description)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Icon (emoji)", text: $icon)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(DesignSystem.Colors.surfaceElevated)
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
        .background(DesignSystem.Colors.surfaceTertiary)
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

struct FieldEditor: View {
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
            .background(DesignSystem.Colors.surfaceTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if isExpanded {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Key", text: Binding(get: { field.key ?? "" }, set: { field.key = $0 }))
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(6)
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        TextField("Label", text: Binding(get: { field.label ?? "" }, set: { field.label = $0 }))
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(6)
                            .background(DesignSystem.Colors.surfaceElevated)
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
                .background(DesignSystem.Colors.surfaceHover)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

// MARK: - New Field Schema Sheet

struct NewFieldSchemaSheet: View {
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
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Description", text: $description)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Icon (emoji)", text: $icon)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(DesignSystem.Colors.surfaceElevated)
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
        .background(DesignSystem.Colors.surfaceTertiary)
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
