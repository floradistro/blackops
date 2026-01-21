import SwiftUI

struct MetaIntegrationDetailPanel: View {
    let integration: MetaIntegration
    @ObservedObject var store: EditorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Integration Details
                detailsSection

                // Connected Accounts
                accountsSection

                // Status Information
                statusSection
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link.badge.plus")
                    .font(.title)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading) {
                    Text(integration.businessName ?? "Meta Integration")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("App ID: \(integration.appId)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                IntegrationStatusBadge(status: integration.status)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Integration Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                CampaignDetailRow(label: "App ID", value: integration.appId)

                if let businessId = integration.businessId {
                    CampaignDetailRow(label: "Business ID", value: businessId)
                }

                if let businessName = integration.businessName {
                    CampaignDetailRow(label: "Business Name", value: businessName)
                }

                CampaignDetailRow(
                    label: "Created",
                    value: integration.createdAt.formatted(date: .abbreviated, time: .shortened)
                )

                CampaignDetailRow(
                    label: "Updated",
                    value: integration.updatedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Accounts")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if let adAccountId = integration.adAccountId {
                    AccountRow(
                        icon: "megaphone.fill",
                        label: "Ad Account",
                        value: adAccountId,
                        color: .pink
                    )
                }

                if let pixelId = integration.pixelId {
                    AccountRow(
                        icon: "target",
                        label: "Pixel",
                        value: pixelId,
                        color: .blue
                    )
                }

                if let pageId = integration.pageId {
                    AccountRow(
                        icon: "doc.text",
                        label: "Page",
                        value: pageId,
                        color: .purple
                    )
                }

                if let instagramBusinessId = integration.instagramBusinessId {
                    AccountRow(
                        icon: "camera",
                        label: "Instagram Business",
                        value: instagramBusinessId,
                        color: .orange
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Connection Status")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(integration.status.rawValue.capitalized)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor)
                    }

                    Spacer()

                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                }

                if let lastError = integration.lastError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Error")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(lastError)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    private var statusColor: Color {
        switch integration.status {
        case .active: return .green
        case .disconnected: return .gray
        case .expired: return .orange
        case .error: return .red
        }
    }
}

struct IntegrationStatusBadge: View {
    let status: MetaIntegrationStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(statusColor)
            )
    }

    var statusColor: Color {
        switch status {
        case .active: return .green
        case .disconnected: return .gray
        case .expired: return .orange
        case .error: return .red
        }
    }
}

struct AccountRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
    }
}
