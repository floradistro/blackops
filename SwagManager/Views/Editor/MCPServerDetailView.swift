import SwiftUI

// MARK: - MCP Server Detail View
// Following Apple engineering standards

struct MCPServerDetailView: View {
    let server: MCPServer
    @ObservedObject var store: EditorStore
    @State private var selectedTab: MCPTab = .details
    @State private var showEditor = false

    enum MCPTab: String, CaseIterable {
        case details = "Details"
        case test = "Test"
        case monitor = "Monitor"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            tabBar

            Divider()

            // Content based on selected tab
            switch selectedTab {
            case .details:
                detailsTab
            case .test:
                MCPTestView(server: server)
            case .monitor:
                MCPMonitoringView()
            }
        }
        .onAppear {
            NSLog("[MCPServerDetailView] Loaded server: \(server.name)")
        }
        .sheet(isPresented: $showEditor) {
            MCPEditorView(server: server) {
                Task { await store.loadMCPServers() }
            }
            .frame(minWidth: 700, minHeight: 600)
        }
    }

    @ViewBuilder
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MCPTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            selectedTab == tab ? VisualEffectBackground(material: .sidebar) : nil
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button("Edit") {
                showEditor = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    @ViewBuilder
    private var detailsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header
                headerSection

                // Server Info
                serverInfoSection

                // Definition
                definitionSection

                // Input Schema
                if let schema = server.definition.inputSchema {
                    inputSchemaSection(schema)
                }

                // Properties
                if let properties = server.definition.inputSchema?.properties, !properties.isEmpty {
                    propertiesSection(properties, required: server.definition.inputSchema?.required ?? [])
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground(material: .underWindowBackground))
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    VisualEffectBackground(material: .sidebar)
                    Color.indigo.opacity(0.1)
                    Image(systemName: "server.rack")
                        .font(.system(size: 32))
                        .foregroundStyle(.indigo)
                }
                .frame(width: 56, height: 56)
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 6) {
                    Text(server.name)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        StatusBadge(text: server.category, color: .orange)
                        if let toolMode = server.toolMode {
                            StatusBadge(text: toolMode, color: .blue)
                        }
                        if server.isActive ?? true {
                            StatusBadge(text: "Active", color: .green)
                        }
                        if server.isReadOnly ?? false {
                            StatusBadge(text: "Read-Only", color: .secondary)
                        }
                    }
                }

                Spacer()
            }

            if let description = server.description {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(8)
    }

    // MARK: - Server Info Section

    @ViewBuilder
    private var serverInfoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionTitle("Server Information")

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if let version = server.version {
                    MCPInfoRow(label: "Version", value: "v\(version)")
                }
                if let type = server.definition.type {
                    MCPInfoRow(label: "Type", value: type)
                }

                if let rpc = server.rpcFunction {
                    MCPInfoRow(label: "RPC Function", value: rpc)
                }

                if let edge = server.edgeFunction {
                    MCPInfoRow(label: "Edge Function", value: edge)
                }

                MCPInfoRow(label: "Requires User ID", value: (server.requiresUserId ?? false) ? "Yes" : "No")
                MCPInfoRow(label: "Requires Store ID", value: (server.requiresStoreId ?? false) ? "Yes" : "No")
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(8)
    }

    // MARK: - Definition Section

    @ViewBuilder
    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionTitle("Definition")

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if let name = server.definition.name {
                    MCPInfoRow(label: "Name", value: name)
                }
                if let description = server.definition.description {
                    MCPInfoRow(label: "Description", value: description)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(8)
    }

    // MARK: - Input Schema Section

    @ViewBuilder
    private func inputSchemaSection(_ schema: InputSchema) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionTitle("Input Schema")

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                MCPInfoRow(label: "Type", value: schema.type)

                if let required = schema.required, !required.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Required Fields:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        ForEach(required, id: \.self) { field in
                            Text("• \(field)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(8)
    }

    // MARK: - Properties Section

    @ViewBuilder
    private func propertiesSection(_ properties: [String: PropertyDefinition], required: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionTitle("Properties")

            ForEach(Array(properties.keys.sorted()), id: \.self) { key in
                if let property = properties[key] {
                    propertyCard(key: key, property: property, isRequired: required.contains(key))
                }
            }
        }
    }

    @ViewBuilder
    private func propertyCard(key: String, property: PropertyDefinition, isRequired: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(key)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)

                if isRequired {
                    Text("required")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .cornerRadius(4)
                }

                Spacer()

                Text(property.type)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let description = property.description {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            if let defaultValue = property.default {
                HStack(spacing: 4) {
                    Text("Default:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(defaultValue.stringValue)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            if let enumValues = property.enum {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Options:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)

                    ForEach(enumValues, id: \.self) { value in
                        Text("• \(value)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(6)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
    }
}

// MARK: - MCP Info Row

struct MCPInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            Spacer()
        }
    }
}

// MARK: - Status Badge

