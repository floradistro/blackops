import SwiftUI

// MARK: - Safari Address Bar
// Extracted from SafariBrowserWindow.swift following Apple engineering standards
// File size: ~45 lines (under Apple's 300 line "excellent" threshold)

struct SafariAddressBar: View {
    @Binding var urlText: String
    let pageTitle: String?
    let isSecure: Bool
    let isLoading: Bool
    @FocusState.Binding var isURLFieldFocused: Bool
    let onSubmit: () -> Void
    let onRefresh: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Security icon
            Image(systemName: isSecure ? "lock.fill" : "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(isSecure ? DesignSystem.Colors.green : DesignSystem.Colors.textTertiary)

            // URL / Title field
            TextField("Search or enter website name", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .focused($isURLFieldFocused)
                .onSubmit(onSubmit)

            // Loading or refresh button
            Button(action: isLoading ? onStop : onRefresh) {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .opacity(isLoading || isURLFieldFocused ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(DesignSystem.Colors.surfaceElevated.opacity(0.8))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isURLFieldFocused ? DesignSystem.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}
