import SwiftUI

struct EmailCampaignDetailPanel: View {
    let campaign: EmailCampaign
    @ObservedObject var store: EditorStore
    @State private var isRefreshing = false

    var body: some View {
        GlassPanel(
            title: campaign.name,
            showHeader: true,
            headerActions: {
                AnyView(
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        CampaignStatusBadge(status: campaign.status)

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
                                    .font(.system(size: DesignSystem.IconSize.medium))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                )
            }
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                // Subject header
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
        }
    }

    private var headerSection: some View {
        GlassSection(
            title: "Campaign Subject",
            subtitle: campaign.subject,
            icon: "envelope.badge"
        ) {
            EmptyView()
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Statistics")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                GlassStatCard(
                    title: "Recipients",
                    value: "\(campaign.totalRecipients)",
                    icon: "person.2",
                    color: DesignSystem.Colors.blue
                )

                GlassStatCard(
                    title: "Sent",
                    value: "\(campaign.totalSent)",
                    icon: "paperplane",
                    color: DesignSystem.Colors.green
                )

                GlassStatCard(
                    title: "Delivered",
                    value: "\(campaign.totalDelivered)",
                    icon: "checkmark.circle",
                    color: DesignSystem.Colors.green
                )

                GlassStatCard(
                    title: "Opened",
                    value: "\(campaign.totalOpened)",
                    icon: "envelope.open",
                    subtitle: String(format: "%.1f%%", campaign.openRate),
                    trend: .up(String(format: "%.1f%%", campaign.openRate)),
                    color: DesignSystem.Colors.orange
                )

                GlassStatCard(
                    title: "Clicked",
                    value: "\(campaign.totalClicked)",
                    icon: "hand.tap",
                    subtitle: String(format: "%.1f%%", campaign.clickRate),
                    trend: .up(String(format: "%.1f%%", campaign.clickRate)),
                    color: DesignSystem.Colors.purple
                )

                GlassStatCard(
                    title: "Bounced",
                    value: "\(campaign.totalBounced)",
                    icon: "exclamationmark.triangle",
                    color: DesignSystem.Colors.error
                )
            }
        }
    }

    private var detailsSection: some View {
        GlassSection(
            title: "Campaign Details",
            icon: "info.circle"
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
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
        }
    }

    private var performanceSection: some View {
        GlassSection(
            title: "Performance Metrics",
            icon: "chart.bar"
        ) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                PerformanceBar(
                    label: "Delivery Rate",
                    value: campaign.deliveryRate,
                    color: DesignSystem.Colors.green
                )

                PerformanceBar(
                    label: "Open Rate",
                    value: campaign.openRate,
                    color: DesignSystem.Colors.orange
                )

                PerformanceBar(
                    label: "Click Rate",
                    value: campaign.clickRate,
                    color: DesignSystem.Colors.purple
                )
            }
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

// MARK: - Legacy StatCard (DEPRECATED - Use GlassStatCard)
// Kept for backward compatibility, will be removed in future version

struct CampaignDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()
        }
    }
}

struct PerformanceBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(label)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Text(String(format: "%.1f%%", value))
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.xs)
                        .fill(DesignSystem.Colors.surfaceSecondary)

                    RoundedRectangle(cornerRadius: DesignSystem.Radius.xs)
                        .fill(color)
                        .frame(width: geometry.size.width * (value / 100))
                }
            }
            .frame(height: 8)
        }
    }
}
