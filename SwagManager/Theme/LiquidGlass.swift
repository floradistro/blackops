//
//  LiquidGlass.swift
//  SwagManager (macOS)
//
//  Liquid glass effects for macOS using native materials
//  Ported from iOS Whale app with macOS adaptations
//

import SwiftUI

// MARK: - Glass Intensity

enum GlassIntensity {
    case subtle, light, medium, strong, solid

    var baseOpacity: CGFloat {
        switch self {
        case .subtle: return 0.02
        case .light: return 0.04
        case .medium: return 0.06
        case .strong: return 0.10
        case .solid: return 0.15
        }
    }

    var selectedOpacity: CGFloat { baseOpacity * 2 }
    var backgroundOpacity: CGFloat { baseOpacity }
    var borderOpacity: CGFloat { baseOpacity * 1.5 }
}

// MARK: - View Extensions for Liquid Glass (macOS)

extension View {
    /// Liquid glass effect for macOS using native materials
    func liquidGlass(
        cornerRadius: CGFloat = 16,
        intensity: GlassIntensity = .medium,
        isSelected: Bool = false,
        borderWidth: CGFloat = 1.5
    ) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(intensity.borderOpacity), lineWidth: borderWidth)
            )
    }

    /// Liquid glass capsule for macOS
    func liquidGlassCapsule(
        intensity: GlassIntensity = .medium,
        isSelected: Bool = false,
        borderWidth: CGFloat = 1.5
    ) -> some View {
        self
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(intensity.borderOpacity), lineWidth: borderWidth)
            )
    }

    /// Liquid glass circle for macOS
    func liquidGlassCircle(
        intensity: GlassIntensity = .medium,
        isSelected: Bool = false,
        borderWidth: CGFloat = 1.5
    ) -> some View {
        self
            .background(.ultraThinMaterial, in: Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(intensity.borderOpacity), lineWidth: borderWidth)
            )
    }

    // Legacy compatibility
    func glassBackground(intensity: GlassIntensity = .medium, cornerRadius: CGFloat = 16) -> some View {
        liquidGlass(cornerRadius: cornerRadius, intensity: intensity)
    }

    func glassCapsule(intensity: GlassIntensity = .medium) -> some View {
        liquidGlassCapsule(intensity: intensity)
    }

    func glassCircle(intensity: GlassIntensity = .medium) -> some View {
        liquidGlassCircle(intensity: intensity)
    }

    /// macOS-compatible glassEffect emulation
    func glassEffect(_ style: GlassStyle, in shape: GlassShape) -> some View {
        self.modifier(GlassEffectModifier(style: style, shape: shape))
    }
}

// MARK: - Glass Effect Emulation for macOS

enum GlassStyle {
    case regular
    case thin
    case ultraThin

    var material: Material {
        switch self {
        case .regular: return .regularMaterial
        case .thin: return .thinMaterial
        case .ultraThin: return .ultraThinMaterial
        }
    }

    func interactive() -> GlassStyle { self }
}

// Type-erased InsettableShape wrapper
struct AnyInsettableShape: InsettableShape, @unchecked Sendable {
    private let _path: @Sendable (CGRect) -> Path
    private let _inset: @Sendable (CGFloat) -> AnyInsettableShape

    init<S: InsettableShape>(_ shape: S) where S: Sendable {
        _path = { rect in shape.path(in: rect) }
        _inset = { amount in AnyInsettableShape(shape.inset(by: amount)) }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        _inset(amount)
    }
}

enum GlassShape {
    case rect(cornerRadius: CGFloat)
    case capsule
    case circle

    func makeShape() -> AnyInsettableShape {
        switch self {
        case .rect(let radius):
            return AnyInsettableShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .capsule:
            return AnyInsettableShape(Capsule())
        case .circle:
            return AnyInsettableShape(Circle())
        }
    }
}

struct GlassEffectModifier: ViewModifier {
    let style: GlassStyle
    let shape: GlassShape

