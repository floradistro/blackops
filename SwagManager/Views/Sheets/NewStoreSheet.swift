import SwiftUI

// MARK: - New Store Sheet
// Minimal monochromatic theme

struct NewStoreSheet: View {
    @Environment(\.editorStore) private var store
    @Environment(\.authManager) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Store")
                    .font(DesignSystem.font(13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.9))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.font(14))
                        .foregroundStyle(Color.primary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(Color.primary.opacity(0.02))

            Divider()
                .opacity(0.3)

            // Form
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Store Name")
                        .font(DesignSystem.font(11))
                        .foregroundStyle(Color.primary.opacity(0.5))
                    TextField("My Store", text: $name)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.font(13))
                        .padding(DesignSystem.Spacing.sm + 2)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(DesignSystem.Radius.sm)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Contact Email")
                        .font(DesignSystem.font(11))
                        .foregroundStyle(Color.primary.opacity(0.5))
                    TextField("store@example.com", text: $email)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.font(13))
                        .padding(DesignSystem.Spacing.sm + 2)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(DesignSystem.Radius.sm)
                }

                Text("The store will be your workspace for managing AI agents and tools.")
                    .font(DesignSystem.font(11))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
            .padding(DesignSystem.Spacing.lg)

            Spacer()

            // Actions
            Divider()
                .opacity(0.3)

            HStack(spacing: DesignSystem.Spacing.sm + 2) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(DesignSystem.font(11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.6))
                        .padding(.horizontal, DesignSystem.Spacing.md + 2)
                        .padding(.vertical, DesignSystem.Spacing.xs + 2)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(DesignSystem.Radius.xs + 1)
                }
                .buttonStyle(.plain)
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
                    HStack(spacing: DesignSystem.Spacing.xs + 2) {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        }
                        Text(isCreating ? "Creating..." : "Create Store")
                            .font(DesignSystem.font(11, weight: .medium))
                    }
                    .foregroundStyle(Color.primary.opacity(canCreate ? 0.8 : 0.3))
                    .padding(.horizontal, DesignSystem.Spacing.md + 2)
                    .padding(.vertical, DesignSystem.Spacing.xs + 2)
                    .background(Color.primary.opacity(canCreate ? 0.1 : 0.04))
                    .cornerRadius(DesignSystem.Radius.xs + 1)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 350, height: 280)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let userEmail = authManager.currentUser?.email {
                email = userEmail
            }
        }
    }

    private var canCreate: Bool {
        !name.isEmpty && !isCreating
    }
}
