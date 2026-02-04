import SwiftUI
import AppKit

// MARK: - Glass UI Components
// Recreated from deleted UnifiedGlassComponents.swift

// MARK: - Visual Effect Background (NSVisualEffectView wrapper)

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

// MARK: - Glass Panel

struct GlassPanel<Content: View, HeaderActions: View>: View {
    let title: String
    let showHeader: Bool
    let headerActions: () -> HeaderActions
    let content: () -> Content

    init(
        title: String,
        showHeader: Bool = true,
        @ViewBuilder headerActions: @escaping () -> HeaderActions = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showHeader = showHeader
        self.headerActions = headerActions
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            if showHeader {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    headerActions()
                }
                .padding()
                .background(VisualEffectBackground(material: .sidebar))
            }

            ScrollView {
                content()
                    .padding()
            }
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
    }
}

// Convenience initializer for GlassPanel with no header actions
extension GlassPanel where HeaderActions == EmptyView {
    init(
        title: String,
        showHeader: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showHeader = showHeader
        self.headerActions = { EmptyView() }
        self.content = content
    }
}

// MARK: - Glass Section

struct GlassSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            content()
        }
        .padding(DesignSystem.Spacing.md)
        .background(VisualEffectBackground(material: .sidebar))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

// MARK: - Common UI Components

struct SectionHeader: View {
    let title: String
    let icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    init(title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

// MARK: - Stub Views (for features not yet implemented)

struct POSSettingsView: View {
    var store: EditorStore
    let locationId: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("POS Settings")
                .font(.title2.bold())
            Text("Register & Printer settings")
                .foregroundStyle(.secondary)
            Button("Close") { dismiss() }
        }
        .padding(40)
        .frame(minWidth: 300)
    }
}

struct LabelPrinterSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Label Printer Settings")
                .font(.title2.bold())
            Text("Configure your label printer")
                .foregroundStyle(.secondary)
            Button("Close") { dismiss() }
        }
        .padding(40)
        .frame(minWidth: 300)
    }
}

// MARK: - Loading Count Badge

struct LoadingCountBadge: View {
    let count: Int
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Pulse Modifier (Animation)

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.5 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Field Schema Editor

struct FieldSchemaEditor: View {
    let schema: FieldSchema
    let catalogId: UUID?
    let onSave: () async -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var schemaDescription: String = ""
    @State private var icon: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            formContent
                .formStyle(.grouped)
                .navigationTitle("Edit Field Schema")
                .toolbar { toolbarContent }
        }
        .frame(minWidth: 500, minHeight: 450)
        .onAppear {
            name = schema.name
            schemaDescription = schema.description ?? ""
            icon = schema.icon ?? ""
        }
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            generalSection
            fieldsSection
            infoSection
        }
    }

    private var generalSection: some View {
        Section("General") {
            TextField("Name", text: $name)
            TextField("Description", text: $schemaDescription)
            TextField("Icon (emoji or SF Symbol)", text: $icon)
        }
    }

    private var fieldsSection: some View {
        Section("Fields (\(schema.fields.count))") {
            ForEach(schema.fields, id: \.fieldId) { field in
                FieldSchemaRowView(field: field)
            }
        }
    }

    private var infoSection: some View {
        Section("Info") {
            LabeledContent("ID") {
                Text(schema.id.uuidString.prefix(8).uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Public", value: schema.isPublic ?? false ? "Yes" : "No")
            if let cats = schema.applicableCategories, !cats.isEmpty {
                LabeledContent("Categories", value: cats.joined(separator: ", "))
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                Task {
                    isSaving = true
                    do {
                        try await SupabaseService.shared.updateFieldSchema(
                            schemaId: schema.id,
                            name: name,
                            description: schemaDescription.isEmpty ? nil : schemaDescription,
                            icon: icon.isEmpty ? nil : icon,
                            fields: schema.fields
                        )
                        await onSave()
                        dismiss()
                    } catch {
                        print("Error saving: \(error)")
                    }
                    isSaving = false
                }
            }
            .disabled(isSaving || name.isEmpty)
        }
    }
}

// MARK: - Field Schema Row View (extracted for type-checker)

private struct FieldSchemaRowView: View {
    let field: FieldDefinition

    var body: some View {
        HStack {
            Image(systemName: field.typeIcon)
                .font(.system(size: 12))
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                labelRow
                typeRow
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var labelRow: some View {
        HStack(spacing: 6) {
            Text(field.displayLabel)
                .font(.subheadline.weight(.medium))
            if field.required ?? false {
                Text("Required")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
    }

    private var typeRow: some View {
        HStack(spacing: 8) {
            Text(field.fieldType)
                .font(.caption)
                .foregroundStyle(.tertiary)
            if let unit = field.unit {
                Text("(\(unit))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Pricing Schema Editor

struct PricingSchemaEditor: View {
    let schema: PricingSchema
    let catalogId: UUID?
    let onSave: () async -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var schemaDescription: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            formContent
                .formStyle(.grouped)
                .navigationTitle("Edit Pricing Schema")
                .toolbar { toolbarContent }
        }
        .frame(minWidth: 450, minHeight: 400)
        .onAppear {
            name = schema.name
            schemaDescription = schema.description ?? ""
        }
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            generalSection
            tiersSection
            infoSection
        }
    }

    private var generalSection: some View {
        Section("General") {
            TextField("Name", text: $name)
            TextField("Description", text: $schemaDescription)
        }
    }

    private var tiersSection: some View {
        Section("Tiers (\(schema.tiers.count))") {
            ForEach(schema.tiers, id: \.tierId) { tier in
                PricingTierRowView(tier: tier)
            }
        }
    }

    private var infoSection: some View {
        Section("Info") {
            LabeledContent("ID") {
                Text(schema.id.uuidString.prefix(8).uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Public", value: schema.isPublic ?? false ? "Yes" : "No")
            if let cats = schema.applicableCategories, !cats.isEmpty {
                LabeledContent("Categories", value: cats.joined(separator: ", "))
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                Task {
                    isSaving = true
                    do {
                        try await SupabaseService.shared.updatePricingSchema(
                            schemaId: schema.id,
                            name: name,
                            description: schemaDescription.isEmpty ? nil : schemaDescription,
                            tiers: schema.tiers
                        )
                        await onSave()
                        dismiss()
                    } catch {
                        print("Error saving: \(error)")
                    }
                    isSaving = false
                }
            }
            .disabled(isSaving || name.isEmpty)
        }
    }
}

// MARK: - Pricing Tier Row View (extracted for type-checker)

private struct PricingTierRowView: View {
    let tier: PricingTier

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tier.displayLabel)
                    .font(.subheadline.weight(.medium))
                Text("Qty: \(tier.quantity, specifier: "%.1f")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(tier.formattedPrice)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.green)
        }
        .padding(.vertical, 2)
    }
}

struct NewFieldSchemaSheet: View {
    let catalogId: UUID?
    let categoryName: String
    let onSave: () async -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("New Field Schema")
                .font(.title2.bold())
            Text("For category: \(categoryName)")
                .foregroundStyle(.secondary)
            Button("Close") { dismiss() }
        }
        .padding(40)
        .frame(minWidth: 400)
    }
}

struct NewPricingSchemaSheet: View {
    let catalogId: UUID?
    let categoryName: String
    let onSave: () async -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("New Pricing Schema")
                .font(.title2.bold())
            Text("For category: \(categoryName)")
                .foregroundStyle(.secondary)
            Button("Close") { dismiss() }
        }
        .padding(40)
        .frame(minWidth: 400)
    }
}
