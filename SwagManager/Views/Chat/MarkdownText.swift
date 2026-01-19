import SwiftUI

// MARK: - Wilson Theme Colors (Material Ocean)

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

// MARK: - Markdown Block Types

enum MarkdownBlock: Identifiable {
    case text(content: String)
    case code(content: String, lang: String?, incomplete: Bool)
    case table(headers: [String], rows: [[String]])
    case metrics(title: String?, items: [(label: String, value: String)])

    var id: String {
        switch self {
        case .text(let content): return "text-\(content.hashValue)"
        case .code(let content, let lang, _): return "code-\(lang ?? "")-\(content.hashValue)"
        case .table(let headers, _): return "table-\(headers.joined())"
        case .metrics(let title, _): return "metrics-\(title ?? "")"
        }
    }
}

// MARK: - Markdown Parser (Wilson style)

struct MarkdownParser {

    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var cleaned = text

        // === AGGRESSIVE TEXT CLEANUP (Wilson style) ===
        // Remove stray ** markers
        cleaned = cleaned.replacingOccurrences(of: "**", with: "", options: .regularExpression.union(.caseInsensitive), range: nil)

        // Clean up ## headers
        let headerPattern = try? NSRegularExpression(pattern: "^##\\s+", options: .anchorsMatchLines)
        cleaned = headerPattern?.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "") ?? cleaned

        // Fix sentences stuck together
        cleaned = cleaned.replacingOccurrences(of: "([.!?:])([A-Z])", with: "$1\n\n$2", options: .regularExpression)

        // Clean up multiple newlines
        cleaned = cleaned.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        let lines = cleaned.components(separatedBy: "\n")
        var buf: [String] = []
        var inCode = false
        var codeLang = ""
        var inTable = false
        var tableHeaders: [String] = []
        var tableRows: [[String]] = []

        for line in lines {
            // Code block handling
            if line.hasPrefix("```") {
                // Flush table if in one
                if inTable && !tableHeaders.isEmpty {
                    blocks.append(.table(headers: tableHeaders, rows: tableRows))
                    inTable = false
                    tableHeaders = []
                    tableRows = []
                }

                if !inCode {
                    // Starting code block
                    if !buf.isEmpty {
                        blocks.append(.text(content: buf.joined(separator: "\n")))
                        buf = []
                    }
                    inCode = true
                    codeLang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                } else {
                    // Ending code block
                    blocks.append(.code(content: buf.joined(separator: "\n"), lang: codeLang.isEmpty ? nil : codeLang, incomplete: false))
                    inCode = false
                    codeLang = ""
                    buf = []
                }
                continue
            }

            if inCode {
                buf.append(line)
                continue
            }

            // Table detection
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isTableLine = trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
            let isSeparator = isTableLine && trimmed.contains("-")

            if isTableLine {
                if !inTable && !buf.isEmpty {
                    blocks.append(.text(content: buf.joined(separator: "\n")))
                    buf = []
                }

                let cells = parseTableRow(trimmed)

                if !inTable {
                    tableHeaders = cells
                    inTable = true
                } else if isSeparator {
                    continue
                } else {
                    tableRows.append(cells)
                }
                continue
            }

            // Flush table if we exit
            if inTable && !tableHeaders.isEmpty {
                blocks.append(.table(headers: tableHeaders, rows: tableRows))
                inTable = false
                tableHeaders = []
                tableRows = []
            }

            buf.append(line)
        }

        // Handle remaining buffer
        if inTable && !tableHeaders.isEmpty {
            blocks.append(.table(headers: tableHeaders, rows: tableRows))
        }

        if !buf.isEmpty {
            if inCode {
                blocks.append(.code(content: buf.joined(separator: "\n"), lang: codeLang.isEmpty ? nil : codeLang, incomplete: true))
            } else {
                blocks.append(.text(content: buf.joined(separator: "\n")))
            }
        }

        return blocks
    }

    private static func parseTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed = String(trimmed.dropFirst()) }
        if trimmed.hasSuffix("|") { trimmed = String(trimmed.dropLast()) }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - Markdown Text View (Wilson Style)

struct MarkdownText: View, Equatable {
    let content: String
    let isFromCurrentUser: Bool

    // Pre-parsed blocks - computed once at init
    private let blocks: [MarkdownBlock]
    private let isPreformatted: Bool

