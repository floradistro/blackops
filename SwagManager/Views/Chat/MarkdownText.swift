import SwiftUI

// MARK: - Markdown Text View (Wilson Style - REFACTORED)
//
// Reduced from 1,066 lines to ~100 lines by extracting components:
// - WilsonTheme.swift (103 lines) - Theme colors, hex extension
// - MarkdownParser.swift (145 lines) - Parser logic, block types
// - MarkdownTextBlocks.swift (310 lines) - Text block rendering
// - MarkdownCodeBlock.swift (237 lines) - Code block with syntax highlighting
// - MarkdownTableBlocks.swift (193 lines) - Table and metrics blocks
//
// File size: ~100 lines (under Apple's 300 line "excellent" threshold)

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
