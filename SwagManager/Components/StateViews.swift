import SwiftUI

// MARK: - Reusable State Views (Apple HIG Compliant)

/// Empty state view with icon, title, subtitle, and optional action
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?
    let action: ActionButton?

    struct ActionButton {
        let label: String
        let icon: String?
        let handler: () -> Void
    }

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        action: ActionButton? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }

            if let action = action {
                Button(action: action.handler) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if let actionIcon = action.icon {
                            Image(systemName: actionIcon)
                                .font(.system(size: DesignSystem.IconSize.small))
                        }
                        Text(action.label)
                            .font(DesignSystem.Typography.button)
                    }
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

/// Loading state view with progress indicator and optional message
struct LoadingStateView: View {
    let message: String?
    let size: Size

    enum Size {
        case small, medium, large

        var scale: CGFloat {
            switch self {
            case .small: return 0.6
            case .medium: return 0.8
            case .large: return 1.0
            }
        }
    }

    init(message: String? = nil, size: Size = .medium) {
        self.message = message
        self.size = size
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(size.scale)
                .controlSize(.large)

            if let message = message {
                Text(message)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

/// Error state view with icon, title, error message, and retry action
struct ErrorStateView: View {
    let title: String
    let error: String
    let retryAction: (() -> Void)?

    init(
        title: String = "Something went wrong",
        error: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.error = error
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DesignSystem.Colors.warning)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(error)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            if let retry = retryAction {
                Button(action: retry) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: DesignSystem.IconSize.small))
                        Text("Try Again")
                            .font(DesignSystem.Typography.button)
                    }
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

/// No selection placeholder (for master-detail interfaces)
struct NoSelectionView: View {
    let icon: String
    let message: String

    init(icon: String = "sidebar.left", message: String = "Select an item to view details") {
        self.icon = icon
        self.message = message
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(DesignSystem.Colors.textQuaternary)

            Text(message)
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Inline Loading Indicator

/// Small inline loading indicator for use in lists or rows
struct InlineLoadingView: View {
    let message: String?

    init(message: String? = nil) {
        self.message = message
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.6)
                .controlSize(.small)

            if let message = message {
                Text(message)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}

// MARK: - Previews

#Preview("Empty State") {
    EmptyStateView(
        icon: "tray",
        title: "No items",
        subtitle: "Get started by creating your first item",
        action: EmptyStateView.ActionButton(
            label: "Create Item",
            icon: "plus",
            handler: {}
        )
    )
    .background(DesignSystem.Materials.thin)
}

#Preview("Loading State") {
    LoadingStateView(message: "Loading items...")
        .background(DesignSystem.Materials.thin)
}

#Preview("Error State") {
    ErrorStateView(
        error: "Failed to load items. Please check your connection and try again.",
        retryAction: {}
    )
    .background(DesignSystem.Materials.thin)
}

#Preview("No Selection") {
    NoSelectionView()
        .background(DesignSystem.Materials.thin)
}
