import SwiftUI

// MARK: - Order Data Card
// Extracted from ChatDataCards.swift following Apple engineering standards
// File size: ~90 lines (under Apple's 300 line "excellent" threshold)

struct OrderDataCard: View {
    let orderNumber: String
    let status: String
    let total: Double
    let itemCount: Int
    let date: Date

    var statusColor: Color {
        switch status.lowercased() {
        case "completed": return .green
        case "processing": return .blue
        case "pending": return .orange
        case "cancelled": return .red
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "bag.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(statusColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("#\(orderNumber)")
                        .font(.system(size: 13, weight: .semibold))

                    Text(status.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.15))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    Text(String(format: "$%.2f", total))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Text(formatDate(date))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Quick actions
            Button {
                // View order
            } label: {
                Text("View")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}
