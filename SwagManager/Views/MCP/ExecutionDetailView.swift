import SwiftUI

// MARK: - Execution Detail View
// Full request/response inspector for debugging

struct ExecutionDetailView: View {
    let execution: ExecutionDetail
    @State private var selectedTab: Tab = .overview
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case request = "Request"
        case response = "Response"
        case timeline = "Timeline"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Tab Bar
            tabBar

            Divider()

            // Content
            ScrollView {
                Group {
                    switch selectedTab {
                    case .overview:
                        overviewSection
                    case .request:
                        requestSection
                    case .response:
                        responseSection
                    case .timeline:
                        timelineSection
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(VisualEffectBackground(material: .underWindowBackground))
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Image(systemName: execution.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(execution.success ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(execution.toolName)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(execution.createdAt, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(execution.createdAt, style: .time)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if let duration = execution.executionTimeMs {
                        Text("•")
                            .foregroundStyle(.secondary)

                        Text("\(duration)ms")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button("Replay") {
                // TODO: Pre-fill test form with these parameters
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Copy as cURL") {
                copyAsCurl()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(DesignSystem.Spacing.md)
    }

    // MARK: - Tab Bar

    @ViewBuilder
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            selectedTab == tab ? VisualEffectBackground(material: .sidebar) : nil
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 4)
    }

    // MARK: - Overview

    @ViewBuilder
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Status
            statusCard

            // Metadata
            metadataCard

            // Error (if any)
            if !execution.success, let error = execution.errorMessage {
                errorCard(error)
            }
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Execution Status")
                .font(.system(size: 14, weight: .semibold))

            HStack(spacing: DesignSystem.Spacing.lg) {
                StatItem(
                    label: "Status",
                    value: execution.success ? "Success" : "Failed",
                    color: execution.success ? .green : .red
                )

                if let duration = execution.executionTimeMs {
                    StatItem(
                        label: "Duration",
                        value: "\(duration)ms",
                        color: duration < 1000 ? .green : duration < 3000 ? .orange : .red
                    )
                }

                if let code = execution.errorCode {
                    StatItem(label: "Error Code", value: code, color: .red)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(6)
    }

    @ViewBuilder
    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Metadata")
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                MetadataRow(label: "Execution ID", value: execution.id.uuidString)
                MetadataRow(label: "Tool Name", value: execution.toolName)
                if let userId = execution.userId {
                    MetadataRow(label: "User ID", value: userId.uuidString)
                }
                if let storeId = execution.storeId {
                    MetadataRow(label: "Store ID", value: storeId.uuidString)
                }
                MetadataRow(label: "Timestamp", value: ISO8601DateFormatter().string(from: execution.createdAt))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func errorCard(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Error Details", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.red)

            Text(error)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Spacing.md)
        .background(VisualEffectBackground(material: .sidebar))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(6)
    }

    // MARK: - Request

    @ViewBuilder
    private var requestSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Request Details")
                .font(.system(size: 16, weight: .semibold))

            if execution.request != nil {
                CodeBlock(title: "Parameters", code: execution.prettyRequest)
            } else {
                Text("No request data available")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Response

    @ViewBuilder
    private var responseSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Response Details")
                .font(.system(size: 16, weight: .semibold))

            if execution.response != nil {
                CodeBlock(title: "Response Body", code: execution.prettyResponse)
            } else {
                Text("No response data available")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Timeline

    @ViewBuilder
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Execution Timeline")
                .font(.system(size: 16, weight: .semibold))

            // TODO: Add timeline visualization
            Text("Timeline visualization coming soon...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func copyAsCurl() {
        guard let requestString = execution.request else { return }

        // Build a simple curl command with the request JSON
        var curl = "curl -X POST"
        curl += " 'https://uaednwpxursknmwdeejn.supabase.co/functions/v1/tools-gateway'"
        curl += " \\\n  -H 'Content-Type: application/json'"
        curl += " \\\n  -d '\(requestString)'"

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(curl, forType: .string)
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CodeBlock: View {
    let title: String
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            ScrollView([.horizontal, .vertical]) {
                Text(code)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSystem.Spacing.sm)
            }
            .frame(maxHeight: 400)
            .background(Color.black.opacity(0.05))
            .cornerRadius(4)
        }
        .padding(DesignSystem.Spacing.md)
        .background(VisualEffectBackground(material: .sidebar))
        .cornerRadius(6)
    }
}
