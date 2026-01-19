import SwiftUI

// MARK: - Filter Chip
// Extracted from TreeItems.swift following Apple engineering standards
// File size: ~18 lines (under Apple's 300 line "excellent" threshold)

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.caption1)
                .padding(.horizontal, DesignSystem.Spacing.xs)
                .padding(.vertical, 2)
                .background(isSelected ? Color.accentColor : DesignSystem.Colors.surfaceElevated)
                .foregroundStyle(isSelected ? .white : .secondary)
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
    }
}
