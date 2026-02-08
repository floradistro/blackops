import SwiftUI

private typealias TC = DesignSystem.Colors.Telemetry

// MARK: - Session Row (one row per conversation session)

struct SessionRow: View {
    let session: TelemetrySession
    let isSelected: Bool
    var isLive: Bool = false

    /// Generate a human-readable summary from all tools across the session
    private var actionSummary: String {
        let tools = session.allSpans.compactMap { $0.toolName }
        if tools.isEmpty { return "session" }
        var counts: [String: Int] = [:]
        for tool in tools {
            let baseName = tool.components(separatedBy: ".").first ?? tool
            counts[baseName, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.prefix(2).map { item in
            item.key.replacingOccurrences(of: "_", with: " ")
        }.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 0) {
            // Status indicator with live pulse
            ZStack {
                if isLive {
                    Circle()
                        .fill(TC.success.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(TC.success)
                        .frame(width: 5, height: 5)
                } else {
                    Text(session.hasErrors ? "ERR" : "OK")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(session.hasErrors ? TC.error : TC.success)
                }
            }
            .frame(width: 28, alignment: .leading)

            // Main content
            VStack(alignment: .leading, spacing: 3) {
                // Action summary + agent name
                HStack(spacing: 4) {
                    if let agent = session.agentName {
                        Text(agent)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(actionSummary)
                        .font(.system(.caption, weight: .medium))
                        .lineLimit(1)
                }

                // Metadata line with mini progress bar
                HStack(spacing: 6) {
                    Label("\(session.turnCount)", systemImage: "bubble.left.fill")
                        .foregroundStyle(.secondary)
                    Label("\(session.toolCount)", systemImage: "wrench.fill")
                        .foregroundStyle(.tertiary)
                    if session.hasErrors {
                        Label("\(session.errorCount)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(TC.error)
                    }
                    if let cost = session.formattedCost {
                        Text(cost)
                            .foregroundStyle(TC.warning)
                    }
                }
                .font(.system(size: 9))
                .labelStyle(.titleAndIcon)
            }

            Spacer()

            // Right: duration and time
            VStack(alignment: .trailing, spacing: 3) {
                Text(session.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(session.endTime ?? session.startTime, style: .relative)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : isLive ? TC.success.opacity(0.03) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Span Row (Anthropic-style minimal waterfall)

struct SpanRow: View {
    let span: TelemetrySpan
    let traceStart: Date
    let traceDuration: TimeInterval
    let isSelected: Bool
    var isNew: Bool = false
    let onSelect: () -> Void

    private var spanStart: TimeInterval {
        span.createdAt.timeIntervalSince(traceStart)
    }

    private var spanDuration: TimeInterval {
        Double(span.durationMs ?? 0) / 1000.0
    }

    private var startPercent: CGFloat {
        guard traceDuration > 0 else { return 0 }
        return CGFloat(spanStart / traceDuration)
    }

    private var widthPercent: CGFloat {
        guard traceDuration > 0 else { return 0.01 }
        return max(0.01, CGFloat(spanDuration / traceDuration))
    }

    private var toolName: String {
        if span.isApiRequest {
            return span.shortModelName ?? "claude"
        }
        return span.toolName ?? span.action
    }

    private var isApiRequest: Bool {
        span.isApiRequest
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                // Status indicator - different for API requests
                if isApiRequest {
                    Text("\u{25C6}")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(TC.sourceClaude)
                        .frame(width: 20)
                } else {
                    Text(span.isError ? "\u{00D7}" : "\u{2713}")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(span.isError ? TC.error : TC.success)
                        .frame(width: 20)
                }

                // Tool name - monospace, no decoration
                Text(toolName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isApiRequest ? TC.sourceClaude : span.isError ? TC.error : .primary)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)

                // Token usage for API requests (compact)
                if isApiRequest, let tokens = span.formattedTokens {
                    Text(tokens)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                } else {
                    Spacer().frame(width: 70)
                }

                // Waterfall bar - simple, no gradients
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        Rectangle()
                            .fill(Color.primary.opacity(0.04))

                        // Bar - solid color
                        Rectangle()
                            .fill(span.isError ? TC.error : Color.primary.opacity(0.25))
                            .frame(width: max(2, geo.size.width * widthPercent))
                            .offset(x: geo.size.width * startPercent)
                    }
                }
                .frame(height: 16)

                // Duration - right aligned
                Text(span.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(
                isSelected ? Color.primary.opacity(0.06)
                : isNew ? TC.success.opacity(0.08)
                : Color.clear
            )
        }
        .buttonStyle(.plain)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: -4)).combined(with: .scale(scale: 0.98, anchor: .top)),
            removal: .opacity
        ))
    }
}

// MARK: - Expandable JSON (Anthropic-style minimal)

struct ExpandableJSON: View {
    let details: [String: AnyCodable]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(details.keys.sorted()), id: \.self) { key in
                JSONRow(key: key, value: details[key]?.value, depth: 0)
            }
        }
        .font(.system(.caption, design: .monospaced))
    }
}

struct JSONRow: View {
    let key: String
    let value: Any?
    let depth: Int
    @State private var isExpanded = false  // Collapsed by default

    private var isExpandable: Bool {
        value is [String: Any] || value is [Any]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // Indent
                Text(String(repeating: "  ", count: depth))

                // Key
                Text(key)
                    .foregroundStyle(.tertiary)
                Text(": ")
                    .foregroundStyle(.quaternary)

                // Value
                if isExpandable {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        if let dict = value as? [String: Any] {
                            Text(isExpanded ? "{...}" : "{ \(dict.count) }")
                                .foregroundStyle(.secondary)
                        } else if let arr = value as? [Any] {
                            Text(isExpanded ? "[...]" : "[ \(arr.count) ]")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    valueText(value)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, 1)

            // Expanded children
            if isExpanded {
                if let dict = value as? [String: Any] {
                    ForEach(Array(dict.keys.sorted()), id: \.self) { childKey in
                        JSONRow(key: childKey, value: dict[childKey], depth: depth + 1)
                    }
                } else if let arr = value as? [Any] {
                    ForEach(Array(arr.enumerated()), id: \.offset) { index, item in
                        JSONRow(key: "\(index)", value: item, depth: depth + 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func valueText(_ value: Any?) -> some View {
        if let str = value as? String {
            Text("\"\(str)\"")
                .foregroundStyle(TC.jsonString)
        } else if let num = value as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                Text(num.boolValue ? "true" : "false")
                    .foregroundStyle(TC.jsonBool)
            } else {
                Text("\(num)")
                    .foregroundStyle(TC.jsonNumber)
            }
        } else if let bool = value as? Bool {
            Text(bool ? "true" : "false")
                .foregroundStyle(TC.jsonBool)
        } else if let int = value as? Int {
            Text("\(int)")
                .foregroundStyle(TC.jsonNumber)
        } else if let double = value as? Double {
            Text(String(format: "%.2f", double))
                .foregroundStyle(TC.jsonNumber)
        } else if value == nil {
            Text("null")
                .foregroundStyle(.quaternary)
        } else {
            Text("\(String(describing: value))")
                .foregroundStyle(.secondary)
        }
    }
}