    init(_ content: String, isFromCurrentUser: Bool = false) {
        self.content = content
        self.isFromCurrentUser = isFromCurrentUser

        // Pre-compute once instead of on every render
        self.isPreformatted = content.contains("===") ||
            content.split(separator: "\n").filter { $0.contains("   ") && $0.count > 20 }.count >= 2

        if self.isPreformatted {
            self.blocks = []
        } else {
            self.blocks = MarkdownParser.parse(content)
        }
    }

    // Equatable - only re-render if content changes
    static func == (lhs: MarkdownText, rhs: MarkdownText) -> Bool {
        lhs.content == rhs.content
    }

    var body: some View {
        if isPreformatted {
            // Preformatted text - monospace
            Text(content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(WilsonColors.text)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(blocks) { block in
                    blockView(for: block)
                }
            }
        }
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .text(let content):
            TextBlockView(content: content, isFromCurrentUser: isFromCurrentUser)

        case .code(let content, let lang, let incomplete):
            CodeBlockView(code: content, language: lang, incomplete: incomplete)

        case .table(let headers, let rows):
            TableBlockView(headers: headers, rows: rows)

        case .metrics(let title, let items):
            MetricsBlockView(title: title, metrics: items)
        }
    }
}

// MARK: - Text Block (Wilson Style)

struct TextBlockView: View, Equatable {
    let content: String
    let isFromCurrentUser: Bool

    // Pre-parsed structure
    private let parsedLines: [[String]]

    init(content: String, isFromCurrentUser: Bool) {
        self.content = content
        self.isFromCurrentUser = isFromCurrentUser

        // Parse once at init, not on every render
        let paragraphs = content.split(separator: "\n\n", omittingEmptySubsequences: true)
        self.parsedLines = paragraphs.map { para in
            para.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        }
    }

