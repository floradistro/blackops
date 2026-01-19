import SwiftUI

// MARK: - Editor Sheet Components
// Extracted from EditorView.swift to reduce file size and improve organization

// MARK: - New Creation Sheet

struct NewCreationSheet: View {
    @ObservedObject var store: EditorStore
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
                    TextField("My New Creation", text: $name)
                        .textFieldStyle(.plain)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .cornerRadius(DesignSystem.Radius.md)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Type")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: DesignSystem.Spacing.sm) {
                        ForEach(CreationType.allCases, id: \.self) { type in
                            Button {
                                selectedType = type
                            } label: {
                                VStack(spacing: DesignSystem.Spacing.xxs) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: DesignSystem.IconSize.medium))
                                    Text(type.displayName)
                                        .font(DesignSystem.Typography.caption1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                .background(selectedType == type ? Color.blue.opacity(0.3) : DesignSystem.Colors.surfaceElevated)
                                .foregroundStyle(selectedType == type ? .primary : .secondary)
                                .cornerRadius(DesignSystem.Radius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                        .stroke(selectedType == type ? Color.blue : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
                        await store.createCreation(
                            name: name,
                            type: selectedType,
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
        .frame(width: 400, height: 450)
        .background(DesignSystem.Colors.surfaceTertiary)
    }
}

// MARK: - New Collection Sheet

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

// MARK: - New Store Sheet

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

// MARK: - New Catalog Sheet

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

// MARK: - New Category Sheet

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
