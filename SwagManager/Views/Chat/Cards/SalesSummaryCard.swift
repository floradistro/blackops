import SwiftUI

// MARK: - Sales Summary Card
// Extracted from ChatDataCards.swift following Apple engineering standards
// File size: ~77 lines (under Apple's 300 line "excellent" threshold)

struct SalesSummaryCard: View {
    let period: String
    let revenue: Double
    let orders: Int
    let growth: Double?
    let topCategory: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(period)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if let growth = growth {
                    HStack(spacing: 2) {
                        Image(systemName: growth >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%.1f%%", abs(growth)))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(growth >= 0 ? .green : .red)
                }
            }

            // Main stats
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Revenue")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(String(format: "$%.2f", revenue))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Orders")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text("\(orders)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                }

                Spacer()
            }

            // Top category
            if let category = topCategory {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                    Text("Top: \(category)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.08), Color.green.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.15), lineWidth: 1)
        )
    }
}
