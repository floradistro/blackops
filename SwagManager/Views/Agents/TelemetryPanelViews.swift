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

                // Status + time + cost
                VStack(alignment: .trailing, spacing: 2) {
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

                        if let cost = session.formattedCost {
                            Text(cost)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(TC.warning)
                        } else {
                            Text(session.formattedDuration)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(session.endTime ?? session.startTime, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            isSelected
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1)
                .fill(
                    session.hasErrors ? TC.error :
                    isLive ? TC.success :
                    session.isTeamCoordinator ? TC.success.opacity(0.7) :
                    Color.clear
                )
                .frame(width: 3)
                .padding(.vertical, 4)
        }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(session.id, forType: .string)
            } label: {
                Label("Copy Session ID", systemImage: "doc.on.doc")
            }
            Button {
                let summary = "\(session.userName ?? session.userEmail ?? "User") · \(session.turnCount) turns · \(session.formattedDuration)"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(summary, forType: .string)
            } label: {
                Label("Copy Summary", systemImage: "text.clipboard")
            }
        }
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
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1)
                .fill(session.hasErrors ? TC.error : (isLive ? TC.success : TC.success.opacity(0.3)))
                .frame(width: 3)
                .padding(.vertical, 2)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(session.id, forType: .string)
            } label: {
                Label("Copy Session ID", systemImage: "doc.on.doc")
            }
        }
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
                        if isAssistantMessage {
                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.purple.opacity(0.5))
                        } else {
                            Text("└─")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.quaternary)
                        }
                        Text(activity)
                            .font(.system(size: isChatMessage ? 12 : 11))
                            .foregroundStyle(
                                span.isError ? TC.error :
                                isChatMessage ? .primary :
                                .secondary
                            )
                            .lineLimit(isAssistantMessage ? 8 : (isUserMessage ? nil : 1))
                            .truncationMode(.tail)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 12)
                    .padding(.vertical, isChatMessage ? 4 : 0)
                    .background(
                        isAssistantMessage ? Color.purple.opacity(0.03) :
                        isUserMessage ? Color.blue.opacity(0.03) :
                        Color.clear
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

// MARK: - Team Members Section (Center Panel)

struct TeamMembersSection: View {
    let session: TelemetrySession
    @Binding var selectedSessionId: String?
    @Binding var expandedChildAgentIds: Set<String>
    @Binding var expandedChildTraceIds: Set<String>
    @Binding var pinnedSpan: TelemetrySpan?
    @Binding var autoExpandedTeamSections: Set<String>
    let isSessionLive: (TelemetrySession) -> Bool

    @State private var showTimeline: Bool = false

    private var isTeamExpanded: Bool {
        expandedChildAgentIds.contains(session.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            teamHeader
            if isTeamExpanded {
                Divider().padding(.leading, 12)
                if showTimeline {
                    TeamTimelineView(
                        session: session,
                        selectedSessionId: $selectedSessionId,
                        pinnedSpan: $pinnedSpan,
                        isSessionLive: isSessionLive
                    )
                } else {
                    teamChildList
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(TC.success.opacity(0.03))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [TC.success.opacity(0.8), TC.success.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(TC.success.opacity(0.12), lineWidth: 1)
        )
        .onAppear {
            if session.childSessions.count <= 5 && !autoExpandedTeamSections.contains(session.id) {
                autoExpandedTeamSections.insert(session.id)
                expandedChildAgentIds.insert(session.id)
            }
        }
    }

    private var teamHeader: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                if expandedChildAgentIds.contains(session.id) {
                    expandedChildAgentIds.remove(session.id)
                } else {
                    expandedChildAgentIds.insert(session.id)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isTeamExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(TC.success)

                Text("TEAM")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(TC.success)

                Text("\(session.childSessions.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                if session.childrenCompletedCount > 0 {
                    Text("\(session.childrenCompletedCount)/\(session.childSessions.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(TC.success.opacity(0.8))
                }

                if session.childrenErrorCount > 0 {
                    Text("\(session.childrenErrorCount)err")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(TC.error)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(TC.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                Spacer()

                // View mode toggle — only show when expanded
                if isTeamExpanded {
                    HStack(spacing: 0) {
                        viewModeButton(label: "Members", icon: "person.2", active: !showTimeline) {
                            showTimeline = false
                        }
                        viewModeButton(label: "Timeline", icon: "clock.arrow.circlepath", active: showTimeline) {
                            showTimeline = true
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }

                if session.childrenTotalCost > 0 {
                    Text(String(format: "$%.4f", session.childrenTotalCost))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(TC.warning)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(TC.success.opacity(isTeamExpanded ? 0.04 : 0))
        }
        .buttonStyle(.plain)
    }

    private func viewModeButton(label: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(label)
                    .font(.system(size: 9, weight: active ? .semibold : .regular, design: .monospaced))
            }
            .foregroundStyle(active ? TC.success : Color.primary.opacity(0.3))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(active ? TC.success.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var teamChildList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(session.childSessions) { child in
                TeamMemberRow(
                    child: child,
                    selectedSessionId: $selectedSessionId,
                    expandedChildAgentIds: $expandedChildAgentIds,
                    isSessionLive: isSessionLive
                )

                if expandedChildAgentIds.contains(child.id) {
                    ChildTraceView(
                        child: child,
                        selectedSessionId: $selectedSessionId,
                        expandedChildTraceIds: $expandedChildTraceIds,
                        expandedChildAgentIds: $expandedChildAgentIds,
                        pinnedSpan: $pinnedSpan,
                        autoExpandedTeamSections: $autoExpandedTeamSections,
                        isSessionLive: isSessionLive
                    )
                }

                if child.id != session.childSessions.last?.id {
                    Divider().padding(.leading, 36)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: session.childSessions.count)

            if isSessionLive(session) && !session.allSpans.contains(where: { $0.action == "team.complete" }) {
                Divider().padding(.leading, 36)
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Team in progress...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Team Timeline View (Unified Chronological)

/// Interleaves all child agents' spans chronologically to show the flow of work
struct TeamTimelineView: View {
    let session: TelemetrySession
    @Binding var selectedSessionId: String?
    @Binding var pinnedSpan: TelemetrySpan?
    let isSessionLive: (TelemetrySession) -> Bool

    /// A timeline entry combining a span with its agent context
    private struct TimelineEntry: Identifiable {
        let id: UUID
        let span: TelemetrySpan
        let agentName: String
        let agentIndex: Int  // for consistent color assignment
        let sessionId: String
    }

    /// Stable agent color palette
    private static let agentColors: [Color] = [
        .blue, .purple, .orange, .cyan, .pink, .mint, .indigo, .teal
    ]

    private func agentColor(for index: Int) -> Color {
        Self.agentColors[index % Self.agentColors.count]
    }

    /// Build interleaved timeline entries from all child sessions
    private var timelineEntries: [TimelineEntry] {
        var entries: [TimelineEntry] = []

        for (agentIndex, child) in session.childSessions.enumerated() {
            let name = child.teammateName ?? child.agentName ?? "Agent \(agentIndex + 1)"
            for span in child.allSpans where !span.isWaterfallHidden {
                entries.append(TimelineEntry(
                    id: span.id,
                    span: span,
                    agentName: name,
                    agentIndex: agentIndex,
                    sessionId: child.id
                ))
            }
        }

        return entries.sorted { $0.span.createdAt < $1.span.createdAt }
    }

    /// Unique agent names for the legend
    private var agentLegend: [(name: String, index: Int)] {
        session.childSessions.enumerated().map { index, child in
            (name: child.teammateName ?? child.agentName ?? "Agent \(index + 1)", index: index)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Agent legend bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(agentLegend, id: \.index) { agent in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(agentColor(for: agent.index))
                                .frame(width: 6, height: 6)
                            Text(agent.name)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(agentColor(for: agent.index).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider().padding(.leading, 12)

            // Timeline entries
            let entries = timelineEntries
            if entries.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 16))
                            .foregroundStyle(.quaternary)
                        Text("No activity yet")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                ForEach(entries) { entry in
                    timelineRow(entry: entry)
                }
            }

            if isSessionLive(session) {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Live...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private func timelineRow(entry: TimelineEntry) -> some View {
        let color = agentColor(for: entry.agentIndex)
        let span = entry.span

        Button {
            pinnedSpan = span
        } label: {
            HStack(spacing: 0) {
                // Agent color lane indicator
                Rectangle()
                    .fill(color)
                    .frame(width: 3)
                    .padding(.vertical, 1)

                HStack(spacing: 6) {
                    // Timestamp
                    Text(span.createdAt, format: .dateTime.hour().minute().second())
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .frame(width: 56, alignment: .trailing)

                    // Agent badge
                    Text(String(entry.agentName.prefix(3)).uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                        .frame(width: 28)

                    // Status icon
                    if span.isApiRequest {
                        Text("\u{25C6}")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(TC.sourceClaude)
                            .frame(width: 14)
                    } else if span.isToolSpan {
                        Text("\u{2713}")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(span.isError ? TC.error : TC.success)
                            .frame(width: 14)
                    } else if span.isTeam {
                        Image(systemName: span.teamIcon)
                            .font(.system(size: 9))
                            .foregroundStyle(TC.success)
                            .frame(width: 14)
                    } else if span.action == "chat.user_message" {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.blue)
                            .frame(width: 14)
                    } else {
                        Text("\u{2022}")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .frame(width: 14)
                    }

                    // Action name
                    Text(span.toolName ?? span.shortModelName ?? span.action)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(span.isError ? TC.error : .primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    // Tokens for API requests
                    if span.isApiRequest, let tokens = span.formattedTokens {
                        Text(tokens)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    // Duration
                    if let ms = span.durationMs, ms > 0 {
                        Text(span.formattedDuration)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
            }
            .contentShape(Rectangle())
            .background(
                pinnedSpan?.id == span.id
                    ? color.opacity(0.06)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Team Member Row

struct TeamMemberRow: View {
    let child: TelemetrySession
    @Binding var selectedSessionId: String?
    @Binding var expandedChildAgentIds: Set<String>
    let isSessionLive: (TelemetrySession) -> Bool

    @State private var isHovering = false

    private var statusColor: Color {
        child.hasErrors ? TC.error :
        isSessionLive(child) ? TC.success :
        child.endTime != nil ? TC.success.opacity(0.6) :
        Color.primary.opacity(0.3)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Main row — tap to expand/collapse inline traces
            rowContent
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        if expandedChildAgentIds.contains(child.id) {
                            expandedChildAgentIds.remove(child.id)
                        } else {
                            expandedChildAgentIds.insert(child.id)
                        }
                    }
                }

            // Navigate to full session detail
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedSessionId = child.id
                }
            } label: {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(isHovering ? TC.success : Color.primary.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open full session")
            .onHover { isHovering = $0 }
            .padding(.trailing, 4)
        }
        .background(
            child.hasErrors ? TC.error.opacity(0.03) :
            expandedChildAgentIds.contains(child.id) ? Color.primary.opacity(0.02) :
            Color.clear
        )
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            // Expand chevron
            Image(systemName: expandedChildAgentIds.contains(child.id) ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            // Avatar with status ring
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 26, height: 26)

                if isSessionLive(child) {
                    Circle()
                        .stroke(TC.success.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                }

                Text(String((child.teammateName ?? "A").prefix(1)).uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusColor)
            }

            // Name + summary
            VStack(alignment: .leading, spacing: 1) {
                Text(child.teammateName ?? "Agent")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(child.turnCount) turn\(child.turnCount == 1 ? "" : "s")")
                        .font(.system(size: 10, design: .monospaced))

                    let tools = child.allSpans.compactMap { $0.toolName }
                    let uniqueTools = Set(tools)
                    if !uniqueTools.isEmpty {
                        Text("\u{00B7}")
                        Text(uniqueTools.prefix(2).joined(separator: ", "))
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)

            // Status + duration cluster
            HStack(spacing: 6) {
                if child.hasErrors {
                    HStack(spacing: 2) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                        Text("\(child.errorCount)")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(TC.error)
                } else if isSessionLive(child) {
                    Circle()
                        .fill(TC.success)
                        .frame(width: 6, height: 6)
                        .modifier(PulseModifier())
                } else if child.endTime != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(TC.success.opacity(0.6))
                }

                Text(child.formattedDuration)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Child Trace View

struct ChildTraceView: View {
    let child: TelemetrySession
    @Binding var selectedSessionId: String?
    @Binding var expandedChildTraceIds: Set<String>
    @Binding var expandedChildAgentIds: Set<String>
    @Binding var pinnedSpan: TelemetrySpan?
    @Binding var autoExpandedTeamSections: Set<String>
    let isSessionLive: (TelemetrySession) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(child.traces.enumerated()), id: \.element.id) { index, trace in
                childTraceRow(trace: trace, index: index)
            }

            if child.isTeamCoordinator {
                TeamMembersSection(
                    session: child,
                    selectedSessionId: $selectedSessionId,
                    expandedChildAgentIds: $expandedChildAgentIds,
                    expandedChildTraceIds: $expandedChildTraceIds,
                    pinnedSpan: $pinnedSpan,
                    autoExpandedTeamSections: $autoExpandedTeamSections,
                    isSessionLive: isSessionLive
                )
                .padding(.leading, 16)
                .padding(.top, 4)
            }
        }
        .padding(.leading, 24)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(TC.success.opacity(0.15))
                .frame(width: 2)
                .padding(.leading, 12)
        }
    }

    @ViewBuilder
    private func childTraceRow(trace: Trace, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                if expandedChildTraceIds.contains(trace.id) {
                    expandedChildTraceIds.remove(trace.id)
                } else {
                    expandedChildTraceIds.insert(trace.id)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: expandedChildTraceIds.contains(trace.id) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.quaternary)
                    .frame(width: 10)

                Text("Turn \(index + 1)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(trace.hasErrors ? "ERR" : "OK")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(trace.hasErrors ? TC.error : TC.success)

                let tools = trace.waterfallSpans.compactMap { $0.toolName }
                let uniqueTools = Set(tools)
                if !tools.isEmpty {
                    Text("\u{00B7} \(tools.count) calls (\(uniqueTools.prefix(2).joined(separator: ", ")))")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                if let cost = trace.formattedCost {
                    Text(cost)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(TC.warning)
                }

                if let duration = trace.duration, duration > 0.001 {
                    Text(trace.formattedDuration)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if expandedChildTraceIds.contains(trace.id) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(trace.waterfallSpans) { span in
                    SpanRow(
                        span: span,
                        traceStart: trace.startTime,
                        traceDuration: trace.duration ?? 1,
                        isSelected: pinnedSpan?.id == span.id,
                        onSelect: { pinnedSpan = span }
                    )
                }
            }
            .padding(.leading, 16)
        }
    }
}

// MARK: - Span Detail Content View

struct SpanDetailContentView: View {
    let span: TelemetrySpan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            coreMetadata
            aiTelemetrySection
            toolContextSection
            compactionSection
            retrySection
            toolInputSection
            toolOutputSection
            errorSection
            attributesSection
        }
    }

    private var coreMetadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailRow("span_id", span.id.uuidString)
            if let parentId = span.parentId {
                detailRow("parent_id", parentId.uuidString)
            }
            detailRow("source", span.source)
            detailRow("severity", span.severity)
            detailRow("duration_ms", "\(span.durationMs ?? 0)")
            detailRow("timestamp", span.createdAt.formatted(date: .abbreviated, time: .standard))

            if let traceId = span.otelTraceId {
                detailRow("trace_id", traceId)
            }
            if let spanId = span.otelSpanId {
                detailRow("w3c_span_id", spanId)
            }
            if let kind = span.otelSpanKind {
                detailRow("span_kind", kind)
            }
            if let service = span.otelServiceName {
                detailRow("service", service)
            }
        }
    }

    @ViewBuilder
    private var aiTelemetrySection: some View {
        if span.isApiRequest {
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("AI TELEMETRY")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)

                if let model = span.model { detailRow("model", model) }
                if let tokens = span.formattedTokens { detailRow("tokens", tokens) }
                if let input = span.inputTokens { detailRow("input_tokens", "\(input)") }
                if let output = span.outputTokens { detailRow("output_tokens", "\(output)") }
                if let cacheRead = span.cacheReadTokens, cacheRead > 0 { detailRow("cache_read", "\(cacheRead)") }
                if let cacheCreate = span.cacheCreationTokens, cacheCreate > 0 { detailRow("cache_create", "\(cacheCreate)") }
                if let cost = span.formattedCost { detailRow("cost", cost) }
                if let turn = span.turnNumber { detailRow("turn", "\(turn)") }
                if let stop = span.stopReason { detailRow("stop_reason", stop) }
                if let iter = span.iteration { detailRow("iteration", "\(iter)") }
                if let tc = span.toolCount, tc > 0 { detailRow("tool_count", "\(tc)") }
                if let names = span.toolNames, !names.isEmpty { detailRow("tools", names.joined(separator: ", ")) }
            }
        }
    }

    @ViewBuilder
    private var toolContextSection: some View {
        if span.isToolSpan {
            if let desc = span.toolDescription { detailRow("description", desc) }
            if let iter = span.iteration { detailRow("iteration", "\(iter)") }
            if let errType = span.errorType { detailRow("error_type", errType) }
        }
    }

    @ViewBuilder
    private var compactionSection: some View {
        if span.isContextCompaction {
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("COMPACTION")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                if let before = span.compactionMessagesBefore { detailRow("messages_before", "\(before)") }
                if let after = span.compactionMessagesAfter { detailRow("messages_after", "\(after)") }
                if let saved = span.compactionTokensSaved { detailRow("tokens_saved", "\(saved)") }
            }
        }
    }

    @ViewBuilder
    private var retrySection: some View {
        if span.isApiRetry {
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("RETRY")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                if let attempt = span.details?["attempt"]?.value as? Int { detailRow("attempt", "\(attempt)") }
                if let errType = span.errorType { detailRow("error_type", errType) }
            }
        }
    }

    @ViewBuilder
    private var toolInputSection: some View {
        if span.isToolSpan, let input = span.toolInput, !input.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("TOOL INPUT")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if let bytes = span.inputBytes {
                        Text("\(bytes)B")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                    Button {
                        let json = (try? JSONSerialization.data(withJSONObject: input, options: .prettyPrinted))
                            .flatMap { String(data: $0, encoding: .utf8) } ?? "\(input)"
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(json, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(Array(input.keys.sorted()), id: \.self) { key in
                    HStack(alignment: .top, spacing: 8) {
                        Text(key)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(TC.jsonKey)
                            .frame(width: 80, alignment: .trailing)
                        FormattedValueView(value: input[key])
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var toolOutputSection: some View {
        if span.isToolSpan {
            if let error = span.toolError {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOOL OUTPUT")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Text(error)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(TC.error)
                        .textSelection(.enabled)
                }
            } else if let result = span.toolResult {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("TOOL OUTPUT")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        if let bytes = span.outputBytes {
                            Text("\(bytes)B")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.quaternary)
                        }
                        Button {
                            let str: String
                            if let dict = result as? [String: Any] {
                                str = (try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted))
                                    .flatMap { String(data: $0, encoding: .utf8) } ?? "\(dict)"
                            } else { str = "\(result)" }
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(str, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    if let dict = result as? [String: Any] {
                        ForEach(Array(dict.keys.sorted().prefix(20)), id: \.self) { key in
                            HStack(alignment: .top, spacing: 8) {
                                Text(key)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(TC.jsonKey)
                                    .frame(width: 80, alignment: .trailing)
                                FormattedValueView(value: dict[key])
                                    .textSelection(.enabled)
                            }
                        }
                    } else if let str = result as? String {
                        Text(str.prefix(500))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            if let cost = span.formattedMarginalCost { detailRow("turn_cost", cost) }
            if let payload = span.formattedPayloadSize { detailRow("payload", payload) }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = span.errorMessage {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("ERROR")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(TC.error)
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TC.error)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var attributesSection: some View {
        if let details = span.details, !details.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("ATTRIBUTES")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                ExpandableJSON(details: details)
            }
        }
    }

    private func detailRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Formatted Value View

struct FormattedValueView: View {
    let value: Any?

    var body: some View {
        if let str = value as? String {
            Text(str)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(TC.jsonString)
        } else if let num = value as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                Text(num.boolValue ? "true" : "false")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TC.jsonBool)
            } else {
                Text("\(num)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TC.jsonNumber)
            }
        } else if let bool = value as? Bool {
            Text(bool ? "true" : "false")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(TC.jsonBool)
        } else if let int = value as? Int {
            Text("\(int)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(TC.jsonNumber)
        } else if let double = value as? Double {
            Text(String(format: "%.2f", double))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(TC.jsonNumber)
        } else if let dict = value as? [String: Any] {
            Text("{\(dict.count) keys}")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        } else if let arr = value as? [Any] {
            Text("[\(arr.count) items]")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        } else if value == nil {
            Text("null")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.quaternary)
        } else {
            Text("\(String(describing: value))")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Pinned Span Panel (full-height 3rd column)

struct PinnedSpanPanel: View {
    let span: TelemetrySpan
    @Binding var pinnedSpan: TelemetrySpan?
    let comparison: SpanComparison?
    @Environment(\.telemetryService) private var telemetry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader
            if let comparison = comparison {
                SpanComparisonBar(span: span, comparison: comparison)
            }
            Divider()
            ScrollView {
                SpanDetailContentView(span: span)
                    .padding(16)
            }
        }
        .background(VibrancyBackground())
        .task(id: span.id) {
            if span.isToolSpan {
                await telemetry.fetchSpanComparison(spanId: span.id)
            }
        }
    }

    private var panelHeader: some View {
        HStack(spacing: 8) {
            Text(span.isError ? "ERR" : "OK")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(span.isError ? TC.error : TC.success)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background((span.isError ? TC.error : TC.success).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text(span.toolName ?? span.action)
                .font(.system(.subheadline, design: .monospaced, weight: .medium))

            Spacer()

            Text(span.formattedDuration)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)

            Button {
                pinnedSpan = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Span Comparison Bar

struct SpanComparisonBar: View {
    let span: TelemetrySpan
    let comparison: SpanComparison

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: comparison.isSlow ? "exclamationmark.triangle.fill" : "gauge.with.dots.needle.33percent")
                    .font(.system(size: 10))
                    .foregroundStyle(comparison.isSlow ? TC.error : TC.success)
                Text("P\(Int(comparison.percentileRank))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(comparison.isSlow ? TC.error : .primary)
            }

            Divider().frame(height: 14)

            HStack(spacing: 4) {
                Text("avg")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(formatMs(comparison.avgMs))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Text("p95")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(formatMs(comparison.p95Ms))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 14)

            HStack(spacing: 4) {
                Text("err")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(String(format: "%.1f%%", comparison.errorRate))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(comparison.errorRate > 5 ? TC.error : .secondary)
            }

            HStack(spacing: 4) {
                Text("24h")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text("\(comparison.totalCalls24h)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if comparison.isSlow {
                Text("SLOW")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(TC.error)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(TC.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(comparison.isSlow ? TC.error.opacity(0.04) : Color.primary.opacity(0.02))
    }

    private func formatMs(_ ms: Double) -> String {
        if ms < 1000 {
            return String(format: "%.0fms", ms)
        }
        return String(format: "%.2fs", ms / 1000)
    }
}