    static func == (lhs: TextBlockView, rhs: TextBlockView) -> Bool {
        lhs.content == rhs.content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parsedLines.indices, id: \.self) { paraIndex in
                let lines = parsedLines[paraIndex]
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(lines.indices, id: \.self) { lineIndex in
                        renderLine(lines[lineIndex])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            EmptyView()
        }
        // Headers
        else if trimmed.hasPrefix("### ") {
            Text(String(trimmed.dropFirst(4)))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WilsonColors.h3)
                .padding(.top, 4)
        }
        else if trimmed.hasPrefix("## ") {
            Text(String(trimmed.dropFirst(3)))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WilsonColors.h2)
                .padding(.top, 6)
        }
        else if trimmed.hasPrefix("# ") {
            Text(String(trimmed.dropFirst(2)))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(WilsonColors.h1)
                .padding(.top, 8)
        }
        // Blockquote
        else if trimmed.hasPrefix("> ") {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(WilsonColors.textDim)
                    .frame(width: 3)
                Text(renderInlineText(String(trimmed.dropFirst(2))))
                    .font(.system(size: 14).italic())
                    .foregroundStyle(WilsonColors.quote)
            }
            .padding(.leading, 8)
        }
        // Unordered list
        else if let listContent = parseUnorderedListItem(trimmed) {
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WilsonColors.bullet)
                Text(renderInlineText(listContent))
                    .font(.system(size: 14))
                    .foregroundStyle(isFromCurrentUser ? .white : WilsonColors.text)
            }
            .padding(.leading, 12)
        }
        // Ordered list
        else if let (num, listContent) = parseOrderedListItem(trimmed) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(num).")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(WilsonColors.listNumber)
                    .frame(minWidth: 20, alignment: .trailing)
                Text(renderInlineText(listContent))
                    .font(.system(size: 14))
                    .foregroundStyle(isFromCurrentUser ? .white : WilsonColors.text)
            }
            .padding(.leading, 12)
        }
        // Horizontal rule
        else if trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) && trimmed.count >= 3 {
            Rectangle()
                .fill(WilsonColors.textDim)
                .frame(height: 1)
                .padding(.vertical, 8)
        }
        // Action lines (Let me, I'll, etc.)
        else if trimmed.hasPrefix("Let me") || trimmed.hasPrefix("I'll") || trimmed.hasPrefix("I will") || trimmed.hasPrefix("Let's") {
            HStack(spacing: 4) {
                Text("→")
                    .foregroundStyle(WilsonColors.action)
                Text(renderInlineText(trimmed))
                    .font(.system(size: 14))
                    .foregroundStyle(isFromCurrentUser ? .white : WilsonColors.text)
            }
        }
        // Label ending with colon
        else if trimmed.hasSuffix(":") && trimmed.count < 60 && !trimmed.contains("  ") {
            Text(trimmed)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(WilsonColors.label)
                .padding(.top, 4)
        }
        // Key-value pairs
        else if let (key, value) = parseKeyValue(trimmed), key.count < 20 {
            HStack(spacing: 4) {
                Text("\(key):")
                    .font(.system(size: 14))
                    .foregroundStyle(WilsonColors.textMuted)
                Text(renderInlineText(value))
                    .font(.system(size: 14))
                    .foregroundStyle(isFromCurrentUser ? .white : WilsonColors.text)
            }
            .padding(.leading, 8)
        }
        // Regular text
        else {
            Text(renderInlineText(trimmed))
                .font(.system(size: 14))
                .foregroundStyle(isFromCurrentUser ? .white : WilsonColors.text)
        }
    }

    private func renderInlineText(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[...]

        while !remaining.isEmpty {
            // Inline code `code`
            if remaining.hasPrefix("`") {
                if let endIdx = remaining.dropFirst().firstIndex(of: "`") {
                    let code = String(remaining[remaining.index(after: remaining.startIndex)..<endIdx])
                    var codeAttr = AttributedString(code)
                    codeAttr.foregroundColor = WilsonColors.inlineCode
                    codeAttr.font = .system(size: 13, design: .monospaced)
                    result += codeAttr
                    remaining = remaining[remaining.index(after: endIdx)...]
                    continue
                }
            }

            // Currency $123.45 or $1,234
            if remaining.hasPrefix("$") {
                var currency = "$"
                var idx = remaining.index(after: remaining.startIndex)
                while idx < remaining.endIndex && (remaining[idx].isNumber || remaining[idx] == "," || remaining[idx] == ".") {
                    currency.append(remaining[idx])
                    idx = remaining.index(after: idx)
                }
                if currency.count > 1 {
                    var attr = AttributedString(currency)
                    attr.foregroundColor = WilsonColors.success
                    attr.font = .system(size: 14, weight: .bold)
                    result += attr
                    remaining = remaining[idx...]
                    continue
                }
            }

            // Positive percentage +12.5%
            if remaining.hasPrefix("+") {
                var pct = "+"
                var idx = remaining.index(after: remaining.startIndex)
                while idx < remaining.endIndex && (remaining[idx].isNumber || remaining[idx] == ".") {
                    pct.append(remaining[idx])
                    idx = remaining.index(after: idx)
                }
                if idx < remaining.endIndex && remaining[idx] == "%" {
                    pct.append("%")
                    idx = remaining.index(after: idx)
                    var attr = AttributedString(pct)
                    attr.foregroundColor = WilsonColors.success
                    attr.font = .system(size: 14, weight: .bold)
                    result += attr
                    remaining = remaining[idx...]
                    continue
                }
            }

            // Negative percentage -12.5%
            if remaining.hasPrefix("-") && remaining.dropFirst().first?.isNumber == true {
                var pct = "-"
                var idx = remaining.index(after: remaining.startIndex)
                while idx < remaining.endIndex && (remaining[idx].isNumber || remaining[idx] == ".") {
                    pct.append(remaining[idx])
                    idx = remaining.index(after: idx)
                }
                if idx < remaining.endIndex && remaining[idx] == "%" {
                    pct.append("%")
                    idx = remaining.index(after: idx)
                    var attr = AttributedString(pct)
                    attr.foregroundColor = WilsonColors.error
                    attr.font = .system(size: 14, weight: .bold)
                    result += attr
                    remaining = remaining[idx...]
                    continue
                }
            }

            // Large numbers with commas (1,234)
            if let first = remaining.first, first.isNumber {
                var num = ""
                var idx = remaining.startIndex
                var hasComma = false
                while idx < remaining.endIndex && (remaining[idx].isNumber || remaining[idx] == ",") {
                    if remaining[idx] == "," { hasComma = true }
                    num.append(remaining[idx])
                    idx = remaining.index(after: idx)
                }
                if hasComma && num.count > 3 {
                    var attr = AttributedString(num)
                    attr.foregroundColor = WilsonColors.secondary
                    attr.font = .system(size: 14, weight: .bold)
                    result += attr
                    remaining = remaining[idx...]
                    continue
                } else {
                    // Just a regular number, add it normally
                    result += AttributedString(num)
                    remaining = remaining[idx...]
                    continue
                }
            }

            // Regular character
            result += AttributedString(String(remaining.prefix(1)))
            remaining = remaining.dropFirst()
        }

        return result
    }

    // Helper: parse unordered list item (- item, * item, + item)
    private func parseUnorderedListItem(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for prefix in ["- ", "* ", "+ "] {
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(2))
            }
        }
        return nil
    }

    // Helper: parse ordered list item (1. item)
    private func parseOrderedListItem(_ line: String) -> (String, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var idx = trimmed.startIndex
        var numStr = ""

        // Get leading digits
        while idx < trimmed.endIndex && trimmed[idx].isNumber {
            numStr.append(trimmed[idx])
            idx = trimmed.index(after: idx)
        }

        guard !numStr.isEmpty,
              idx < trimmed.endIndex,
              trimmed[idx] == "." else { return nil }

        let afterDot = trimmed.index(after: idx)
        guard afterDot < trimmed.endIndex,
              trimmed[afterDot] == " " else { return nil }

        let content = String(trimmed[trimmed.index(after: afterDot)...])
        return (numStr, content)
    }

    // Helper: parse key-value pair (Key: value)
    private func parseKeyValue(_ line: String) -> (String, String)? {
        guard let colonIdx = line.firstIndex(of: ":") else { return nil }
        let key = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces)
        let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

        // Key must start with letter and contain only letters/spaces
        guard let first = key.first, first.isLetter else { return nil }
        guard key.allSatisfy({ $0.isLetter || $0 == " " }) else { return nil }
        guard !value.isEmpty else { return nil }

        return (key, value)
    }
}

