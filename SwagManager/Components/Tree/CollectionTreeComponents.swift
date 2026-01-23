import SwiftUI

// MARK: - Collection Tree Components
// Minimal monochromatic theme

// MARK: - Collection Tree Item

struct CollectionTreeItem: View {
    let collection: CreationCollection
    let isExpanded: Bool
    var itemCount: Int = 0
    let onToggle: () -> Void

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { onToggle() }
        } label: {
            HStack(spacing: 6) {
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.15), value: isExpanded)
                    .frame(width: 10)

                // Icon
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .frame(width: 14)

                // Name
                Text(collection.name)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Count
                if itemCount > 0 {
                    Text("\(itemCount)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.35))
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}

// MARK: - Collection List Item

struct CollectionListItem: View {
    let collection: CreationCollection

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 14)

            Text(collection.name)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.75))
                .lineLimit(1)

            Spacer()

            if collection.isPublic == true {
                Image(systemName: "globe")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.primary.opacity(0.35))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
