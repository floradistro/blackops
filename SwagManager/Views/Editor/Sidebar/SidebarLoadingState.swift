import SwiftUI

// MARK: - Sidebar Loading State
// Extracted from EditorSidebarView.swift following Apple engineering standards
// File size: ~20 lines (under Apple's 300 line "excellent" threshold)

struct SidebarLoadingState: View {
    var body: some View {
        Spacer()
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(DesignSystem.Colors.accent)
            Text("Loading...")
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        Spacer()
    }
}