// MARK: - Code Block View (Wilson Style)

struct CodeBlockView: View {
    let code: String
    let language: String?
    let incomplete: Bool
    @State private var expanded = true
    @State private var copied = false

    private var lines: [String] { code.components(separatedBy: "\n") }
    private var isLong: Bool { lines.count > 10 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language badge
            HStack(spacing: 8) {
                Text("╭─")
                    .foregroundStyle(WilsonColors.border)
                    .font(.system(size: 12, design: .monospaced))

                if let lang = language, !lang.isEmpty {
                    Text(lang)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(WilsonColors.textDim)
                }

                if isLong && !incomplete {
                    Text(expanded ? "[-]" : "[+\(lines.count)]")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(WilsonColors.textVeryDim)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                        }
                }

                if incomplete {
                    Text("streaming...")
                        .font(.system(size: 10))
                        .foregroundStyle(WilsonColors.warning)
                }

                Spacer()

                // Copy button
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(copied ? WilsonColors.success : WilsonColors.textDim)
                }
                .buttonStyle(.plain)
            }

            // Code lines
            let displayLines = expanded || !isLong ? lines : Array(lines.prefix(6))
            ForEach(Array(displayLines.enumerated()), id: \.offset) { idx, line in
                HStack(spacing: 0) {
                    Text("│")
                        .foregroundStyle(WilsonColors.border)
                    Text(String(format: "%4d ", idx + 1))
                        .foregroundStyle(WilsonColors.textDisabled)
                    Text("│ ")
                        .foregroundStyle(WilsonColors.border)
                    Text(highlightLine(line))
                }
                .font(.system(size: 12, design: .monospaced))
            }

            // Hidden lines indicator
            if !expanded && isLong && !incomplete {
                HStack(spacing: 0) {
                    Text("│")
                        .foregroundStyle(WilsonColors.border)
                    Text("      │ ... \(lines.count - 6) more lines")
                        .foregroundStyle(WilsonColors.textVeryDim)
                }
                .font(.system(size: 12, design: .monospaced))
            }

            // Footer
            if !incomplete {
                Text("╰" + String(repeating: "─", count: 46))
                    .foregroundStyle(WilsonColors.border)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
    }

    private func highlightLine(_ line: String) -> AttributedString {
        var result = AttributedString()
        var remaining = line[...]
        let lang = (language ?? "").lowercased()

        // Language keywords
        let keywords: Set<String> = {
            switch lang {
            case "swift":
                return ["func", "var", "let", "if", "else", "for", "while", "return", "import", "struct", "class", "enum", "protocol", "extension", "guard", "switch", "case", "default", "break", "continue", "private", "public", "internal", "static", "final", "override", "init", "self", "nil", "true", "false", "async", "await", "throws", "try", "catch", "@State", "@Binding", "@Published", "@ObservedObject", "@StateObject", "@Environment", "@MainActor", "some", "any"]
            case "javascript", "js", "typescript", "ts", "tsx", "jsx":
                return ["function", "const", "let", "var", "if", "else", "for", "while", "return", "import", "export", "from", "class", "extends", "new", "this", "async", "await", "try", "catch", "throw", "switch", "case", "default", "break", "continue", "true", "false", "null", "undefined", "typeof", "instanceof", "interface", "type"]
            case "python", "py":
                return ["def", "class", "if", "elif", "else", "for", "while", "return", "import", "from", "as", "try", "except", "finally", "raise", "with", "lambda", "pass", "break", "continue", "True", "False", "None", "and", "or", "not", "in", "is", "async", "await", "yield"]
            case "sql":
                return ["SELECT", "FROM", "WHERE", "AND", "OR", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "INDEX", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "GROUP", "BY", "ORDER", "ASC", "DESC", "LIMIT", "OFFSET", "HAVING", "DISTINCT", "AS", "NULL", "NOT", "IN", "LIKE", "BETWEEN", "EXISTS", "CASE", "WHEN", "THEN", "ELSE", "END", "COUNT", "SUM", "AVG", "MAX", "MIN"]
            default:
                return ["function", "func", "def", "class", "if", "else", "for", "while", "return", "import", "var", "let", "const", "true", "false", "null", "nil"]
            }
        }()

        while !remaining.isEmpty {
            // Comment
            if remaining.hasPrefix("//") || (lang == "python" && remaining.hasPrefix("#")) {
                var attr = AttributedString(String(remaining))
                attr.foregroundColor = WilsonColors.Syntax.comment
                result += attr
                break
            }

            // String (double quotes)
            if remaining.hasPrefix("\"") {
                var str = "\""
                var idx = remaining.index(after: remaining.startIndex)
                while idx < remaining.endIndex {
                    let char = remaining[idx]
                    str.append(char)
                    if char == "\"" { break }
                    idx = remaining.index(after: idx)
                }
                var attr = AttributedString(str)
                attr.foregroundColor = WilsonColors.Syntax.string
                result += attr
                if idx < remaining.endIndex {
                    remaining = remaining[remaining.index(after: idx)...]
                } else {
                    remaining = remaining[idx...]
                }
                continue
            }

            // String (single quotes)
            if remaining.hasPrefix("'") {
                var str = "'"
                var idx = remaining.index(after: remaining.startIndex)
                while idx < remaining.endIndex {
                    let char = remaining[idx]
                    str.append(char)
                    if char == "'" { break }
                    idx = remaining.index(after: idx)
                }
                var attr = AttributedString(str)
                attr.foregroundColor = WilsonColors.Syntax.string
                result += attr
                if idx < remaining.endIndex {
                    remaining = remaining[remaining.index(after: idx)...]
                } else {
                    remaining = remaining[idx...]
                }
                continue
            }

            // Number
            if let first = remaining.first, first.isNumber {
                var num = ""
                var idx = remaining.startIndex
                while idx < remaining.endIndex && (remaining[idx].isNumber || remaining[idx] == "." || remaining[idx] == "x" || remaining[idx].isHexDigit) {
                    num.append(remaining[idx])
                    idx = remaining.index(after: idx)
                }
                var attr = AttributedString(num)
                attr.foregroundColor = WilsonColors.Syntax.number
                result += attr
                remaining = remaining[idx...]
                continue
            }

            // Word (keyword or identifier)
            if let first = remaining.first, first.isLetter || first == "_" || first == "@" {
                var word = ""
                var idx = remaining.startIndex
                while idx < remaining.endIndex && (remaining[idx].isLetter || remaining[idx].isNumber || remaining[idx] == "_" || remaining[idx] == "@") {
                    word.append(remaining[idx])
                    idx = remaining.index(after: idx)
                }
                var attr = AttributedString(word)
                if keywords.contains(word) {
                    attr.foregroundColor = WilsonColors.Syntax.keyword
                } else if word.first?.isUppercase == true {
                    attr.foregroundColor = WilsonColors.Syntax.type
                } else {
                    attr.foregroundColor = WilsonColors.Syntax.variable
                }
                result += attr
                remaining = remaining[idx...]
                continue
            }

            // Operators & punctuation
            if let first = remaining.first, "=+-*/<>!&|?:".contains(first) {
                var attr = AttributedString(String(first))
                attr.foregroundColor = WilsonColors.Syntax.operator
                result += attr
                remaining = remaining.dropFirst()
                continue
            }

            if let first = remaining.first, "{}[](),;".contains(first) {
                var attr = AttributedString(String(first))
                attr.foregroundColor = WilsonColors.Syntax.punctuation
                result += attr
                remaining = remaining.dropFirst()
                continue
            }

            // Other characters
            var attr = AttributedString(String(remaining.prefix(1)))
            attr.foregroundColor = WilsonColors.Syntax.variable
            result += attr
            remaining = remaining.dropFirst()
        }

        return result
    }
}

