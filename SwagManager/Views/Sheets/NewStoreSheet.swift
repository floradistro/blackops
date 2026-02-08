import SwiftUI

// MARK: - New Store Sheet
// Minimal monochromatic theme

struct NewStoreSheet: View {
    @Environment(\.editorStore) private var store
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.9))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.primary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.primary.opacity(0.02))

            Divider()
                .opacity(0.3)

            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Store Name")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))
                    TextField("My Store", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Contact Email")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))
                    TextField("store@example.com", text: $email)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                }

                Text("The store will be your workspace for managing AI agents and tools.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
            .padding(16)

            Spacer()

            // Actions
            Divider()
                .opacity(0.3)

            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(5)
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
                    HStack(spacing: 6) {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        }
                        Text(isCreating ? "Creating..." : "Create Store")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.primary.opacity(canCreate ? 0.8 : 0.3))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(canCreate ? 0.1 : 0.04))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate)
            }
            .padding(16)
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
