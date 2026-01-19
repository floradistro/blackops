import SwiftUI

// MARK: - Quick Stats Row
// Extracted from ChatDataCards.swift following Apple engineering standards
// File size: ~32 lines (under Apple's 300 line "excellent" threshold)

struct QuickStatsRow: View {
    let stats: [(label: String, value: String, icon: String, color: Color)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(stats.indices, id: \.self) { index in
                let stat = stats[index]
                HStack(spacing: 6) {
                    Image(systemName: stat.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(stat.color)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(stat.value)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        Text(stat.label)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(stat.color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if index < stats.count - 1 {
                    Spacer()
                }
            }
        }
    }
}
