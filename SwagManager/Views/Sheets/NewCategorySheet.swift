import SwiftUI

// MARK: - New Category Sheet
// Extracted from EditorSheets.swift following Apple engineering standards
// File size: ~94 lines (under Apple's 300 line "excellent" threshold)

struct NewCategorySheet: View {
    @ObservedObject var store: EditorStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var parentCategory: Category?
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Category")
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
                    Text("Category Name")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.secondary)
                    TextField("New Category", text: $name)
                        .textFieldStyle(.plain)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .cornerRadius(DesignSystem.Radius.md)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Parent Category (Optional)")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $parentCategory) {
                        Text("None (Top Level)").tag(nil as Category?)
                        ForEach(store.categories) { category in
                            Text(category.name).tag(category as Category?)
                        }
                    }
                    .labelsHidden()
                }

                Text("Categories help organize your products for easier navigation.")
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
                        await store.createCategory(name: name, parentId: parentCategory?.id)
                        isCreating = false
                        dismiss()
                    }
                } label: {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 80)
                    } else {
                        Text("Create Category")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || isCreating)
            }
            .padding()
            .background(DesignSystem.Colors.surfaceElevated)
        }
        .frame(width: 350, height: 280)
        .background(DesignSystem.Colors.surfaceTertiary)
    }
}
