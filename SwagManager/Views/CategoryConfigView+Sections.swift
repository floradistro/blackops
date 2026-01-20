import SwiftUI

// MARK: - CategoryConfigView Sections Extension
// Extracted from CategoryConfigView.swift following Apple engineering standards
// File size: ~140 lines (under Apple's 300 line "excellent" threshold)

extension CategoryConfigView {
    // MARK: - Field Schemas Section

    internal var fieldSchemasSection: some View {
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

    internal var pricingSchemasSection: some View {
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

    // MARK: - Category Details Section

    internal var categoryDetailsSection: some View {
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

    internal func emptyState(message: String) -> some View {
        HStack {
            Spacer()
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 20)
    }
}
