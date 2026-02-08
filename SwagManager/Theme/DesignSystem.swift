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
        public static let monoSmall = Font.system(size: 9, weight: .medium, design: .monospaced)
        public static let monoLabel = Font.system(size: 10, weight: .medium, design: .monospaced)
        public static let monoHeader = Font.system(size: 10, weight: .semibold, design: .monospaced)

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

        // MARK: - Telemetry (OTEL-style palette)
        public enum Telemetry {
            // Status colors
            static let success = Color(red: 0.2, green: 0.7, blue: 0.4)
            static let error = Color(red: 0.9, green: 0.3, blue: 0.3)
            static let warning = Color(red: 0.95, green: 0.7, blue: 0.2)
            static let info = Color(red: 0.4, green: 0.6, blue: 0.9)

            // Latency colors
            static let latencyFast = Color(red: 0.2, green: 0.7, blue: 0.4)
            static let latencyMedium = Color(red: 0.95, green: 0.7, blue: 0.2)
            static let latencySlow = Color(red: 0.9, green: 0.3, blue: 0.3)

            // Source colors
            static let sourceClaude = Color(red: 0.8, green: 0.5, blue: 0.2)
            static let sourceApp = Color(red: 0.4, green: 0.6, blue: 0.9)
            static let sourceAPI = Color(red: 0.6, green: 0.4, blue: 0.8)
            static let sourceEdge = Color(red: 0.2, green: 0.7, blue: 0.7)

            // JSON syntax colors
            static let jsonKey = Color(red: 0.6, green: 0.4, blue: 0.8)
            static let jsonString = Color(red: 0.2, green: 0.7, blue: 0.4)
            static let jsonNumber = Color(red: 0.4, green: 0.6, blue: 0.9)
            static let jsonBool = Color(red: 0.9, green: 0.5, blue: 0.2)

            static func forLatency(_ ms: Double?) -> Color {
                guard let ms = ms else { return .secondary }
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

