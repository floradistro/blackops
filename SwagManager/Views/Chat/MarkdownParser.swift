import Foundation

// MARK: - Markdown Parser Components
// Extracted from MarkdownText.swift following Apple engineering standards
// Contains: MarkdownBlock enum, MarkdownParser struct
// File size: ~145 lines (under Apple's 300 line "excellent" threshold)

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