// MARK: - Table Block View (Wilson Style)

struct TableBlockView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        let colWidths = calculateColumnWidths()

        VStack(alignment: .leading, spacing: 0) {
            // Top border
            HStack(spacing: 0) {
                Text("╭")
                    .foregroundStyle(WilsonColors.textDim)
                ForEach(Array(colWidths.enumerated()), id: \.offset) { idx, width in
                    Text(String(repeating: "─", count: width + 2))
                        .foregroundStyle(WilsonColors.textDim)
                    if idx < colWidths.count - 1 {
                        Text("┬").foregroundStyle(WilsonColors.textDim)
                    }
                }
                Text("╮").foregroundStyle(WilsonColors.textDim)
            }
            .font(.system(size: 12, design: .monospaced))

            // Headers
            HStack(spacing: 0) {
                Text("│ ").foregroundStyle(WilsonColors.textDim)
                ForEach(Array(headers.enumerated()), id: \.offset) { idx, header in
                    Text(header.padding(toLength: colWidths[idx], withPad: " ", startingAt: 0))
                        .foregroundStyle(WilsonColors.h2)
                        .fontWeight(.bold)
                    Text(" │ ").foregroundStyle(WilsonColors.textDim)
                }
            }
            .font(.system(size: 12, design: .monospaced))

            // Header separator
            HStack(spacing: 0) {
                Text("├")
                    .foregroundStyle(WilsonColors.textDim)
                ForEach(Array(colWidths.enumerated()), id: \.offset) { idx, width in
                    Text(String(repeating: "─", count: width + 2))
                        .foregroundStyle(WilsonColors.textDim)
                    if idx < colWidths.count - 1 {
                        Text("┼").foregroundStyle(WilsonColors.textDim)
                    }
                }
                Text("┤").foregroundStyle(WilsonColors.textDim)
            }
            .font(.system(size: 12, design: .monospaced))

            // Data rows
            ForEach(Array(rows.prefix(15).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    Text("│ ").foregroundStyle(WilsonColors.textDim)
                    ForEach(Array(row.enumerated()), id: \.offset) { idx, cell in
                        let width = idx < colWidths.count ? colWidths[idx] : 10
                        Text(cell.padding(toLength: width, withPad: " ", startingAt: 0))
                            .foregroundStyle(cellColor(cell))
                        Text(" │ ").foregroundStyle(WilsonColors.textDim)
                    }
                }
                .font(.system(size: 12, design: .monospaced))
            }

            // More rows indicator
            if rows.count > 15 {
                HStack(spacing: 0) {
                    Text("│ ").foregroundStyle(WilsonColors.textDim)
                    Text("... \(rows.count - 15) more rows")
                        .foregroundStyle(WilsonColors.textVeryDim)
                }
                .font(.system(size: 12, design: .monospaced))
            }

            // Bottom border
            HStack(spacing: 0) {
                Text("╰")
                    .foregroundStyle(WilsonColors.textDim)
                ForEach(Array(colWidths.enumerated()), id: \.offset) { idx, width in
                    Text(String(repeating: "─", count: width + 2))
                        .foregroundStyle(WilsonColors.textDim)
                    if idx < colWidths.count - 1 {
                        Text("┴").foregroundStyle(WilsonColors.textDim)
                    }
                }
                Text("╯").foregroundStyle(WilsonColors.textDim)
            }
            .font(.system(size: 12, design: .monospaced))
        }
    }

    private func calculateColumnWidths() -> [Int] {
        headers.enumerated().map { idx, header in
            let headerWidth = header.count
            let maxDataWidth = rows.map { row in
                idx < row.count ? row[idx].count : 0
            }.max() ?? 0
            return min(max(headerWidth, maxDataWidth, 4), 25)
        }
    }

    private func cellColor(_ cell: String) -> Color {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        let isNum = trimmed.range(of: #"^-?\$?[\d,]+\.?\d*%?$"#, options: .regularExpression) != nil
        let isNeg = trimmed.hasPrefix("-")

        if isNum {
            return isNeg ? WilsonColors.error : WilsonColors.success
        }
        return WilsonColors.text
    }
}

