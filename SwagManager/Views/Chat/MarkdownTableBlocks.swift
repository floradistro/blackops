import SwiftUI

// MARK: - Markdown Table & Metrics Block Views
// Extracted from MarkdownText.swift following Apple engineering standards
// Contains: TableBlockView, MetricsBlockView
// File size: ~193 lines (under Apple's 300 line "excellent" threshold)

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

