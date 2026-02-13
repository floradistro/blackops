import SwiftUI

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Spacing.xs + 2)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.xs))
    }
}
