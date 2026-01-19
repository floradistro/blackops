import SwiftUI

// MARK: - Wilson Theme Colors (Material Ocean)
// Extracted from MarkdownText.swift following Apple engineering standards
// Contains: Theme colors, syntax highlighting colors, Color hex extension
// File size: ~103 lines (under Apple's 300 line "excellent" threshold)

struct WilsonColors {
    // Primary Brand
    static let primary = Color(hex: "#7DC87D")      // Wilson green
    static let secondary = Color(hex: "#89DDFF")    // Cyan accent

    // Status Colors
    static let success = Color(hex: "#C3E88D")      // Bright green
    static let error = Color(hex: "#FF5370")        // Bright red
    static let warning = Color(hex: "#FFCB6B")      // Amber
    static let info = Color(hex: "#82AAFF")         // Blue

    // Text Colors (higher contrast)
    static let text = Color(hex: "#EEFFFF")         // Primary text
    static let textMuted = Color(hex: "#A0A0A0")    // Secondary text
    static let textDim = Color(hex: "#707070")      // Tertiary
    static let textVeryDim = Color(hex: "#505050")  // Subtle
    static let textDisabled = Color(hex: "#404040") // Disabled

    // UI Elements
    static let border = Color(hex: "#3D4D5D")       // Subtle blue-gray
    static let borderLight = Color(hex: "#2D3D4D")

    // Syntax Highlighting (Material Ocean)
    struct Syntax {
        static let keyword = Color(hex: "#C792EA")    // Purple - if, const, function
        static let builtin = Color(hex: "#82AAFF")    // Blue - console, require
        static let type = Color(hex: "#FFCB6B")       // Yellow - types, classes
        static let literal = Color(hex: "#FF5370")    // Red - true, false, null
        static let number = Color(hex: "#F78C6C")     // Orange - numbers
        static let string = Color(hex: "#C3E88D")     // Green - strings
        static let comment = Color(hex: "#546E7A")    // Gray - comments
        static let function = Color(hex: "#82AAFF")   // Blue - function calls
        static let `operator` = Color(hex: "#89DDFF") // Cyan - = + - =>
        static let property = Color(hex: "#F07178")   // Coral - object.property
        static let tag = Color(hex: "#F07178")        // Coral - <Component>
        static let attribute = Color(hex: "#C792EA")  // Purple - className=
        static let variable = Color(hex: "#EEFFFF")   // White - variables
        static let punctuation = Color(hex: "#89DDFF") // Cyan - {} [] ()
    }

    // Markdown element colors
    static let h1 = Color(hex: "#82AAFF")           // Blue headers
    static let h2 = Color(hex: "#89DDFF")           // Cyan headers
    static let h3 = Color(hex: "#A0A0A0")           // Gray headers
    static let inlineCode = Color(hex: "#C792EA")   // Purple
    static let link = Color(hex: "#82AAFF")         // Blue underlined
    static let bold = Color(hex: "#EEFFFF")         // Bright white
    static let italic = Color(hex: "#B0B0B0")       // Gray
    static let bullet = Color(hex: "#7DC87D")       // Green
    static let listNumber = Color(hex: "#F78C6C")   // Orange
    static let quote = Color(hex: "#546E7A")        // Gray
    static let action = Color(hex: "#7DC87D")       // Green
    static let label = Color(hex: "#89DDFF")        // Cyan
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - String Extension

extension String {
    func trimWhitespace() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func leftPadded(toLength length: Int, withPad pad: Character = " ") -> String {
        let padCount = length - self.count
        guard padCount > 0 else { return self }
        return String(repeating: pad, count: padCount) + self
    }
}
