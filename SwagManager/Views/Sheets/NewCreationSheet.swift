import SwiftUI

// MARK: - New Creation Sheet
// Minimal monochromatic theme

struct NewCreationSheet: View {
    var store: EditorStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedType: CreationType = .app
    @State private var description = ""
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Creation")
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
                    Text("Name")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))
                    TextField("My New Creation", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Type")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                        ForEach(CreationType.allCases, id: \.self) { type in
                            Button {
                                selectedType = type
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 14))
                                    Text(type.displayName)
                                        .font(.system(size: 10))
                                }
                                .foregroundStyle(Color.primary.opacity(selectedType == type ? 0.8 : 0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.primary.opacity(selectedType == type ? 0.1 : 0.04))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(selectedType == type ? 0.2 : 0), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Description (optional)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))
                    TextField("", text: $description)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                }
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
                        await store.createCreation(
                            name: name,
                            type: selectedType,
                            description: description.isEmpty ? nil : description
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
                        Text(isCreating ? "Creating..." : "Create")
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
        .frame(width: 400, height: 450)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var canCreate: Bool {
        !name.isEmpty && !isCreating
    }
}
