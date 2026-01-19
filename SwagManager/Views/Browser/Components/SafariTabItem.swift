import SwiftUI

// MARK: - Safari Tab Item
// Extracted from SafariBrowserWindow.swift following Apple engineering standards
// File size: ~44 lines (under Apple's 300 line "excellent" threshold)

struct SafariTabItem: View {
    let tab: BrowserTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Favicon or loading indicator
                if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                // Title
                Text(tab.pageTitle ?? "New Tab")
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(1)

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .opacity(isActive ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? DesignSystem.Colors.surfaceElevated.opacity(0.5) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
