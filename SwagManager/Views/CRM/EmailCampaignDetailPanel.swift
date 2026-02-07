import SwiftUI

// MARK: - Email Campaign Detail Panel
// Minimal monochromatic theme

struct EmailCampaignDetailPanel: View {
    let campaign: EmailCampaign
    @Environment(\.editorStore) private var store
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            // Inline toolbar
            PanelToolbar(
                title: campaign.name,
                icon: "envelope.badge",
                subtitle: campaign.status.rawValue.capitalized
            ) {
                ToolbarButton(
                    icon: isRefreshing ? "ellipsis" : "arrow.clockwise",
                    action: {
                        Task {
                            isRefreshing = true
                            await store.refreshEmailCampaign(campaign)
                            isRefreshing = false
                        }
                    },
                    disabled: isRefreshing
                )
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    headerSection

                    Divider()
                        .padding(.vertical, 8)

                    // Stats
                    SectionHeader(title: "Statistics")
                    statsGrid
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)

                    // Details
                    SectionHeader(title: "Details")
                    detailsSection

                    // Performance
                    if campaign.totalSent > 0 {
                        Divider()
                            .padding(.vertical, 8)
                        SectionHeader(title: "Performance")
                        performanceSection
                    }

                    Spacer(minLength: 20)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 48, height: 48)
                Image(systemName: "envelope.badge")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.primary.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(campaign.subject)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.9))
                    .lineLimit(2)

                if let previewText = campaign.previewText {
                    Text(previewText)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status badge - sleek minimal
            CampaignStatusBadge(status: campaign.status)
        }
        .padding(20)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 1) {
            MinimalStatCell(title: "Recipients", value: "\(campaign.totalRecipients)", icon: "person.2")
            MinimalStatCell(title: "Sent", value: "\(campaign.totalSent)", icon: "paperplane")
            MinimalStatCell(title: "Delivered", value: "\(campaign.totalDelivered)", icon: "checkmark.circle")
            MinimalStatCell(title: "Opened", value: "\(campaign.totalOpened)", subtitle: String(format: "%.1f%%", campaign.openRate))
            MinimalStatCell(title: "Clicked", value: "\(campaign.totalClicked)", subtitle: String(format: "%.1f%%", campaign.clickRate))
            MinimalStatCell(title: "Bounced", value: "\(campaign.totalBounced)", icon: "exclamationmark.triangle")
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: 6) {
            if let objective = campaign.objective {
                InfoRow(label: "Objective", value: objective.rawValue.capitalized)
            }

            InfoRow(label: "Channels", value: campaign.channels.joined(separator: ", "))
            InfoRow(label: "Created", value: campaign.createdAt.formatted(date: .abbreviated, time: .shortened))

            if let sentAt = campaign.sentAt {
                InfoRow(label: "Sent At", value: sentAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Performance Section

    private var performanceSection: some View {
        VStack(spacing: 12) {
            MinimalPerformanceBar(label: "Delivery Rate", value: campaign.deliveryRate)
            MinimalPerformanceBar(label: "Open Rate", value: campaign.openRate)
            MinimalPerformanceBar(label: "Click Rate", value: campaign.clickRate)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Supporting Views

private struct MinimalStatCell: View {
    let title: String
    let value: String
    var icon: String? = nil
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.8))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.4))
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.primary.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.03))
    }
}

struct CampaignStatusBadge: View {
    let status: CampaignStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.primary.opacity(statusOpacity))
                .frame(width: 6, height: 6)
            Text(status.rawValue.capitalized)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
    }

    private var statusOpacity: Double {
        switch status {
        case .draft: return 0.3
        case .scheduled: return 0.5
        case .sending: return 0.6
        case .sent: return 0.7
        case .paused: return 0.4
        case .cancelled: return 0.3
        case .testing: return 0.5
        }
    }
}

struct CampaignDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.8))

            Spacer()
        }
    }
}

private struct MinimalPerformanceBar: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.5))
                Spacer()
                Text(String(format: "%.1f%%", value))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.8))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.06))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.25))
                        .frame(width: geometry.size.width * (value / 100))
                }
            }
            .frame(height: 4)
        }
    }
}

// Legacy support
struct PerformanceBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.5))
                Spacer()
                Text(String(format: "%.1f%%", value))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.8))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.06))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.25))
                        .frame(width: geometry.size.width * (value / 100))
                }
            }
            .frame(height: 4)
        }
    }
}
