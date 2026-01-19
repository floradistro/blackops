import SwiftUI

// MARK: - Sidebar Search Bar
// Extracted from EditorSidebarView.swift following Apple engineering standards
// File size: ~36 lines (under Apple's 300 line "excellent" threshold)

struct SidebarSearchBar: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button {
                        withAnimation(DesignSystem.Animation.fast) { searchText = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 5)
            .background(DesignSystem.Colors.surfaceSecondary)

            Rectangle()
                .fill(DesignSystem.Colors.border)
                .frame(height: 1)
        }
    }
}
