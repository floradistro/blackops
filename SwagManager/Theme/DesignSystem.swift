import SwiftUI

// MARK: - Design System (Apple HIG Compliant)

/// Centralized design tokens following Apple Human Interface Guidelines
/// All spacing, colors, typography, and animations in one place
public struct DesignSystem {

    // MARK: - Spacing Scale (8pt grid system)
    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 24
        public static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius Scale
    public enum Radius {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 12
        public static let xl: CGFloat = 16
        public static let xxl: CGFloat = 20
        public static let pill: CGFloat = 9999
    }

    // MARK: - Typography Scale (SF Pro)
    public enum Typography {
        public static let largeTitle = Font.system(size: 34, weight: .bold)
        public static let title1 = Font.system(size: 28, weight: .bold)
        public static let title2 = Font.system(size: 22, weight: .bold)
        public static let title3 = Font.system(size: 20, weight: .semibold)
        public static let headline = Font.system(size: 17, weight: .semibold)
        public static let body = Font.system(size: 17, weight: .regular)
        public static let callout = Font.system(size: 16, weight: .regular)
        public static let subheadline = Font.system(size: 15, weight: .regular)
        public static let footnote = Font.system(size: 13, weight: .regular)
        public static let caption1 = Font.system(size: 12, weight: .regular)
        public static let caption2 = Font.system(size: 11, weight: .regular)

        // Monospace variants
        public static let monoBody = Font.system(size: 14, weight: .regular, design: .monospaced)
        public static let monoCaption = Font.system(size: 12, weight: .regular, design: .monospaced)

        // Button text
        public static let button = Font.system(size: 15, weight: .semibold)
        public static let buttonSmall = Font.system(size: 13, weight: .semibold)

        // Sidebar-specific typography
        public static let sidebarGroupHeader = Font.system(size: 11, weight: .semibold)
        public static let sidebarSectionLabel = Font.system(size: 13, weight: .medium)
        public static let sidebarItem = Font.system(size: 13, weight: .regular)
        public static let sidebarItemCount = Font.system(size: 11, weight: .regular)
    }

    // MARK: - Colors (Semantic, Dark Mode Optimized)
    public enum Colors {
        // Background hierarchy
        public static let surfacePrimary = Color.clear
        public static let surfaceSecondary = Color.clear
        public static let surfaceTertiary = Color.white.opacity(0.03)
        public static let surfaceElevated = Color.white.opacity(0.05)
        public static let surfaceHover = Color.white.opacity(0.04)
        public static let surfaceActive = Color.white.opacity(0.08)
        public static let surfaceSelected = Color.white.opacity(0.08)

        // Text hierarchy
        public static let textPrimary = Color.white.opacity(0.92)
        public static let textSecondary = Color.white.opacity(0.65)
        public static let textTertiary = Color.white.opacity(0.40)
        public static let textQuaternary = Color.white.opacity(0.25)
        public static let textDisabled = Color.white.opacity(0.20)

        // Borders and dividers
        public static let border = Color.white.opacity(0.08)
        public static let borderSubtle = Color.white.opacity(0.04)
        public static let divider = Color.white.opacity(0.06)

        // Semantic colors
        public static let accent = Color(red: 0.35, green: 0.68, blue: 1.0)
        public static let success = Color(red: 0.35, green: 0.78, blue: 0.48)
        public static let warning = Color(red: 0.95, green: 0.78, blue: 0.28)
        public static let error = Color(red: 0.95, green: 0.38, blue: 0.42)
        public static let info = Color(red: 0.35, green: 0.82, blue: 0.88)

        // Brand colors (soft, dark-mode optimized)
        public static let blue = Color(red: 0.35, green: 0.68, blue: 1.0)
        public static let green = Color(red: 0.35, green: 0.78, blue: 0.48)
        public static let yellow = Color(red: 0.95, green: 0.78, blue: 0.28)
        public static let orange = Color(red: 0.95, green: 0.55, blue: 0.28)
        public static let red = Color(red: 0.95, green: 0.38, blue: 0.42)
        public static let purple = Color(red: 0.68, green: 0.52, blue: 0.95)
        public static let cyan = Color(red: 0.35, green: 0.82, blue: 0.88)
        public static let pink = Color(red: 0.95, green: 0.50, blue: 0.70)

        // Selection states
        public static let selection = Color.white.opacity(0.08)
        public static let selectionActive = Color(red: 0.35, green: 0.68, blue: 1.0).opacity(0.20)
        public static let selectionSubtle = Color.white.opacity(0.04)
    }

    // MARK: - Glass Materials
    public enum Materials {
        public static let ultraThin = Material.ultraThin
        public static let thin = Material.thin
        public static let regular = Material.regular
        public static let thick = Material.thick
        public static let ultraThick = Material.ultraThick
    }

