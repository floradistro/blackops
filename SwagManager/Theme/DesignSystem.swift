import SwiftUI

// MARK: - Design System
// Unified design tokens · Apple Human Interface Guidelines
// Single source of truth across all Whale platform apps

struct DesignSystem {

    // MARK: - Spacing (8pt grid)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let pill: CGFloat = 9999
    }

    // MARK: - Typography (SF Pro)

    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold)
        static let title1 = Font.system(size: 28, weight: .bold)
        static let title2 = Font.system(size: 22, weight: .bold)
        static let title3 = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let callout = Font.system(size: 16, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption1 = Font.system(size: 12, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .regular)

        // Monospace
        static let monoBody = Font.system(size: 14, weight: .regular, design: .monospaced)
        static let monoCaption = Font.system(size: 12, weight: .regular, design: .monospaced)
        static let monoSmall = Font.system(size: 9, weight: .medium, design: .monospaced)
        static let monoLabel = Font.system(size: 10, weight: .medium, design: .monospaced)
        static let monoHeader = Font.system(size: 10, weight: .semibold, design: .monospaced)

        // Buttons
        static let button = Font.system(size: 15, weight: .semibold)
        static let buttonSmall = Font.system(size: 13, weight: .semibold)

        // Sidebar
        static let sidebarGroupHeader = Font.system(size: 11, weight: .semibold)
        static let sidebarSectionLabel = Font.system(size: 13, weight: .medium)
        static let sidebarItem = Font.system(size: 13, weight: .regular)
        static let sidebarItemCount = Font.system(size: 11, weight: .regular)
    }

    // MARK: - Colors (Semantic · Dark Mode Optimized)

    enum Colors {
        // Surface hierarchy
        static let surfacePrimary = Color.clear
        static let surfaceSecondary = Color.clear
        static let surfaceTertiary = Color.white.opacity(0.03)
        static let surfaceElevated = Color.white.opacity(0.05)
        static let surfaceHover = Color.white.opacity(0.04)
        static let surfaceActive = Color.white.opacity(0.08)
        static let surfaceSelected = Color.white.opacity(0.08)

        // Text hierarchy
        static let textPrimary = Color.white.opacity(0.92)
        static let textSecondary = Color.white.opacity(0.65)
        static let textTertiary = Color.white.opacity(0.40)
        static let textQuaternary = Color.white.opacity(0.25)
        static let textDisabled = Color.white.opacity(0.20)

        // Borders
        static let border = Color.white.opacity(0.08)
        static let borderSubtle = Color.white.opacity(0.04)
        static let divider = Color.white.opacity(0.06)

        // Semantic
        static let accent = Color(red: 0.35, green: 0.68, blue: 1.0)
        static let success = Color(red: 0.35, green: 0.78, blue: 0.48)
        static let warning = Color(red: 0.95, green: 0.78, blue: 0.28)
        static let error = Color(red: 0.95, green: 0.38, blue: 0.42)
        static let info = Color(red: 0.35, green: 0.82, blue: 0.88)

        // Brand palette
        static let blue = Color(red: 0.35, green: 0.68, blue: 1.0)
        static let green = Color(red: 0.35, green: 0.78, blue: 0.48)
        static let yellow = Color(red: 0.95, green: 0.78, blue: 0.28)
        static let orange = Color(red: 0.95, green: 0.55, blue: 0.28)
        static let red = Color(red: 0.95, green: 0.38, blue: 0.42)
        static let purple = Color(red: 0.68, green: 0.52, blue: 0.95)
        static let cyan = Color(red: 0.35, green: 0.82, blue: 0.88)
        static let pink = Color(red: 0.95, green: 0.50, blue: 0.70)

        // Selection
        static let selection = Color.white.opacity(0.08)
        static let selectionActive = Color(red: 0.35, green: 0.68, blue: 1.0).opacity(0.20)
        static let selectionSubtle = Color.white.opacity(0.04)

        // MARK: Telemetry (OTEL-style)

        enum Telemetry {
            static let success = Color(red: 0.2, green: 0.7, blue: 0.4)
            static let error = Color(red: 0.9, green: 0.3, blue: 0.3)
            static let warning = Color(red: 0.95, green: 0.7, blue: 0.2)
            static let info = Color(red: 0.4, green: 0.6, blue: 0.9)

            static let latencyFast = Color(red: 0.2, green: 0.7, blue: 0.4)
            static let latencyMedium = Color(red: 0.95, green: 0.7, blue: 0.2)
            static let latencySlow = Color(red: 0.9, green: 0.3, blue: 0.3)

            static let sourceClaude = Color(red: 0.8, green: 0.5, blue: 0.2)
            static let sourceApp = Color(red: 0.4, green: 0.6, blue: 0.9)
            static let sourceAPI = Color(red: 0.6, green: 0.4, blue: 0.8)
            static let sourceEdge = Color(red: 0.2, green: 0.7, blue: 0.7)

            static let jsonKey = Color(red: 0.6, green: 0.4, blue: 0.8)
            static let jsonString = Color(red: 0.2, green: 0.7, blue: 0.4)
            static let jsonNumber = Color(red: 0.4, green: 0.6, blue: 0.9)
            static let jsonBool = Color(red: 0.9, green: 0.5, blue: 0.2)

            static func forLatency(_ ms: Double?) -> Color {
                guard let ms else { return .secondary }
                if ms < 100 { return latencyFast }
                if ms < 500 { return latencyMedium }
                return latencySlow
            }

            static func forSource(_ source: String) -> Color {
                switch source {
                case "claude_code": return sourceClaude
                case "swag_manager": return sourceApp
                case "api": return sourceAPI
                case "edge_function": return sourceEdge
                default: return .secondary
                }
            }

            static func forSeverity(_ severity: String) -> Color {
                switch severity {
                case "error", "critical": return error
                case "warning": return warning
                case "info": return info
                default: return success
                }
            }
        }
    }

    // MARK: - Materials

    enum Materials {
        static let ultraThin = Material.ultraThin
        static let thin = Material.thin
        static let regular = Material.regular
        static let thick = Material.thick
        static let ultraThick = Material.ultraThick
    }

    // MARK: - Animation

    enum Animation {
        static let fast = SwiftUI.Animation.easeOut(duration: 0.15)
        static let medium = SwiftUI.Animation.easeOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.75)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.65)
        static let springSmooth = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.85)
    }

    // MARK: - Shadows

    enum Shadow {
        static let small = (color: Color.black.opacity(0.15), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.20), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let large = (color: Color.black.opacity(0.25), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    }

    // MARK: - Icon Sizes

    enum IconSize {
        static let small: CGFloat = 14
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xlarge: CGFloat = 24
    }

    // MARK: - Sidebar Tree Spacing

    enum TreeSpacing {
        static let itemHeight: CGFloat = 26
        static let itemPaddingVertical: CGFloat = 5
        static let itemPaddingHorizontal: CGFloat = 8
        static let iconSpacing: CGFloat = 6
        static let elementSpacing: CGFloat = 4
        static let indentPerLevel: CGFloat = 14
        static let chevronSize: CGFloat = 8
        static let iconSize: CGFloat = 10
        static let statusIconSize: CGFloat = 6
        static let primaryTextSize: CGFloat = 11
        static let secondaryTextSize: CGFloat = 9
        static let sectionHeaderSize: CGFloat = 11
        static let sectionPaddingTop: CGFloat = 2
        static let sectionPaddingVertical: CGFloat = 4
    }

    // MARK: - Layout Constants

    static let sidebarWidth: CGFloat = 320
    static let sidebarMaxWidth: CGFloat = 400
    static let toolbarHeight: CGFloat = 52
    static let listItemHeight: CGFloat = 72

    // MARK: - Flat Typography Aliases

    static let largeTitle = Typography.largeTitle
    static let title1 = Typography.title1
    static let title2 = Typography.title2
    static let title3 = Typography.title3
    static let headline = Typography.headline
    static let body = Typography.body
    static let callout = Typography.callout
    static let subheadline = Typography.subheadline
    static let footnote = Typography.footnote
    static let caption1 = Typography.caption1
    static let caption2 = Typography.caption2

    // MARK: - Flat Spacing Aliases

    static let spacing2 = Spacing.xxs
    static let spacing4 = Spacing.xs
    static let spacing8 = Spacing.sm
    static let spacing12 = Spacing.md
    static let spacing16 = Spacing.lg
    static let spacing20 = Spacing.xl
    static let spacing24 = Spacing.xxl
    static let spacing32 = Spacing.xxxl

    // MARK: - Flat Radius Aliases

    static let cornerRadius4 = Radius.xs
    static let cornerRadius6 = Radius.sm
    static let cornerRadius8 = Radius.md
    static let cornerRadius12 = Radius.lg
    static let cornerRadius16 = Radius.xl
    static let cornerRadius20 = Radius.xxl

    // MARK: - Helpers

    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func monoFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - View Extensions

extension View {
    /// Ultra-thin material background for inputs and subtle containers
    func glassBackground(cornerRadius: CGFloat = DesignSystem.Radius.lg) -> some View {
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Configurable glass surface with material, tint, and corner radius
    func glassSurface(
        material: Material = DesignSystem.Materials.regular,
        tint: Color = DesignSystem.Colors.surfaceTertiary,
        cornerRadius: CGFloat = DesignSystem.Radius.lg
    ) -> some View {
        self
            .background(tint)
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Card container with regular material, padding, and 0.5pt border
    func cardStyle(padding: CGFloat = DesignSystem.Spacing.lg, cornerRadius: CGFloat = DesignSystem.Radius.lg) -> some View {
        self
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            }
    }

    /// Subtle border overlay
    func standardBorder(color: Color = DesignSystem.Colors.border, cornerRadius: CGFloat = DesignSystem.Radius.md, width: CGFloat = 1) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(color, lineWidth: width)
        )
    }

    /// Background highlight on hover
    func hoverEffect(isHovered: Bool) -> some View {
        self.background(isHovered ? DesignSystem.Colors.surfaceHover : Color.clear)
    }
}

// MARK: - Global Alias

typealias DS = DesignSystem