// MARK: - Metrics Block View (Wilson Style)

struct MetricsBlockView: View {
    let title: String?
    let metrics: [(label: String, value: String)]

    var body: some View {
        if metrics.isEmpty { return AnyView(EmptyView()) }

        let labelWidth = max(metrics.map { $0.label.count }.max() ?? 8, 8)
        let valueWidth = max(metrics.map { $0.value.count }.max() ?? 8, 8)
        let totalWidth = labelWidth + valueWidth + 5

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                // Top border with title
                HStack(spacing: 0) {
                    Text("╭")
                        .foregroundStyle(WilsonColors.textDim)
                    Text(String(repeating: "─", count: totalWidth))
                        .foregroundStyle(WilsonColors.textDim)
                    if let title = title {
                        Text("─ ")
                            .foregroundStyle(WilsonColors.textDim)
                        Text(title)
                            .foregroundStyle(WilsonColors.h1)
                            .fontWeight(.bold)
                        Text(" ")
                    }
                    Text("╮").foregroundStyle(WilsonColors.textDim)
                }
                .font(.system(size: 12, design: .monospaced))

                // Metric rows
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    HStack(spacing: 0) {
                        Text("│ ").foregroundStyle(WilsonColors.textDim)
                        Text(metric.label.padding(toLength: labelWidth, withPad: " ", startingAt: 0))
                            .foregroundStyle(WilsonColors.textMuted)
                        Text(" │ ").foregroundStyle(WilsonColors.textDim)
                        Text(metric.value.leftPadded(toLength: valueWidth))
                            .foregroundStyle(valueColor(metric.value))
                            .fontWeight(.bold)
                        Text(" │").foregroundStyle(WilsonColors.textDim)
                    }
                    .font(.system(size: 12, design: .monospaced))
                }

