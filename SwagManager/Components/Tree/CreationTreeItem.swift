import SwiftUI

// MARK: - Creation Tree Item
// Extracted from TreeItems.swift following Apple engineering standards
// File size: ~48 lines (under Apple's 300 line "excellent" threshold)

struct CreationTreeItem: View {
    let creation: Creation
    let isSelected: Bool
    let isActive: Bool
    var indentLevel: Int = 0
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: creation.creationType.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(creation.creationType.color)
                    .frame(width: 16)

                Text(creation.name)
                    .font(.system(size: 13))
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let status = creation.status {
                    Circle()
                        .fill(status.color)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.leading, 16 + CGFloat(indentLevel) * 16)
            .padding(.trailing, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
