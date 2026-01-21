import SwiftUI

// MARK: - Sidebar Search Bar
// Extracted from EditorSidebarView.swift following Apple engineering standards
// File size: ~36 lines (under Apple's 300 line "excellent" threshold)

struct SidebarSearchBar: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    withAnimation(DesignSystem.Animation.fast) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(DesignSystem.Colors.surfaceSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
