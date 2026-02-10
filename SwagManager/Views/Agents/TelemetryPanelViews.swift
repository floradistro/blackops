import SwiftUI

private typealias TC = DesignSystem.Colors.Telemetry

// MARK: - Color Hex Extension

private extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b, a: Double
        switch hexSanitized.count {
        case 6:
            r = Double((rgb >> 16) & 0xFF) / 255.0
            g = Double((rgb >> 8) & 0xFF) / 255.0
            b = Double(rgb & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((rgb >> 24) & 0xFF) / 255.0
            g = Double((rgb >> 16) & 0xFF) / 255.0
            b = Double((rgb >> 8) & 0xFF) / 255.0
            a = Double(rgb & 0xFF) / 255.0
        default:
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Session Row (Chat-style feed item)

struct SessionRow: View {
    let session: TelemetrySession
    let isSelected: Bool
    var isLive: Bool = false
    var isNew: Bool = false
    var isExpanded: Bool = false
    var onToggleExpand: (() -> Void)? = nil
    @State private var pulseScale: CGFloat = 1.0

    private var actionSummary: String {
        let tools = session.allSpans.compactMap { $0.toolName }
        let uniqueTools = Set(tools)
        let baseSummary: String
        if tools.isEmpty {
            baseSummary = "started session"
        } else {
            baseSummary = "\(session.turnCount) turn\(session.turnCount == 1 ? "" : "s") • \(uniqueTools.prefix(2).joined(separator: ", "))"
        }

        // Add child count suffix if has children
        if session.isTeamCoordinator {
            return "\(baseSummary) +\(session.childSessions.count)"
        }
        return baseSummary
    }

    var body: some View {
        HStack(spacing: 10) {
            // Expand/collapse chevron for team coordinators (subtle)
            if session.isTeamCoordinator {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.quaternary)
                    .frame(width: 14, height: 24)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onToggleExpand?()
                    }
            }

            // Compact avatar - same style for all, small badge for teams
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

                // Small team badge in corner
                if session.isTeamCoordinator {
                    Circle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Text("\(session.childSessions.count)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                        )
                        .offset(x: 12, y: 10)
                }
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

// MARK: - Teammate Session Row (Indented child in tree)

struct TeammateSessionRow: View {
    let session: TelemetrySession
    let isSelected: Bool
    var isLive: Bool = false
    @State private var pulseScale: CGFloat = 1.0

    private var teammateName: String {
        session.teammateName ?? "Agent"
    }

    private var summary: String {
        let tools = session.allSpans.compactMap { $0.toolName }
        let uniqueTools = Set(tools)
        if uniqueTools.isEmpty {
            return "\(session.turnCount) turn\(session.turnCount == 1 ? "" : "s")"
        }
        return "\(session.turnCount) turn\(session.turnCount == 1 ? "" : "s") • \(uniqueTools.prefix(2).joined(separator: ", "))"
    }

    var body: some View {
        HStack(spacing: 8) {
            // Subtle indent line
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1, height: 24)
                .padding(.leading, 28)

            // Small avatar
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                    .frame(width: 24, height: 24)

                if isLive {
                    Circle()
                        .stroke(TC.success, lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                        .scaleEffect(pulseScale)
                        .opacity(0.6)
                }

                Text(String(teammateName.prefix(1)))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }

            // Name + summary
            VStack(alignment: .leading, spacing: 1) {
                Text(teammateName)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(summary)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Status
            HStack(spacing: 3) {
                if session.hasErrors {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(TC.error)
                } else if isLive {
                    Circle()
                        .fill(TC.success)
                        .frame(width: 4, height: 4)
                }

                Text(session.formattedDuration)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.1)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onAppear {
            if isLive {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }
            }
        }
        .onChange(of: isLive) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
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

    private var isSubagent: Bool {
        span.isSubagent
    }

    /// Is this a team ACTION span (team.create, team.teammate_start, etc.) - NOT just any span from a teammate
    private var isTeamActionSpan: Bool {
        span.action.hasPrefix("team.")
    }

    /// Is this any span related to a team (for styling purposes)
    private var isTeam: Bool {
        span.isTeam || span.isTeammate || span.isTeamCoordinator
    }

    private var isTeamCoordinator: Bool {
        span.isTeamCoordinator
    }

    private var isTeammate: Bool {
        span.isTeammate
    }

    /// Display name for the span - tool executions should show tool name even if from teammate
    private var toolName: String {
        // Tool executions always show tool name, even if from teammate
        if span.isToolSpan {
            return span.toolName ?? span.action
        }
        if span.isApiRequest {
            // For teammate API requests, show model + teammate indicator
            if isTeammate, let teammateName = span.teammateName {
                return "\(span.shortModelName ?? "claude") (\(teammateName))"
            }
            return span.shortModelName ?? "claude"
        }
        if isUserMessage {
            return "user"
        }
        if isAssistantMessage {
            return "assistant"
        }
        // Team ACTION spans (team.create, team.teammate_start, etc.) show team/teammate name
        if isTeamActionSpan {
            return span.teamDisplayName ?? (isTeamCoordinator ? "Team Lead" : span.teammateName ?? "Teammate")
        }
        if isSubagent {
            return span.subagentDisplayName ?? "Subagent"
        }
        return span.toolName ?? span.action
    }

    private var subagentColor: Color {
        Color(hex: span.subagentColor) ?? .purple
    }

    private var teamColor: Color {
        Color(hex: span.teamColor) ?? .green
    }

    private var isApiRequest: Bool {
        span.isApiRequest
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 2) {
                // Main row: status + tool + waterfall + duration
                HStack(spacing: 0) {
                    // Depth indicator for subagent spans (nested hierarchy)
                    if span.depth > 0 {
                        HStack(spacing: 0) {
                            ForEach(0..<span.depth, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.primary.opacity(0.1))
                                    .frame(width: 1)
                                    .padding(.horizontal, 6)
                            }
                        }
                    }

                    // Status indicator - different for API requests, chat messages, teams, and subagents
                    if isTeam {
                        Image(systemName: span.teamIcon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(teamColor)
                            .frame(width: 20)
                    } else if isSubagent {
                        Image(systemName: span.subagentIcon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(subagentColor)
                            .frame(width: 20)
                    } else if isApiRequest {
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

                    // Tool name - monospace, no decoration (wider for subagents/teams)
                    Text(toolName)
                        .font(.system(isSubagent || isTeam ? .callout : .caption, design: .monospaced))
                        .fontWeight(isSubagent || isTeam ? .semibold : .regular)
                        .foregroundStyle(
                            isTeam ? teamColor :
                            isSubagent ? subagentColor :
                            isApiRequest ? TC.sourceClaude :
                            isUserMessage ? .blue :
                            isAssistantMessage ? .purple :
                            span.isError ? TC.error : .primary
                        )
                        .lineLimit(1)
                        .frame(width: isSubagent || isTeam ? 140 : 120, alignment: .leading)

                    // Token/tools usage (compact)
                    if isTeam {
                        // Show teammates/tasks count for teams
                        if isTeamCoordinator {
                            if let teammates = span.teammateCount {
                                HStack(spacing: 2) {
                                    Image(systemName: "person.3")
                                        .font(.system(size: 9))
                                    Text("\(teammates)")
                                        .font(.system(size: 11, design: .monospaced))
                                }
                                .foregroundStyle(teamColor.opacity(0.8))
                                .frame(width: 70, alignment: .trailing)
                            } else if let completed = span.teamTasksCompleted, let total = span.teamTasksTotal {
                                Text("\(completed)/\(total)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(teamColor.opacity(0.8))
                                    .frame(width: 70, alignment: .trailing)
                            } else {
                                Spacer().frame(width: 70)
                            }
                        } else if isTeammate {
                            if let input = span.inputTokens, let output = span.outputTokens {
                                Text("\(input)→\(output)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(teamColor.opacity(0.8))
                                    .frame(width: 70, alignment: .trailing)
                            } else {
                                Spacer().frame(width: 70)
                            }
                        } else {
                            Spacer().frame(width: 70)
                        }
                    } else if isSubagent {
                        // Show tools count for subagents
                        if let toolCount = span.subagentToolCount, toolCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.system(size: 9))
                                Text("\(toolCount)")
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            .foregroundStyle(subagentColor.opacity(0.8))
                            .frame(width: 70, alignment: .trailing)
                        } else {
                            Spacer().frame(width: 70)
                        }
                    } else if isApiRequest, let tokens = span.formattedTokens {
                        Text(tokens)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    } else {
                        Spacer().frame(width: 70)
                    }

                    // Waterfall bar - simple, no gradients (colored for subagents)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            Rectangle()
                                .fill(Color.primary.opacity(0.04))

                            // Bar - solid color (use subagent/team color if applicable)
                            Rectangle()
                                .fill(
                                    span.isError ? TC.error :
                                    isTeam ? teamColor.opacity(0.6) :
                                    isSubagent ? subagentColor.opacity(0.6) :
                                    Color.primary.opacity(0.25)
                                )
                                .frame(width: max(2, geo.size.width * widthPercent))
                                .offset(x: geo.size.width * startPercent)
                        }
                    }
                    .frame(height: isSubagent || isTeam ? 20 : 16)

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
