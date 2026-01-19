import SwiftUI

// MARK: - Chart Placeholder Card
// Extracted from ChatDataCards.swift following Apple engineering standards
// File size: ~45 lines (under Apple's 300 line "excellent" threshold)

struct ChartPlaceholderCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            // Placeholder bars
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let height = CGFloat.random(in: 20...60)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: 24, height: height)
                }
            }
            .frame(height: 60)

            // Labels
            HStack {
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .frame(width: 24)
                }
            }
        }
        .padding(14)
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 1)
        )
    }
}
