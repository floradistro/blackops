import SwiftUI

// MARK: - Markdown Text Block View
// Extracted from MarkdownText.swift following Apple engineering standards
// Contains: TextBlockView with inline markdown rendering
// File size: ~310 lines (under Apple's 500 line "good" threshold)

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
            // Bold **text**
            if remaining.hasPrefix("**") {
                let afterStars = remaining.dropFirst(2)
                if let endRange = afterStars.range(of: "**") {
                    let boldText = String(afterStars[..<endRange.lowerBound])
                    var boldAttr = AttributedString(boldText)
                    boldAttr.font = .system(size: 14, weight: .semibold)
                    result += boldAttr
                    remaining = afterStars[endRange.upperBound...]
                    continue
                }
            }

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

