import SwiftUI

// MARK: - Creation Tree Item
// Minimal monochromatic theme

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
            HStack(spacing: 6) {
                // Indentation
                if indentLevel > 0 {
                    Color.clear.frame(width: CGFloat(indentLevel) * 14)
                }

                // Icon - monochromatic
                Image(systemName: creation.creationType.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .frame(width: 14)

                // Name
                Text(creation.name)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.primary.opacity(isActive ? 0.9 : 0.7))
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Status - monochromatic dot
                if let status = creation.status {
                    Circle()
                        .fill(Color.primary.opacity(statusOpacity(status)))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusOpacity(_ status: CreationStatus) -> Double {
        switch status {
        case .draft: return 0.3
        case .published: return 0.7
        }
    }
}
