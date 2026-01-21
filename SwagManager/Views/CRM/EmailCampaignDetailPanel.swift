import SwiftUI

struct EmailCampaignDetailPanel: View {
    let campaign: EmailCampaign
    @ObservedObject var store: EditorStore
    @State private var isRefreshing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Stats
                statsSection

                // Campaign Details
                detailsSection

                // Performance Metrics
                if campaign.totalSent > 0 {
                    performanceSection
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    Task {
                        isRefreshing = true
                        await store.refreshEmailCampaign(campaign)
                        isRefreshing = false
                    }
                }) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "envelope.badge")
                    .font(.title)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading) {
                    Text(campaign.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(campaign.subject)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                CampaignStatusBadge(status: campaign.status)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Recipients",
                    value: "\(campaign.totalRecipients)",
                    icon: "person.2",
                    color: .blue
                )

                StatCard(
                    title: "Sent",
                    value: "\(campaign.totalSent)",
                    icon: "paperplane",
                    color: .green
                )

                StatCard(
                    title: "Delivered",
                    value: "\(campaign.totalDelivered)",
                    icon: "checkmark.circle",
                    color: .green
                )

                StatCard(
                    title: "Opened",
                    value: "\(campaign.totalOpened)",
                    subtitle: String(format: "%.1f%%", campaign.openRate),
                    icon: "envelope.open",
                    color: .orange
                )

                StatCard(
                    title: "Clicked",
                    value: "\(campaign.totalClicked)",
                    subtitle: String(format: "%.1f%%", campaign.clickRate),
                    icon: "hand.tap",
                    color: .purple
                )

                StatCard(
                    title: "Bounced",
                    value: "\(campaign.totalBounced)",
                    icon: "exclamationmark.triangle",
                    color: .red
                )
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Campaign Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                CampaignDetailRow(label: "Subject", value: campaign.subject)

                if let previewText = campaign.previewText {
                    CampaignDetailRow(label: "Preview Text", value: previewText)
                }

                if let objective = campaign.objective {
                    CampaignDetailRow(label: "Objective", value: objective.rawValue.capitalized)
                }

                CampaignDetailRow(label: "Channels", value: campaign.channels.joined(separator: ", "))

                CampaignDetailRow(
                    label: "Created",
                    value: campaign.createdAt.formatted(date: .abbreviated, time: .shortened)
                )

                if let sentAt = campaign.sentAt {
                    CampaignDetailRow(
                        label: "Sent At",
                        value: sentAt.formatted(date: .abbreviated, time: .shortened)
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

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.headline)

            VStack(spacing: 8) {
                PerformanceBar(
                    label: "Delivery Rate",
                    value: campaign.deliveryRate,
                    color: .green
                )

                PerformanceBar(
                    label: "Open Rate",
                    value: campaign.openRate,
                    color: .orange
                )

                PerformanceBar(
                    label: "Click Rate",
                    value: campaign.clickRate,
                    color: .purple
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }
}

struct CampaignStatusBadge: View {
    let status: CampaignStatus

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
        case .draft: return .gray
        case .scheduled: return .orange
        case .sending: return .blue
        case .sent: return .green
        case .paused: return .yellow
        case .cancelled: return .red
        case .testing: return .purple
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct CampaignDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.subheadline)

            Spacer()
        }
    }
}

struct PerformanceBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f%%", value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * (value / 100))
                }
            }
            .frame(height: 8)
        }
    }
}
