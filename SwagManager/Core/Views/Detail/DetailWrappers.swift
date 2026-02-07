import SwiftUI
import SwiftData

// MARK: - Detail Wrappers
// Clean, comprehensive detail views following Apple HIG

// MARK: - Email Detail

struct EmailDetailWrapper: View {
    let emailId: UUID
    @Environment(\.editorStore) private var store

    var body: some View {
        if let email = store.emails.first(where: { $0.id == emailId }) {
            EmailDetailView(email: email)
        } else {
            ContentUnavailableView("Email not found", systemImage: "envelope")
        }
    }
}

struct EmailDetailView: View {
    let email: ResendEmail

    var body: some View {
        SettingsContainer {
            // Header
            SettingsDetailHeader(
                title: email.subject.isEmpty ? "No Subject" : email.subject,
                subtitle: "To: \(email.toEmail)",
                icon: "envelope"
            )

            // Status
            HStack(spacing: 12) {
                SettingsStatCard(label: "Status", value: email.statusLabel, color: email.statusColor)
            }

            // Details
            SettingsGroup(header: "Details") {
                SettingsRow(label: "To", value: email.toEmail)
                SettingsRow(label: "From", value: email.fromEmail)
                    .settingsDivider()
                SettingsBadgeRow(label: "Status", badge: email.statusLabel, badgeColor: email.statusColor)
                    .settingsDivider()
            }

            // Metadata
            SettingsGroup(header: "Metadata") {
                SettingsRow(label: "Email ID", value: String(email.id.uuidString.prefix(8)).uppercased(), mono: true)
            }
        }
        .navigationTitle("Email")
    }
}

// MARK: - Campaign Wrappers

struct EmailCampaignWrapper: View {
    let campaignId: UUID
    @Environment(\.editorStore) private var store

    var body: some View {
        if let campaign = store.emailCampaigns.first(where: { $0.id == campaignId }) {
            EmailCampaignDetailPanel(campaign: campaign)
        } else {
            ContentUnavailableView("Campaign not found", systemImage: "envelope.badge")
        }
    }
}

struct MetaCampaignWrapper: View {
    let campaignId: UUID
    @Environment(\.editorStore) private var store

    var body: some View {
        if let campaign = store.metaCampaigns.first(where: { $0.id == campaignId }) {
            MetaCampaignDetailPanel(campaign: campaign)
        } else {
            ContentUnavailableView("Campaign not found", systemImage: "megaphone")
        }
    }
}

struct MetaIntegrationWrapper: View {
    let integrationId: UUID
    @Environment(\.editorStore) private var store

    var body: some View {
        if let integration = store.metaIntegrations.first(where: { $0.id == integrationId }) {
            MetaIntegrationDetailPanel(integration: integration)
        } else {
            ContentUnavailableView("Integration not found", systemImage: "link")
        }
    }
}

// MARK: - Agent Detail

struct AgentDetailWrapper: View {
    let agentId: UUID
    @Environment(\.editorStore) private var store
    @Binding var selection: SDSidebarItem?

    var body: some View {
        if let agent = store.aiAgents.first(where: { $0.id == agentId }) {
            AgentConfigPanel(agent: agent, selection: $selection)
        } else {
            ContentUnavailableView("Agent not found", systemImage: "cpu")
        }
    }
}

// MARK: - Shared Components

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content()
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var mono: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(mono ? .system(.body, design: .monospaced) : .body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

struct DetailBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PricingRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(bold ? .headline : .body)
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(color)
        }
    }
}

struct StatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
