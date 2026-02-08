import SwiftUI

private typealias TC = DesignSystem.Colors.Telemetry

// MARK: - Session Row (Chat-style feed item)

struct SessionRow: View {
    let session: TelemetrySession
    let isSelected: Bool
    var isLive: Bool = false
    var isNew: Bool = false
    @State private var pulseScale: CGFloat = 1.0

    private var actionSummary: String {
        let tools = session.allSpans.compactMap { $0.toolName }
        if tools.isEmpty { return "started session" }
        let uniqueTools = Set(tools)
        return "\(session.turnCount) turn\(session.turnCount == 1 ? "" : "s") • \(uniqueTools.prefix(2).joined(separator: ", "))"
    }

    var body: some View {
        HStack(spacing: 10) {
            // Compact avatar
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08))
                    .frame(width: 32, height: 32)

                if isLive {
                    Circle()
                        .stroke(TC.success, lineWidth: 2)
                        .frame(width: 34, height: 34)
                        .scaleEffect(pulseScale)
                        .opacity(0.7)
                }

                Text(session.userInitials)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
            }

            // Content - single line, compact
            HStack(spacing: 6) {
                // Source icon
                Image(systemName: session.sourceIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                // Name + action
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.userName ?? session.userEmail ?? "User")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(actionSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Status + time
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(spacing: 3) {
                        if session.hasErrors {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(TC.error)
                        } else if isLive {
                            Circle()
                                .fill(TC.success)
                                .frame(width: 6, height: 6)
                        }

                        Text(session.formattedDuration)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Text(session.endTime ?? session.startTime, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onAppear {
            if isLive {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.2
                }
            }
        }
        .onChange(of: isLive) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.2
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    pulseScale = 1.0
                }
            }
        }
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

    private var isChatMessage: Bool {
        span.action == "chat.user_message" || span.action == "chat.assistant_response"
    }

    private var isUserMessage: Bool {
        span.action == "chat.user_message"
    }

    private var isAssistantMessage: Bool {
        span.action == "chat.assistant_response"
    }

    private var toolName: String {
        if span.isApiRequest {
            return span.shortModelName ?? "claude"
        }
        if isUserMessage {
            return "user"
        }
        if isAssistantMessage {
            return "assistant"
        }
        return span.toolName ?? span.action
    }

    private var isApiRequest: Bool {
        span.isApiRequest
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 2) {
                // Main row: status + tool + waterfall + duration
                HStack(spacing: 0) {
                    // Status indicator - different for API requests and chat messages
                    if isApiRequest {
                        Text("\u{25C6}")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(TC.sourceClaude)
                            .frame(width: 20)
                    } else if isUserMessage {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                            .frame(width: 20)
                    } else if isAssistantMessage {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundStyle(.purple)
                            .frame(width: 20)
                    } else {
                        Text(span.isError ? "\u{00D7}" : "\u{2713}")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(span.isError ? TC.error : TC.success)
                            .frame(width: 20)
                    }

                    // Tool name - monospace, no decoration
                    Text(toolName)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(
                            isApiRequest ? TC.sourceClaude :
                            isUserMessage ? .blue :
                            isAssistantMessage ? .purple :
                            span.isError ? TC.error : .primary
                        )
                        .lineLimit(1)
                        .frame(width: 120, alignment: .leading)

                    // Token usage for API requests (compact)
                    if isApiRequest, let tokens = span.formattedTokens {
                        Text(tokens)
                            .font(.system(size: 13, design: .monospaced))
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

                // Activity description (inline preview)
                if let activity = span.activityDescription {
                    HStack(alignment: .top, spacing: 4) {
                        Text("└─")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.quaternary)
                        Text(activity)
                            .font(.system(size: isChatMessage ? 12 : 11))
                            .foregroundStyle(
                                span.isError ? TC.error :
                                isChatMessage ? .primary :
                                .secondary
                            )
                            .lineLimit(isChatMessage ? nil : 1)  // Unlimited lines for chat, single for tools
                            .textSelection(.enabled)  // Allow selecting message text
                            .fixedSize(horizontal: false, vertical: true)  // Allow wrapping
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 12)
                    .padding(.vertical, isChatMessage ? 4 : 0)
                    .background(
                        isChatMessage ? Color.primary.opacity(0.03) : Color.clear
                    )
                    .cornerRadius(6)
                }
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
