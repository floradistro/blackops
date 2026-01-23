import SwiftUI

// MARK: - Catalog Row
// Minimal monochromatic theme

struct CatalogRow: View {
    let catalog: Catalog
    let isExpanded: Bool
    let itemCount: Int?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)

                // Icon
                Image(systemName: "tray.full")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .frame(width: 14)

                // Name
                Text(catalog.name)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Count
                if let count = itemCount, count > 0 {
                    Text("\(count)")
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
