import SwiftUI

// MARK: - Schema Row Components
// Extracted from CategoryConfigView.swift following Apple engineering standards
// Contains: FieldSchemaRow, PricingSchemaRow
// File size: ~270 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Field Schema Row

struct FieldSchemaRow: View {
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
                    .background(DesignSystem.Colors.surfaceElevated)
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
            .background(isHovering ? DesignSystem.Colors.surfaceTertiary : Color.clear)
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
                .background(DesignSystem.Colors.surfaceHover)
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

struct PricingSchemaRow: View {
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
                    .background(DesignSystem.Colors.surfaceElevated)
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
            .background(isHovering ? DesignSystem.Colors.surfaceTertiary : Color.clear)
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
                        .background(DesignSystem.Colors.surfaceTertiary)
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
                .background(DesignSystem.Colors.surfaceHover)
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
