import SwiftUI

// MARK: - New Category Sheet
// Minimal monochromatic theme

struct NewCategorySheet: View {
    var store: EditorStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var parentCategory: Category?
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Category")
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
                    Text("Category Name")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))
                    TextField("New Category", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Parent Category (Optional)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))
                    Picker("", selection: $parentCategory) {
                        Text("None (Top Level)").tag(nil as Category?)
                        ForEach(store.categories) { category in
                            Text(category.name).tag(category as Category?)
                        }
                    }
                    .labelsHidden()
                }

                Text("Categories help organize your products for easier navigation.")
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
                        await store.createCategory(name: name, parentId: parentCategory?.id)
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
                        Text(isCreating ? "Creating..." : "Create Category")
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
    }

    private var canCreate: Bool {
        !name.isEmpty && !isCreating
    }
}
