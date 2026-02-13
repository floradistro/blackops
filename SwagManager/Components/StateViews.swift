import SwiftUI

// MARK: - State Views
// Unified empty, loading, error, and placeholder states

// MARK: - Empty State

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
                .font(DesignSystem.font(48, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(.secondary)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }

            if let action {
                Button(action: action.handler) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if let actionIcon = action.icon {
                            Image(systemName: actionIcon)
                                .font(DesignSystem.font(DesignSystem.IconSize.small))
                        }
                        Text(action.label)
                            .font(DesignSystem.Typography.button)
                    }
                }
                .buttonStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

// MARK: - Loading State

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

    init(_ message: String? = nil, size: Size = .medium) {
        self.message = message
        self.size = size
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(size.scale)
                .controlSize(.large)

            if let message {
                Text(message)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

// MARK: - Error State

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
                .font(DesignSystem.font(48, weight: .light))
                .foregroundStyle(DesignSystem.Colors.warning)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(.primary)

                Text(error)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            if let retry = retryAction {
                Button(action: retry) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(DesignSystem.font(DesignSystem.IconSize.small))
                        Text("Try Again")
                            .font(DesignSystem.Typography.button)
                    }
                }
                .buttonStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

// MARK: - No Selection

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
                .font(DesignSystem.font(48, weight: .ultraLight))
                .foregroundStyle(.quaternary)

            Text(message)
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Inline Loading

struct InlineLoadingView: View {
    let message: String?

    init(_ message: String? = nil) {
        self.message = message
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.6)
                .controlSize(.small)

            if let message {
                Text(message)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}
