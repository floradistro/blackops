import SwiftUI

// MARK: - New Store Sheet
// Extracted from EditorSheets.swift following Apple engineering standards
// File size: ~103 lines (under Apple's 300 line "excellent" threshold)

struct NewStoreSheet: View {
    @ObservedObject var store: EditorStore
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Store")
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
                    Text("Store Name")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.secondary)
                    TextField("My Store", text: $name)
                        .textFieldStyle(.plain)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .cornerRadius(DesignSystem.Radius.md)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Contact Email")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.secondary)
                    TextField("store@example.com", text: $email)
                        .textFieldStyle(.plain)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .cornerRadius(DesignSystem.Radius.md)
                }

                Text("The store will be your workspace for managing products, creations, and settings.")
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
                        await store.createStore(
                            name: name,
                            email: email.isEmpty ? (authManager.currentUser?.email ?? "no-email@example.com") : email,
                            ownerUserId: authManager.currentUser?.id
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
                        Text("Create Store")
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
        .onAppear {
            if let userEmail = authManager.currentUser?.email {
                email = userEmail
            }
        }
    }
}
