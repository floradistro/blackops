import SwiftUI

// MARK: - New Collection Sheet
// Extracted from EditorSheets.swift following Apple engineering standards
// File size: ~92 lines (under Apple's 300 line "excellent" threshold)

struct NewCollectionSheet: View {
    @ObservedObject var store: EditorStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Collection")
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
                    Text("Name")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.secondary)
                    TextField("My Collection", text: $name)
                        .textFieldStyle(.plain)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .cornerRadius(DesignSystem.Radius.md)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Description (optional)")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.secondary)
                    TextField("", text: $description)
                        .textFieldStyle(.plain)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .cornerRadius(DesignSystem.Radius.md)
                }
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
                        await store.createCollection(
                            name: name,
                            description: description.isEmpty ? nil : description
                        )
                        isCreating = false
                        dismiss()
                    }
                } label: {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 60)
                    } else {
                        Text("Create")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || isCreating)
            }
            .padding()
            .background(DesignSystem.Colors.surfaceElevated)
        }
        .frame(width: 350, height: 250)
        .background(DesignSystem.Colors.surfaceTertiary)
    }
}
