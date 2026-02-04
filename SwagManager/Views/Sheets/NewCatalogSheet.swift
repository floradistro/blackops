import SwiftUI

// MARK: - New Catalog Sheet
// Minimal monochromatic theme

struct NewCatalogSheet: View {
    var store: EditorStore
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
                    Text("Catalog Name")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))
                    TextField("Master Catalog", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Vertical / Industry")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))

                    HStack(spacing: 6) {
                        ForEach(verticals, id: \.0) { vertical in
                            Button {
                                selectedVertical = vertical.0
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: vertical.2)
                                        .font(.system(size: 14))
                                    Text(vertical.1)
                                        .font(.system(size: 9))
                                }
                                .foregroundStyle(Color.primary.opacity(selectedVertical == vertical.0 ? 0.8 : 0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.primary.opacity(selectedVertical == vertical.0 ? 0.1 : 0.04))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(selectedVertical == vertical.0 ? 0.2 : 0), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Toggle("Set as default catalog", isOn: $isDefault)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.6))

                Text("Catalogs contain categories, products, and pricing structures for different business verticals.")
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
                        await store.createCatalog(name: name, vertical: selectedVertical, isDefault: isDefault)
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
                        Text(isCreating ? "Creating..." : "Create Catalog")
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
        .frame(width: 420, height: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var canCreate: Bool {
        !name.isEmpty && !isCreating
    }
}
