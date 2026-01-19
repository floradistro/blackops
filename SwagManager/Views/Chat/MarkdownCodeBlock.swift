import SwiftUI

// MARK: - Markdown Code Block View
// Extracted from MarkdownText.swift following Apple engineering standards
// Contains: CodeBlockView with syntax highlighting
// File size: ~237 lines (under Apple's 300 line "excellent" threshold)

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

