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

            // Content based on selected tab
            TabView(selection: $selectedTab) {
                detailsTab.tag(MCPTab.details)
                MCPTestView(server: server).tag(MCPTab.test)
                MCPMonitoringView().tag(MCPTab.monitor)
            }
            .tabViewStyle(.automatic)
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: { showEditor = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                    Text("Edit")
                }
                .font(.system(size: 12))
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(Color.primary.opacity(0.03))
    }

    @ViewBuilder
    private var detailsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Header
                headerSection

                Divider()

                // Server Info
                serverInfoSection

                Divider()

                // Definition
                definitionSection

                Divider()

                // Input Schema
                if let schema = server.definition.inputSchema {
                    inputSchemaSection(schema)
                    Divider()
                }

                // Properties
                if let properties = server.definition.inputSchema?.properties, !properties.isEmpty {
                    propertiesSection(properties, required: server.definition.inputSchema?.required ?? [])
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "server.rack")
                    .font(.system(size: 32))
                    .foregroundStyle(.indigo)
                    .frame(width: 44, height: 44)
                    .background(Color.indigo.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(.system(size: 20, weight: .semibold))

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
            }

            if let description = server.description {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Server Info Section

    @ViewBuilder
    private var serverInfoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionTitle("Server Information")

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

    // MARK: - Definition Section

    @ViewBuilder
    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionTitle("Definition")

            if let name = server.definition.name {
                MCPInfoRow(label: "Name", value: name)
            }
            if let description = server.definition.description {
                MCPInfoRow(label: "Description", value: description)
            }
        }
    }

    // MARK: - Input Schema Section

    @ViewBuilder
    private func inputSchemaSection(_ schema: InputSchema) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionTitle("Input Schema")

            MCPInfoRow(label: "Type", value: schema.type)

            if let required = schema.required, !required.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Required Fields:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    ForEach(required, id: \.self) { field in
                        Text("• \(field)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(key)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)

                if isRequired {
                    Text("required")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }

                Spacer()

                Text(property.type)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let description = property.description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if let defaultValue = property.default {
                Text("Default: \(defaultValue.stringValue)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            if let enumValues = property.enum {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Options:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)

                    ForEach(enumValues, id: \.self) { value in
                        Text("• \(value)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(Color.primary.opacity(0.05))
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

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}
