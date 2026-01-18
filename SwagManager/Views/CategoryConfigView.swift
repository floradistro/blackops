import SwiftUI

// MARK: - Category Config View

struct CategoryConfigView: View {
    let category: Category
    @ObservedObject var store: EditorStore
    @State private var selectedTab: ConfigTab = .fields
    @State private var fieldSchemas: [FieldSchema] = []
    @State private var pricingSchemas: [PricingSchema] = []
    @State private var isLoading = true
    @State private var error: String?

    enum ConfigTab: String, CaseIterable {
        case fields = "Fields"
        case pricing = "Pricing"
        case settings = "Settings"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            configHeader

            // Tab bar
            configTabs

            // Content
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error = error {
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }

                        switch selectedTab {
                        case .fields:
                            fieldGroupsSection
                        case .pricing:
                            pricingTemplatesSection
                        case .settings:
                            categorySettingsSection
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(Color(white: 0.08))
        .task {
            await loadData()
        }
        .onChange(of: category.id) { _ in
            Task { await loadData() }
        }
    }

    // MARK: - Load Data

    private func loadData() async {
        isLoading = true
        error = nil

        do {
            async let fieldTask = SupabaseService.shared.fetchFieldSchemasForCategory(
                categoryName: category.name
            )
            async let pricingTask = SupabaseService.shared.fetchPricingSchemasForCategory(
                categoryName: category.name
            )

            let (fields, pricing) = try await (fieldTask, pricingTask)
            self.fieldSchemas = fields
            self.pricingSchemas = pricing
            NSLog("[CategoryConfig] Loaded \(fields.count) field schemas, \(pricing.count) pricing schemas for \(category.name)")
        } catch let decodingError as DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                self.error = "Missing key: \(key.stringValue) in \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case .typeMismatch(let type, let context):
                self.error = "Type mismatch: expected \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case .valueNotFound(let type, let context):
                self.error = "Value not found: \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case .dataCorrupted(let context):
                self.error = "Data corrupted at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            @unknown default:
                self.error = decodingError.localizedDescription
            }
            NSLog("[CategoryConfig] Decoding error: \(self.error ?? "unknown")")
        } catch {
            self.error = error.localizedDescription
            NSLog("[CategoryConfig] Error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Header

    private var configHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.system(size: 16, weight: .semibold))
                Text("Category Configuration")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Refresh button
            Button {
                Task { await loadData() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                // Save changes
            } label: {
                Text("Save")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(white: 0.06))
    }

    // MARK: - Tabs

    private var configTabs: some View {
        HStack(spacing: 0) {
            ForEach(ConfigTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))

                        // Show count badge
                        if tab == .fields && !fieldSchemas.isEmpty {
                            Text("\(fieldSchemas.count)")
                                .font(.system(size: 9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        } else if tab == .pricing && !pricingSchemas.isEmpty {
                            Text("\(pricingSchemas.count)")
                                .font(.system(size: 9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? Color.white.opacity(0.05) : Color.clear)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .background(Color(white: 0.065))
    }

    // MARK: - Field Schemas Section

    private var fieldGroupsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Field Schemas")
                .font(.system(size: 13, weight: .semibold))

            Text("Custom fields for products in this category.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if fieldSchemas.isEmpty {
                emptyState(
                    icon: "rectangle.stack",
                    title: "No Field Schemas",
                    message: "No field schemas apply to this category."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(fieldSchemas) { schema in
                        FieldSchemaRowView(schema: schema)
                    }
                }
            }

            Button {
                // Add field schema
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                    Text("Add Field Schema")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(white: 0.12))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Pricing Schemas Section

    private var pricingTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pricing Schemas")
                .font(.system(size: 13, weight: .semibold))

            Text("Pricing tiers for products in this category.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if pricingSchemas.isEmpty {
                emptyState(
                    icon: "tag",
                    title: "No Pricing Schemas",
                    message: "No pricing schemas apply to this category."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(pricingSchemas) { schema in
                        PricingSchemaRowView(schema: schema)
                    }
                }
            }

            Button {
                // Add pricing schema
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                    Text("Add Pricing Schema")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(white: 0.12))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Category Settings Section

    private var categorySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category Settings")
                .font(.system(size: 13, weight: .semibold))

            VStack(spacing: 12) {
                SettingRowView(label: "Name", value: category.name)
                SettingRowView(label: "Slug", value: category.slug)
                SettingRowView(label: "Description", value: category.description ?? "")
                SettingRowView(label: "Display Order", value: "\(category.displayOrder ?? 0)")
                SettingToggleView(label: "Active", isOn: category.isActive ?? true)
                SettingToggleView(label: "Featured", isOn: category.featured ?? false)
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(white: 0.1))
        .cornerRadius(8)
    }
}

// MARK: - Field Schema Row View

struct FieldSchemaRowView: View {
    let schema: FieldSchema

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let icon = schema.icon {
                        Text(icon)
                            .font(.system(size: 12))
                    }

                    Text(schema.name)
                        .font(.system(size: 12, weight: .medium))

                    Text("\(schema.fields.count) fields")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }

                if !schema.fields.isEmpty {
                    Text(schema.fields.map(\.displayLabel).joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if let desc = schema.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                // Edit
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(white: 0.12))
        .cornerRadius(8)
    }
}

// MARK: - Pricing Schema Row View

struct PricingSchemaRowView: View {
    let schema: PricingSchema

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "tag")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        Text(schema.name)
                            .font(.system(size: 12, weight: .medium))

                        Text("\(schema.tiers.count) tiers")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }

                    if let desc = schema.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    // Edit
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Show pricing tiers
            if !schema.tiers.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(schema.tiers.prefix(5).enumerated()), id: \.offset) { _, tier in
                        VStack(spacing: 2) {
                            Text(tier.displayLabel)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(tier.formattedPrice)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(4)
                    }
                    if schema.tiers.count > 5 {
                        Text("+\(schema.tiers.count - 5)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(white: 0.12))
        .cornerRadius(8)
    }
}

// MARK: - Setting Row View

struct SettingRowView: View {
    let label: String
    @State var value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            TextField("", text: $value)
                .font(.system(size: 11))
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(white: 0.12))
                .cornerRadius(6)
        }
    }
}

// MARK: - Setting Toggle View

struct SettingToggleView: View {
    let label: String
    @State var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.7)

            Spacer()
        }
    }
}
