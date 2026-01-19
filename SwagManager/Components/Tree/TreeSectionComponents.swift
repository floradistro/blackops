import SwiftUI

// MARK: - Tree Section Components
// Extracted from TreeItems.swift following Apple engineering standards
// Contains: TreeItemButtonStyle, TreeSectionHeader
// File size: ~53 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Tree Item Button Style

struct TreeItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? DesignSystem.Colors.surfaceActive : Color.clear
            )
    }
}

// MARK: - Tree Section Header

struct TreeSectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool
    let count: Int

    var body: some View {
        Button {
            withAnimation(DesignSystem.Animation.spring) { isExpanded.toggle() }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(DesignSystem.Animation.fast, value: isExpanded)
                    .frame(width: 12)

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(0.5)

                Text("\(count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}
