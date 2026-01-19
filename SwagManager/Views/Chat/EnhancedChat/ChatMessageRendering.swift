import SwiftUI

// MARK: - Chat Message Rendering
// Extracted from EnhancedChatView.swift following Apple engineering standards
// Contains: Message list with scrolling and date grouping
// File size: ~55 lines (under Apple's 300 line "excellent" threshold)

extension EnhancedChatView {
    // MARK: - Message List (OPTIMIZED with LazyVStack)

    internal var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    let groups = Formatters.groupMessagesByDate(chatStore.messages) { $0.createdAt }

                    ForEach(groups) { group in
                        ChatDateSeparator(date: group.date)

                        let groupIndices = group.items.groupedIndices()

                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, message in
                            let grouping = groupIndices[index]
                            let isPending = chatStore.pendingMessageIds.contains(message.id)

                            ChatMessageBubble(
                                message: message,
                                config: .init(
                                    isFromCurrentUser: message.senderId == chatStore.currentUserId,
                                    showAvatar: true,
                                    isFirstInGroup: grouping.first,
                                    isLastInGroup: grouping.last,
                                    isPending: isPending,
                                    style: .enhanced
                                )
                            )
                        }
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .scrollBounceBehavior(.always)
            .onChange(of: shouldScrollToBottom) { _, shouldScroll in
                if shouldScroll {
                    withAnimation(DesignSystem.Animation.medium) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    shouldScrollToBottom = false
                }
            }
            .onChange(of: chatStore.messages.count) { _, _ in
                shouldScrollToBottom = true
            }
        }
    }
}