                // Bottom border
                HStack(spacing: 0) {
                    Text("╰")
                        .foregroundStyle(WilsonColors.textDim)
                    Text(String(repeating: "─", count: totalWidth + (title?.count ?? 0) + 4))
                        .foregroundStyle(WilsonColors.textDim)
                    Text("╯").foregroundStyle(WilsonColors.textDim)
                }
                .font(.system(size: 12, design: .monospaced))
            }
        )
    }

    private func valueColor(_ value: String) -> Color {
        let isCurrency = value.hasPrefix("$")
        let isPercent = value.hasSuffix("%")
        let isNegative = value.contains("-") || value.lowercased().contains("decrease") || value.lowercased().contains("down")

        if isCurrency { return WilsonColors.success }
        if isPercent && isNegative { return WilsonColors.error }
        if isPercent { return WilsonColors.success }
        return WilsonColors.text
    }
}

// MARK: - String Extension

extension String {
    func leftPadded(toLength length: Int, withPad pad: Character = " ") -> String {
        let padCount = length - self.count
        guard padCount > 0 else { return self }
        return String(repeating: pad, count: padCount) + self
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            MarkdownText("""
            # Welcome to Wilson

            This is a **test** of the markdown rendering.

            ## Code Example

            Here's some inline `code` and a block:

            ```swift
            func greet(name: String) -> String {
                return "Hello, \\(name)!"
            }

            let message = greet(name: "World")
            print(message)
            ```

            ## Lists

            - First item with $1,234 value
            - Second item at +15.2%
            - Third item at -8.5%

            1. Numbered one
            2. Numbered two

            > This is a blockquote

            | Product | Price | Stock |
            |---------|-------|-------|
            | Widget  | $10   | 100   |
            | Gadget  | $25   | -50   |

            Let me analyze this data for you.
            """)
        }
        .padding()
    }
    .background(Color(hex: "#0F111A"))
}
