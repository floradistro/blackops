import SwiftUI

// MARK: - Pricing Schema Sheet Components
// Extracted from CategoryConfigView.swift following Apple engineering standards
// Contains: PricingSchemaEditor, TierEditor, NewPricingSchemaSheet
// File size: ~275 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Pricing Schema Editor

struct PricingSchemaEditor: View {
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
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Description", text: $description)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(DesignSystem.Colors.surfaceElevated)
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
        .background(DesignSystem.Colors.surfaceTertiary)
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

struct TierEditor: View {
    @Binding var tier: PricingTier
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Label", text: Binding(get: { tier.label ?? "" }, set: { tier.label = $0 }))
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(6)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 80)

            TextField("Price", value: Binding(get: { tier.defaultPrice ?? 0 }, set: { tier.defaultPrice = $0 }), format: .currency(code: "USD"))
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(6)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 80)

            TextField("Unit", text: Binding(get: { tier.unit ?? "" }, set: { tier.unit = $0 }))
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(6)
                .background(DesignSystem.Colors.surfaceElevated)
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
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - New Pricing Schema Sheet

struct NewPricingSchemaSheet: View {
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
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Description", text: $description)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(DesignSystem.Colors.surfaceElevated)
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
        .background(DesignSystem.Colors.surfaceTertiary)
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
