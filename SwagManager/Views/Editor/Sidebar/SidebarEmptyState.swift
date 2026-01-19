import SwiftUI

// MARK: - Sidebar Empty State
// Extracted from EditorSidebarView.swift following Apple engineering standards
// File size: ~35 lines (under Apple's 300 line "excellent" threshold)

struct SidebarEmptyState: View {
    let onCreateStore: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "building.2")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textQuaternary)

            Text("No Store Selected")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Button {
                onCreateStore()
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "plus")
                    Text("Create Store")
                }
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
