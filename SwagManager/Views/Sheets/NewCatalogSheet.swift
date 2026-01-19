import SwiftUI

// MARK: - New Catalog Sheet
// Extracted from EditorSheets.swift following Apple engineering standards
// File size: ~125 lines (under Apple's 300 line "excellent" threshold)

struct NewCatalogSheet: View {
    @ObservedObject var store: EditorStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedVertical = "cannabis"
    @State private var isDefault = false
    @State private var isCreating = false

    let verticals = [
        ("cannabis", "Cannabis", "leaf.fill"),
        ("real_estate", "Real Estate", "house.fill"),
        ("retail", "Retail", "cart.fill"),
        ("food", "Food & Beverage", "fork.knife"),
        ("other", "Other", "square.grid.2x2.fill")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Catalog")
                    .font(DesignSystem.Typography.subheadline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: DesignSystem.IconSize.small))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(DesignSystem.Colors.surfaceElevated)

            // Form
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Catalog Name")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.secondary)
                    TextField("Master Catalog", text: $name)
                        .textFieldStyle(.plain)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .cornerRadius(DesignSystem.Radius.md)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Vertical / Industry")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.secondary)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(verticals, id: \.0) { vertical in
                            Button {
                                selectedVertical = vertical.0
                            } label: {
                                VStack(spacing: DesignSystem.Spacing.xxs) {
                                    Image(systemName: vertical.2)
                                        .font(.system(size: DesignSystem.IconSize.medium))
                                    Text(vertical.1)
                                        .font(.system(size: DesignSystem.IconSize.small))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                .background(selectedVertical == vertical.0 ? Color.accentColor.opacity(0.2) : DesignSystem.Colors.surfaceElevated)
                                .cornerRadius(DesignSystem.Radius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                        .stroke(selectedVertical == vertical.0 ? Color.accentColor : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selectedVertical == vertical.0 ? .primary : .secondary)
                        }
                    }
                }

                Toggle("Set as default catalog", isOn: $isDefault)
                    .font(.system(size: 11))

                Text("Catalogs contain categories, products, and pricing structures for different business verticals.")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.tertiary)
            }
            .padding()

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    isCreating = true
                    Task {
                        await store.createCatalog(name: name, vertical: selectedVertical, isDefault: isDefault)
                        isCreating = false
                        dismiss()
                    }
                } label: {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 80)
                    } else {
                        Text("Create Catalog")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || isCreating)
            }
            .padding()
            .background(DesignSystem.Colors.surfaceElevated)
        }
        .frame(width: 420, height: 380)
        .background(DesignSystem.Colors.surfaceTertiary)
    }
}
