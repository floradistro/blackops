import SwiftUI

// MARK: - Button Styles
// Unified button styles · Apple HIG compliant with spring press feedback

// MARK: - Primary

struct PrimaryButtonStyle: ButtonStyle {
    let color: Color

    init(_ color: Color = DesignSystem.Colors.accent) {
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Secondary

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(.primary)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Tertiary

struct TertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.buttonSmall)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(.primary.opacity(configuration.isPressed ? 0.1 : 0.05))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Destructive

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.error.opacity(configuration.isPressed ? 0.8 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Toolbar

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.buttonSmall)
            .foregroundStyle(.primary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs + 2)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Icon

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

// MARK: - Pill

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

// MARK: - Scale

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Hover

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
            .onHover { hovering in isHovering = hovering }
            .animation(DesignSystem.Animation.fast, value: isHovering)
    }
}

// MARK: - Minimal

struct MinimalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(DesignSystem.Colors.accent)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Static Convenience

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

// MARK: - Instance Convenience

extension Button {
    func primaryStyle(_ color: Color = DesignSystem.Colors.accent) -> some View {
        self.buttonStyle(PrimaryButtonStyle(color))
    }

    func secondaryStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }

    func tertiaryStyle() -> some View {
        self.buttonStyle(TertiaryButtonStyle())
    }

    func destructiveStyle() -> some View {
        self.buttonStyle(DestructiveButtonStyle())
    }

    func toolbarStyle() -> some View {
        self.buttonStyle(ToolbarButtonStyle())
    }

    func iconStyle(size: IconButtonStyle.Size = .medium) -> some View {
        self.buttonStyle(IconButtonStyle(size: size))
    }

    func pillStyle(color: Color = DesignSystem.Colors.accent) -> some View {
        self.buttonStyle(PillButtonStyle(color: color))
    }
}
