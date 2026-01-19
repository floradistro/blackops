import SwiftUI

// MARK: - Empty Browser View
// Extracted from SafariBrowserWindow.swift following Apple engineering standards
// File size: ~28 lines (under Apple's 300 line "excellent" threshold)

struct EmptyBrowserView: View {
    let onNewTab: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "safari")
                .font(.system(size: 64))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("No tabs open")
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Button(action: onNewTab) {
                Text("New Tab")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(DesignSystem.Colors.accent)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.surfacePrimary)
    }
}