    func body(content: Content) -> some View {
        content
            .background(style.material, in: shape.makeShape())
            .overlay(
                shape.makeShape()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - Liquid Press Style

struct LiquidPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Note: ScaleButtonStyle already exists in ButtonStyles.swift

// MARK: - Liquid Glass Search Bar

struct LiquidGlassSearchBar: View {
    let placeholder: String
    @Binding var text: String
    var onClear: (() -> Void)?

    @FocusState private var isFocused: Bool

    init(
        _ placeholder: String = "Search...",
        text: Binding<String>,
        onClear: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.onClear = onClear
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isFocused ? .primary : .secondary)

            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .textFieldStyle(.plain)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                    onClear?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

// MARK: - Liquid Glass Pill

struct LiquidGlassPill: View {
    let label: String
    var icon: String?
    var count: Int?
    var color: Color?
    let isSelected: Bool
    let action: () -> Void

    init(
        _ label: String,
        icon: String? = nil,
        count: Int? = nil,
        color: Color? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.count = count
        self.color = color
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                }

                if let color = color {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }

                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))

                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.tertiary, in: .capsule)
                }
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected ? Color.white.opacity(0.15) : Color.clear,
                in: .capsule
            )
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

// MARK: - Liquid Glass Icon Button

struct LiquidGlassIconButton: View {
    let icon: String
    var size: CGFloat = 44
    var iconSize: CGFloat?
    var badge: Int?
    var badgeColor: Color = .blue
    var isSelected: Bool = false
    var tintColor: Color = .white
    let action: () -> Void

    private var computedIconSize: CGFloat {
        iconSize ?? (size * 0.40)
    }

    var body: some View {
        Button {
            action()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: computedIconSize, weight: .semibold))
                    .foregroundStyle(isSelected ? .blue : tintColor)
                    .frame(width: size, height: size)

                if let badge = badge, badge > 0 {
                    Text("\(min(badge, 99))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(badgeColor, in: Circle())
                        .offset(x: 6, y: -6)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(LiquidPressStyle())
        .glassEffect(.regular.interactive(), in: .circle)
    }
}

// MARK: - Modal Icon Button

struct ModalIconButton: View {
    let icon: String
    var tintColor: Color = .white.opacity(0.7)
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tintColor)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(LiquidPressStyle())
        .glassEffect(.regular.interactive(), in: .circle)
    }
}

// MARK: - Liquid Glass Button

struct LiquidGlassButton: View {
    let title: String
    var icon: String?
    var style: Style = .secondary
    var isFullWidth: Bool = true
    let action: () -> Void

    enum Style {
        case primary
        case secondary
        case ghost
        case destructive
        case success

        var tintColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .primary
            case .ghost: return .secondary
            case .destructive: return .red
            case .success: return .green
            }
        }
    }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(style.tintColor)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, isFullWidth ? 16 : 20)
            .padding(.vertical, 14)
            .contentShape(Capsule())
        }
        .buttonStyle(LiquidPressStyle())
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

// MARK: - Liquid Glass Card

struct LiquidGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16
    var intensity: GlassIntensity = .medium
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

// MARK: - Liquid Glass Text Field

struct LiquidGlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String?
    @FocusState private var isFocused: Bool

    init(
        _ placeholder: String,
        text: Binding<String>,
        icon: String? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isFocused ? .primary : .secondary)
                    .frame(width: 24)
            }

            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .textFieldStyle(.plain)
                .focused($isFocused)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
}

// MARK: - Glass Effect Container (macOS)

struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        content
    }
}

// MARK: - Legacy Compatibility Aliases

typealias GlassPill = LiquidGlassPill
typealias GlassSearchBar = LiquidGlassSearchBar
typealias GlassIconButton = LiquidGlassIconButton
typealias GlassButton = LiquidGlassButton
typealias GlassCard = LiquidGlassCard
typealias GlassTextField = LiquidGlassTextField
