import SwiftUI

// MARK: - Conversation Tree Components
// Minimal monochromatic theme

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // Hash icon
                Text("#")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .frame(width: 14)

                // Title
                Text(conversation.displayTitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.primary.opacity(isSelected ? 0.9 : 0.7))
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Message count
                if let count = conversation.messageCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.35))
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}

// MARK: - Chat Section Label

struct ChatSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.primary.opacity(0.35))
            .tracking(0.5)
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 3)
    }
}
