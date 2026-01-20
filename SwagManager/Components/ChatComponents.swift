import SwiftUI

// MARK: - Unified Chat Message Bubble (Consolidates 4 implementations)

/// High-performance message bubble with iMessage-style design
/// Supports: user/AI messages, rich markdown, avatars, grouping, pending states
struct ChatMessageBubble: View, Equatable {
    let message: ChatMessage
    let config: BubbleConfiguration

    struct BubbleConfiguration: Equatable {
        let isFromCurrentUser: Bool
        let showAvatar: Bool
        let isFirstInGroup: Bool
        let isLastInGroup: Bool
        let isPending: Bool
        let style: BubbleStyle

        enum BubbleStyle {
            case standard      // Team chat (iMessage style)
            case enhanced      // Enhanced chat (with reactions)
            case streaming     // Streaming response
        }

        static func == (lhs: BubbleConfiguration, rhs: BubbleConfiguration) -> Bool {
            lhs.isFromCurrentUser == rhs.isFromCurrentUser &&
            lhs.showAvatar == rhs.showAvatar &&
            lhs.isFirstInGroup == rhs.isFirstInGroup &&
            lhs.isLastInGroup == rhs.isLastInGroup &&
            lhs.isPending == rhs.isPending
        }
    }

    // Equatable - only re-render if these change
    static func == (lhs: ChatMessageBubble, rhs: ChatMessageBubble) -> Bool {
        lhs.message.id == rhs.message.id && lhs.config == rhs.config
    }

    // MARK: - Computed Properties

    private var isAI: Bool {
        message.isFromAssistant
    }

    private var hasRichContent: Bool {
        let content = message.content
        return content.contains("```") ||
               content.contains("|---") ||
               content.contains("| ---") ||
               content.contains("|:--")
    }

    private var avatarColor: Color {
        if isAI { return DesignSystem.Colors.purple }
        let hash = message.senderId?.hashValue ?? 0
        let colors: [Color] = [
            DesignSystem.Colors.blue,
            DesignSystem.Colors.green,
            DesignSystem.Colors.orange,
            DesignSystem.Colors.cyan,
            DesignSystem.Colors.purple,
            DesignSystem.Colors.pink
        ]
        return colors[abs(hash) % colors.count]
    }

    private var initials: String {
        isAI ? "AI" : "U"
    }

    private var bubbleColor: Color {
        if isAI {
            return DesignSystem.Colors.surfaceElevated
        } else if config.isFromCurrentUser {
            return DesignSystem.Colors.accent
        } else {
            return DesignSystem.Colors.surfaceElevated
        }
    }

    // iMessage-style corner radii
    private var bubbleCorners: RoundedCornerShape {
        let large: CGFloat = 18
        let small: CGFloat = 4

        if config.isFromCurrentUser {
            return RoundedCornerShape(
                topLeft: large,
                topRight: config.isFirstInGroup ? large : small,
                bottomLeft: large,
                bottomRight: config.isLastInGroup ? large : small
            )
        } else {
            return RoundedCornerShape(
                topLeft: config.isFirstInGroup ? large : small,
                topRight: large,
                bottomLeft: config.isLastInGroup ? large : small,
                bottomRight: large
            )
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.sm) {
            if config.isFromCurrentUser {
                Spacer(minLength: 60)
            } else {
                avatarSection
            }

            VStack(alignment: config.isFromCurrentUser ? .trailing : .leading, spacing: DesignSystem.Spacing.xxs) {
                messageContent
                timestampSection
            }

            if !config.isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, config.isLastInGroup ? DesignSystem.Spacing.xs : 1)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var avatarSection: some View {
        if config.showAvatar && config.isLastInGroup {
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.15))
                    .frame(width: 28, height: 28)

                if isAI {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(avatarColor)
                } else {
                    Text(initials)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(avatarColor)
                }
            }
        } else {
            Color.clear.frame(width: 28, height: 28)
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if isAI && hasRichContent {
            // AI message with markdown/code/tables
            MarkdownText(message.content, isFromCurrentUser: false)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm + 2)
                .background(DesignSystem.Colors.surfaceTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                .opacity(config.isPending ? 0.6 : 1.0)
        } else if isAI {
            // Simple AI message
            MarkdownText(message.content, isFromCurrentUser: false)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(bubbleColor)
                .clipShape(bubbleCorners)
                .opacity(config.isPending ? 0.6 : 1.0)
        } else {
            // User message
            Text(message.content)
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(bubbleColor)
                .clipShape(bubbleCorners)
                .opacity(config.isPending ? 0.6 : 1.0)
        }
    }

    @ViewBuilder
    private var timestampSection: some View {
        if config.isLastInGroup, let createdAt = message.createdAt {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text(Formatters.formatTime(createdAt))
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                if config.isPending {
                    ProgressView()
                        .scaleEffect(0.5)
                        .controlSize(.mini)
                } else if config.isFromCurrentUser {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(.top, DesignSystem.Spacing.xxs)
            .padding(.horizontal, DesignSystem.Spacing.xs)
        }
    }
}

// MARK: - Rounded Corner Shape (iMessage style)

struct RoundedCornerShape: Shape {
    var topLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var bottomRight: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.size.width
        let h = rect.size.height

        let tr = min(min(topRight, h/2), w/2)
        let tl = min(min(topLeft, h/2), w/2)
        let bl = min(min(bottomLeft, h/2), w/2)
        let br = min(min(bottomRight, h/2), w/2)

        path.move(to: CGPoint(x: tl, y: 0))
        path.addLine(to: CGPoint(x: w - tr, y: 0))
        path.addArc(center: CGPoint(x: w - tr, y: tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addArc(center: CGPoint(x: w - br, y: h - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: bl, y: h))
        path.addArc(center: CGPoint(x: bl, y: h - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: tl))
        path.addArc(center: CGPoint(x: tl, y: tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()

        return path
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorBubble: View {
    @State private var animating = false
    let senderName: String?

    init(senderName: String? = nil) {
        self.senderName = senderName
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.sm) {
            // Avatar
            Circle()
                .fill(DesignSystem.Colors.surfaceElevated)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignSystem.Colors.purple)
                )

            // Typing bubble
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(DesignSystem.Colors.textTertiary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))

            Spacer(minLength: 60)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .onAppear { animating = true }
    }
}

// MARK: - Date Separator

struct ChatDateSeparator: View {
    let date: Date

    var body: some View {
        HStack {
            Spacer()
            Text(Formatters.formatDateHeader(date))
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.surfaceTertiary)
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.md)
    }
}

// MARK: - Message Grouping Utility

extension Array where Element == ChatMessage {
    /// Group messages by sender for bubble grouping
    /// Returns indices of first and last messages in each group
    func groupedIndices() -> [(first: Bool, last: Bool)] {
        guard !isEmpty else { return [] }

        var result: [(Bool, Bool)] = []

        for i in indices {
            let isFirst = i == startIndex || self[i].senderId != self[i - 1].senderId
            let isLast = i == endIndex - 1 || self[i].senderId != self[i + 1].senderId
            result.append((isFirst, isLast))
        }

        return result
    }
}

