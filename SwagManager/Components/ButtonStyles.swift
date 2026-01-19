import SwiftUI

// MARK: - Standardized Button Styles (Apple HIG Compliant)

/// Primary action button (accent color, prominent)
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

/// Secondary action button (subtle, glass effect)
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

/// Destructive action button (red, for delete/remove actions)
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.error)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

/// Icon button (compact, icon-only or icon+text)
struct IconButtonStyle: ButtonStyle {
    let size: Size

    enum Size {
        case small, medium, large

        var padding: CGFloat {
            switch self {
            case .small: return DesignSystem.Spacing.xs
            case .medium: return DesignSystem.Spacing.sm
            case .large: return DesignSystem.Spacing.md
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return DesignSystem.IconSize.small
            case .medium: return DesignSystem.IconSize.medium
            case .large: return DesignSystem.IconSize.large
            }
        }
    }

    init(size: Size = .medium) {
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.iconSize))
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .padding(size.padding)
            .background(
                configuration.isPressed
                    ? DesignSystem.Colors.surfaceActive
                    : DesignSystem.Colors.surfaceElevated
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

/// Scale button (simple scale effect on press)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

/// Hover button (shows background on hover, common for lists)
struct HoverButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                isHovering || configuration.isPressed
                    ? DesignSystem.Colors.surfaceHover
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
            .onHover { hovering in
                isHovering = hovering
            }
            .animation(DesignSystem.Animation.fast, value: isHovering)
    }
}

/// Pill button (rounded capsule shape, used for tags/chips)
struct PillButtonStyle: ButtonStyle {
    let color: Color

    init(color: Color = DesignSystem.Colors.accent) {
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.caption1)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(color)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

/// Minimal button (text only, no background)
struct MinimalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(DesignSystem.Colors.accent)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle { ScaleButtonStyle() }
}

extension ButtonStyle where Self == MinimalButtonStyle {
    static var minimal: MinimalButtonStyle { MinimalButtonStyle() }
}

// MARK: - Previews

#Preview("Button Styles") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        Button("Primary Action") {}
            .buttonStyle(.primary)

        Button("Secondary Action") {}
            .buttonStyle(.secondary)

        Button("Delete") {}
            .buttonStyle(.destructive)

        HStack {
            Button {
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(IconButtonStyle(size: .small))

            Button {
            } label: {
                Image(systemName: "star.fill")
            }
            .buttonStyle(IconButtonStyle(size: .medium))

            Button {
            } label: {
                Image(systemName: "heart.fill")
            }
            .buttonStyle(IconButtonStyle(size: .large))
        }

        Button("Pill Button") {}
            .buttonStyle(PillButtonStyle())

        Button("Minimal Link") {}
            .buttonStyle(.minimal)
    }
    .padding()
    .background(DesignSystem.Materials.thin)
}
