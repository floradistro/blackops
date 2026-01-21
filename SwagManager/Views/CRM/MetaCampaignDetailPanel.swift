import SwiftUI

struct MetaCampaignDetailPanel: View {
    let campaign: MetaCampaign
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

                // Budget & Spending
                budgetSection

                // Performance Metrics
                if campaign.impressions > 0 {
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
                        await store.refreshMetaCampaign(campaign)
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
                Image(systemName: "megaphone")
                    .font(.title)
                    .foregroundStyle(.pink)

                VStack(alignment: .leading) {
                    Text(campaign.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let objective = campaign.objective {
                        Text(objective)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let status = campaign.status {
                    MetaStatusBadge(status: status)
                }
            }

            if let effectiveStatus = campaign.effectiveStatus {
                Text("Effective Status: \(effectiveStatus)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            Text("Performance")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Impressions",
                    value: formatNumber(campaign.impressions),
                    icon: "eye",
                    color: .blue
                )

                StatCard(
                    title: "Reach",
                    value: formatNumber(campaign.reach),
                    icon: "person.2",
                    color: .purple
                )

                StatCard(
                    title: "Clicks",
                    value: formatNumber(campaign.clicks),
                    subtitle: String(format: "%.2f%% CTR", campaign.clickRate),
                    icon: "hand.tap",
                    color: .orange
                )

                StatCard(
                    title: "Spend",
                    value: formatCurrency(campaign.spend),
                    icon: "dollarsign.circle",
                    color: .green
                )

                StatCard(
                    title: "CPC",
                    value: formatCurrency(campaign.cpc ?? 0),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .indigo
                )

                StatCard(
                    title: "CPM",
                    value: formatCurrency(campaign.cpm ?? 0),
                    icon: "chart.bar",
                    color: .cyan
                )
            }
        }
    }

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget & Spending")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if let dailyBudget = campaign.dailyBudget {
                    BudgetRow(label: "Daily Budget", amount: dailyBudget)
                }

                if let lifetimeBudget = campaign.lifetimeBudget {
                    BudgetRow(label: "Lifetime Budget", amount: lifetimeBudget)
                }

                if let budgetRemaining = campaign.budgetRemaining {
                    BudgetRow(label: "Budget Remaining", amount: budgetRemaining)
                }

                BudgetRow(label: "Total Spend", amount: campaign.spend)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Campaign Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                CampaignDetailRow(label: "Meta Campaign ID", value: campaign.metaCampaignId)
                CampaignDetailRow(label: "Ad Account", value: campaign.metaAccountId)

                if let objective = campaign.objective {
                    CampaignDetailRow(label: "Objective", value: objective)
                }

                if let startTime = campaign.startTime {
                    CampaignDetailRow(
                        label: "Start Time",
                        value: startTime.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                if let stopTime = campaign.stopTime {
                    CampaignDetailRow(
                        label: "Stop Time",
                        value: stopTime.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                if let lastSynced = campaign.lastSyncedAt {
                    CampaignDetailRow(
                        label: "Last Synced",
                        value: lastSynced.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                CampaignDetailRow(
                    label: "Created",
                    value: campaign.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
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
            Text("Performance Metrics")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                if campaign.conversions > 0 {
                    MetricCard(
                        label: "Conversions",
                        value: "\(campaign.conversions)",
                        subtitle: "Value: \(formatCurrency(campaign.conversionValue))"
                    )
                }

                if let roas = campaign.roas, roas > 0 {
                    MetricCard(
                        label: "ROAS",
                        value: String(format: "%.2fx", NSDecimalNumber(decimal: roas).doubleValue),
                        subtitle: "Return on Ad Spend"
                    )
                }

                if let ctr = campaign.ctr, ctr > 0 {
                    MetricCard(
                        label: "CTR",
                        value: String(format: "%.2f%%", NSDecimalNumber(decimal: ctr).doubleValue),
                        subtitle: "Click-Through Rate"
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

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$\(amount)"
    }
}

struct MetaStatusBadge: View {
    let status: String

    var body: some View {
        Text(status)
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
        switch status.uppercased() {
        case "ACTIVE": return .green
        case "PAUSED": return .orange
        case "DRAFT": return .gray
        case "ARCHIVED": return .secondary
        default: return .blue
        }
    }
}

struct BudgetRow: View {
    let label: String
    let amount: Decimal

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(formatCurrency(amount))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$\(amount)"
    }
}

struct MetricCard: View {
    let label: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
