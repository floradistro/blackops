import SwiftUI

// MARK: - Tree Section Components
// Extracted from TreeItems.swift following Apple engineering standards
// Contains: TreeItemButtonStyle, TreeSectionHeader, LoadingCountBadge
// File size: ~100 lines (under Apple's 300 line "excellent" threshold)

// MARK: - Tree Item Button Style

struct TreeItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? DesignSystem.Colors.surfaceActive : Color.clear
            )
    }
}

// MARK: - Loading Count Badge
// Native iOS spinner for sidebar section counts

struct LoadingCountBadge: View {
    let count: Int
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                // Native iOS spinner (hide count while loading)
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            } else {
                // Count (only show when not loading)
                Text("\(count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Tree Section Header

struct TreeSectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool
    let count: Int
    let isLoading: Bool
    let realtimeConnected: Bool

    init(title: String, isExpanded: Binding<Bool>, count: Int, isLoading: Bool = false, realtimeConnected: Bool = false) {
        self.title = title
        self._isExpanded = isExpanded
        self.count = count
        self.isLoading = isLoading
        self.realtimeConnected = realtimeConnected
    }

    var body: some View {
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

            // Realtime connection indicator
            if realtimeConnected {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }

            LoadingCountBadge(
                count: count,
                isLoading: isLoading
            )

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(DesignSystem.Animation.spring) {
                isExpanded.toggle()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: realtimeConnected)
    }
}
