import SwiftUI

// MARK: - Meta Campaign Detail Panel
// Minimal, monochromatic theme

struct MetaCampaignDetailPanel: View {
    let campaign: MetaCampaign
    @Environment(\.editorStore) private var store
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            // Inline toolbar
            PanelToolbar(
                title: campaign.name,
                icon: "megaphone",
                subtitle: campaign.status
            ) {
                ToolbarButton(
                    icon: isRefreshing ? "ellipsis" : "arrow.clockwise",
                    action: {
                        Task {
                            isRefreshing = true
                            await store.refreshMetaCampaign(campaign)
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
                    SectionHeader(title: "Performance")
                    statsGrid
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)

                    // Budget
                    SectionHeader(title: "Budget")
                    budgetSection

                    Divider()
                        .padding(.vertical, 8)

                    // Details
                    SectionHeader(title: "Details")
                    detailsSection

                    // Performance Metrics
                    if campaign.impressions > 0 {
                        Divider()
                            .padding(.vertical, 8)
                        SectionHeader(title: "Metrics")
                        metricsSection
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
                Image(systemName: "megaphone")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.primary.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(campaign.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.9))

                if let objective = campaign.objective {
                    Text(objective)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.primary.opacity(0.5))
                }

                if let effectiveStatus = campaign.effectiveStatus {
                    Text("Effective: \(effectiveStatus)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
            }

            Spacer()

            // Status badge
            if let status = campaign.status {
                MinimalStatusBadge(status: status)
            }
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
            MinimalMetricCell(title: "Impressions", value: formatNumber(campaign.impressions))
            MinimalMetricCell(title: "Reach", value: formatNumber(campaign.reach))
            MinimalMetricCell(title: "Clicks", value: formatNumber(campaign.clicks), subtitle: String(format: "%.2f%% CTR", campaign.clickRate))
            MinimalMetricCell(title: "Spend", value: formatCurrency(campaign.spend))
            MinimalMetricCell(title: "CPC", value: formatCurrency(campaign.cpc ?? 0))
            MinimalMetricCell(title: "CPM", value: formatCurrency(campaign.cpm ?? 0))
        }
    }

    // MARK: - Budget

    private var budgetSection: some View {
        VStack(spacing: 6) {
            if let dailyBudget = campaign.dailyBudget {
                MinimalBudgetRow(label: "Daily Budget", value: formatCurrency(dailyBudget))
            }
            if let lifetimeBudget = campaign.lifetimeBudget {
                MinimalBudgetRow(label: "Lifetime Budget", value: formatCurrency(lifetimeBudget))
            }
            if let budgetRemaining = campaign.budgetRemaining {
                MinimalBudgetRow(label: "Remaining", value: formatCurrency(budgetRemaining))
            }
            MinimalBudgetRow(label: "Total Spend", value: formatCurrency(campaign.spend))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(spacing: 6) {
            InfoRow(label: "Campaign ID", value: String(campaign.metaCampaignId.prefix(16)) + "...")
            InfoRow(label: "Ad Account", value: campaign.metaAccountId)

            if let objective = campaign.objective {
                InfoRow(label: "Objective", value: objective)
            }

            if let startTime = campaign.startTime {
                InfoRow(label: "Start", value: startTime.formatted(date: .abbreviated, time: .shortened))
            }

            if let stopTime = campaign.stopTime {
                InfoRow(label: "Stop", value: stopTime.formatted(date: .abbreviated, time: .shortened))
            }

            if let lastSynced = campaign.lastSyncedAt {
                InfoRow(label: "Synced", value: lastSynced.formatted(date: .abbreviated, time: .shortened))
            }

            InfoRow(label: "Created", value: campaign.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(spacing: 12) {
            if campaign.conversions > 0 {
                MinimalMetricRow(
                    label: "Conversions",
                    value: "\(campaign.conversions)",
                    subtitle: "Value: \(formatCurrency(campaign.conversionValue))"
                )
            }

            if let roas = campaign.roas, roas > 0 {
                MinimalMetricRow(
                    label: "ROAS",
                    value: String(format: "%.2fx", NSDecimalNumber(decimal: roas).doubleValue),
                    subtitle: "Return on Ad Spend"
                )
            }

            if let ctr = campaign.ctr, ctr > 0 {
                MinimalMetricRow(
                    label: "CTR",
                    value: String(format: "%.2f%%", NSDecimalNumber(decimal: ctr).doubleValue),
                    subtitle: "Click-Through Rate"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        }
        return "\(number)"
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

// MARK: - Supporting Views

private struct MinimalStatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.primary.opacity(statusOpacity))
                .frame(width: 6, height: 6)
            Text(status.capitalized)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
    }

    private var statusOpacity: Double {
        switch status.uppercased() {
        case "ACTIVE": return 0.7
        case "PAUSED": return 0.4
        default: return 0.3
        }
    }
}

private struct MinimalMetricCell: View {
    let title: String
    let value: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 4) {
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

private struct MinimalBudgetRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.8))
        }
    }
}

private struct MinimalMetricRow: View {
    let label: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.5))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.3))
            }
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.8))
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
    }
}

// MARK: - Legacy Support

struct MetaStatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.primary.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(status.capitalized)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
    }
}

struct BudgetRow: View {
    let label: String
    let amount: Decimal

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.5))
            Spacer()
            Text(formatCurrency(amount))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.8))
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

struct MetricCard: View {
    let label: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.4))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.8))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.4))
        }
    }
}
