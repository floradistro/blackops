import SwiftUI

// MARK: - Chat Input Components
// Extracted from EnhancedChatView.swift following Apple engineering standards
// Contains: Message input field and reply preview
// File size: ~80 lines (under Apple's 300 line "excellent" threshold)

extension EnhancedChatView {
    // MARK: - Enhanced Message Input

    internal var enhancedMessageInput: some View {
        VStack(spacing: 0) {
            if let replyTo = chatStore.replyToMessage {
                replyPreview(replyTo)
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                TextField("Message AI assistant...", text: $chatStore.draftMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                    .lineLimit(1...6)
                    .focused($isInputFocused)
                    .onSubmit {
                        Task { await chatStore.sendMessage(supabase: store.supabase) }
                    }
                    .onChange(of: chatStore.draftMessage) { _, newValue in
                        chatStore.updateSuggestions(newValue)
                    }

                Button {
                    Task { await chatStore.sendMessage(supabase: store.supabase) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            chatStore.draftMessage.isEmpty
                                ? DesignSystem.Colors.textQuaternary
                                : DesignSystem.Colors.accent
                        )
                }
                .buttonStyle(.plain)
                .disabled(chatStore.draftMessage.isEmpty)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.surfaceTertiary)
    }

    private func replyPreview(_ message: ChatMessage) -> some View {
        HStack {
            Rectangle()
                .fill(DesignSystem.Colors.accent)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Text(message.content)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                chatStore.replyToMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: DesignSystem.IconSize.small))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.surfaceElevated)
    }
}
