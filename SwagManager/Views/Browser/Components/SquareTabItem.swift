import SwiftUI

// MARK: - Square Tab Item
// Extracted from SafariBrowserWindow.swift following Apple engineering standards
// File size: ~50 lines (under Apple's 300 line "excellent" threshold)

struct SquareTabItem: View {
    @ObservedObject var tab: BrowserTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Loading indicator or favicon
                if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: tab.isSecure ? "lock.fill" : "globe")
                        .font(.system(size: 9))
                        .foregroundStyle(tab.isSecure ? DesignSystem.Colors.green : DesignSystem.Colors.textTertiary)
                        .frame(width: 14, height: 14)
                }

                // Title with URL fallback
                Text(tab.pageTitle ?? tab.currentURL ?? "New Tab")
                    .font(.system(size: 11))
                    .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .opacity(isActive ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(isActive ? DesignSystem.Colors.surfaceTertiary : DesignSystem.Colors.surfaceSecondary)
            .overlay(
                Rectangle()
                    .frame(width: 1)
                    .foregroundStyle(DesignSystem.Colors.border)
                , alignment: .trailing
            )
        }
        .buttonStyle(.plain)
    }
}