    // MARK: - Animations
    public enum Animation {
        public static let fast = SwiftUI.Animation.easeOut(duration: 0.15)
        public static let medium = SwiftUI.Animation.easeOut(duration: 0.25)
        public static let slow = SwiftUI.Animation.easeInOut(duration: 0.35)
        public static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.75)
        public static let springBouncy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.65)
    }

    // MARK: - Shadows
    public enum Shadow {
        public static let small = (color: Color.black.opacity(0.15), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        public static let medium = (color: Color.black.opacity(0.20), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        public static let large = (color: Color.black.opacity(0.25), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    }

    // MARK: - Icon Sizes
    public enum IconSize {
        public static let small: CGFloat = 14
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 20
        public static let xlarge: CGFloat = 24
    }

    // MARK: - Sidebar Tree Spacing (macOS native consistency)
    public enum TreeSpacing {
        // Vertical spacing
        public static let itemHeight: CGFloat = 26          // Consistent row height
        public static let itemPaddingVertical: CGFloat = 5  // Top/bottom padding (26 - 16 line = 10 / 2)
        public static let itemPaddingHorizontal: CGFloat = 8 // Left/right padding

        // Horizontal spacing
        public static let iconSpacing: CGFloat = 6          // Space between icon and text
        public static let elementSpacing: CGFloat = 4       // Space between elements

        // Indentation
        public static let indentPerLevel: CGFloat = 14      // Indent for each tree level

        // Icon sizes
        public static let chevronSize: CGFloat = 8          // Disclosure chevron
        public static let iconSize: CGFloat = 10            // Standard tree icon
        public static let statusIconSize: CGFloat = 6       // Status indicator dot

        // Font sizes
        public static let primaryTextSize: CGFloat = 11     // Main item text
        public static let secondaryTextSize: CGFloat = 9    // Secondary/meta text
        public static let sectionHeaderSize: CGFloat = 11   // Section headers

        // Section spacing
        public static let sectionPaddingTop: CGFloat = 2    // Between sections
        public static let sectionPaddingVertical: CGFloat = 4 // Section header padding
    }
}

// MARK: - Convenient View Extensions

extension View {
    /// Apply standard padding presets
    func padding(_ preset: DesignSystem.Spacing.Type) -> some View {
        padding(preset.md)
    }

    /// Apply glass surface with standard styling
    func glassSurface(
        material: Material = DesignSystem.Materials.thin,
        tint: Color = DesignSystem.Colors.surfaceTertiary,
        radius: CGFloat = DesignSystem.Radius.md
    ) -> some View {
        background(tint)
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }

    /// Apply standard border
    func standardBorder(color: Color = DesignSystem.Colors.border, width: CGFloat = 1) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(color, lineWidth: width)
        )
    }

    /// Apply hover effect (standard macOS hover state)
    func hoverEffect(isHovered: Bool) -> some View {
        background(
            isHovered ? DesignSystem.Colors.surfaceHover : Color.clear
        )
    }
}

// MARK: - Legacy Theme Compatibility Layer
// Keep existing Theme references working during migration

extension DesignSystem {
    // Legacy compatibility
    public static let glassThin = Materials.thin
    public static let glass = Materials.thin
    public static let glassMedium = Materials.regular
    public static let glassThick = Materials.thick
    public static let glassUltraThick = Materials.ultraThick

    public static let bg = Colors.surfacePrimary
    public static let bgSecondary = Colors.surfaceSecondary
    public static let bgTertiary = Colors.surfaceTertiary
    public static let bgElevated = Colors.surfaceElevated
    public static let bgHover = Colors.surfaceHover
    public static let bgActive = Colors.surfaceActive

    public static let border = Colors.border
    public static let borderSubtle = Colors.borderSubtle

    public static let text = Colors.textPrimary
    public static let textSecondary = Colors.textSecondary
    public static let textTertiary = Colors.textTertiary
    public static let textQuaternary = Colors.textQuaternary

    public static let accent = Colors.accent
    public static let green = Colors.green
    public static let yellow = Colors.yellow
    public static let orange = Colors.orange
    public static let red = Colors.error
    public static let blue = Colors.blue
    public static let purple = Colors.purple
    public static let cyan = Colors.cyan

    public static let selection = Colors.selection
    public static let selectionActive = Colors.selectionActive
    public static let selectionSubtle = Colors.selectionSubtle

    public static let animationFast = Animation.fast
    public static let animationMedium = Animation.medium
    public static let animationSlow = Animation.slow
    public static let spring = Animation.spring

    public static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    public static func monoFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Backward Compatibility (Legacy Theme → DesignSystem)

/// Legacy Theme typealias for backward compatibility
/// All Theme.* references now use DesignSystem
public typealias Theme = DesignSystem.LegacyTheme

public extension DesignSystem {
    struct LegacyTheme {
        // Glass Materials
        public static let glassThin = Materials.thin
        public static let glass = Materials.regular
        public static let glassMedium = Materials.regular
        public static let glassThick = Materials.thick
        public static let glassUltraThick = Materials.ultraThick

        // Backgrounds
        public static let bg = Colors.surfacePrimary
        public static let bgSecondary = Colors.surfaceSecondary
        public static let bgTertiary = Colors.surfaceTertiary
        public static let bgElevated = Colors.surfaceElevated
        public static let bgHover = Colors.surfaceHover
        public static let bgActive = Colors.surfaceActive

        // Borders
        public static let border = Colors.border
        public static let borderSubtle = Colors.borderSubtle

        // Text
        public static let text = Colors.textPrimary
        public static let textSecondary = Colors.textSecondary
        public static let textTertiary = Colors.textTertiary
        public static let textQuaternary = Colors.textQuaternary

        // Accents
        public static let accent = Colors.accent
        public static let green = Colors.success
        public static let yellow = Colors.warning
        public static let orange = Colors.warning
        public static let red = Colors.error
        public static let blue = Colors.accent
        public static let purple = Color(red: 0.68, green: 0.52, blue: 0.95)
        public static let cyan = Color(red: 0.35, green: 0.82, blue: 0.88)

        // Selection
        public static let selection = Colors.selection
        public static let selectionActive = Colors.selectionActive
        public static let selectionSubtle = Colors.selectionSubtle

        // Animations
        public static let animationFast = Animation.fast
        public static let animationMedium = Animation.medium
        public static let animationSlow = Animation.slow
        public static let spring = Animation.spring

        // Fonts
        public static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            DesignSystem.font(size, weight: weight)
        }

        public static func monoFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            DesignSystem.monoFont(size, weight: weight)
        }
    }
}
