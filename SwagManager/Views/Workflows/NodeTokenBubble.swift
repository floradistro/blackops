import SwiftUI

// MARK: - Node Token Bubble
// Compact streaming output bubble rendered below agent nodes on the workflow canvas.
// Shows accumulated SSE agentToken text with auto-scroll and typing cursor animation.

struct NodeTokenBubble: View {
    let tokens: String
    let isStreaming: Bool

    private let maxWidth: CGFloat = 200
    private let maxHeight: CGFloat = 100

    @State private var cursorVisible = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 0) {
                    Text(tokens)
                        .font(DS.Typography.monoSmall)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .textSelection(.enabled)

                    if isStreaming {
                        Text("|")
                            .font(DS.Typography.monoSmall)
                            .foregroundStyle(DS.Colors.accent)
                            .opacity(cursorVisible ? 1 : 0)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id("bottom")
            }
            .onChange(of: tokens) { _, _ in
                withAnimation(DS.Animation.fast) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .background(.ultraThinMaterial, in: bubbleShape)
        .overlay {
            bubbleShape
                .strokeBorder(DS.Colors.accent.opacity(0.3), lineWidth: 0.5)
        }
        .shadow(
            color: Color.black.opacity(0.15),
            radius: 4,
            y: 2
        )
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
        .animation(DS.Animation.medium, value: isStreaming)
        .onAppear { startCursorBlink() }
    }

    // MARK: - Private

    private var bubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DS.Radius.md)
    }

    private func startCursorBlink() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            cursorVisible = true
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Streaming") {
    VStack(spacing: DS.Spacing.lg) {
        NodeTokenBubble(
            tokens: "Checking inventory levels for Purple Haze...\nQuerying database",
            isStreaming: true
        )
        NodeTokenBubble(
            tokens: "Done. Found 24 units across 2 locations.",
            isStreaming: false
        )
    }
    .padding(DS.Spacing.xxl)
    .background(Color.black)
}
#endif
