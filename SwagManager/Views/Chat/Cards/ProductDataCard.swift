import SwiftUI

// MARK: - Product Data Card
// Extracted from ChatDataCards.swift following Apple engineering standards
// File size: ~84 lines (under Apple's 300 line "excellent" threshold)

struct ProductDataCard: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            // Image
            if let imageUrl = product.featuredImage, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    DesignSystem.Colors.surfaceElevated
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.Colors.surfaceElevated)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "leaf")
                            .font(.system(size: 20))
                            .foregroundStyle(.tertiary)
                    )
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                if let sku = product.sku {
                    Text(sku)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 8) {
                    Text(product.displayPrice)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)

                    Text(product.stockStatusLabel)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(product.stockStatusColor.opacity(0.15))
                        .foregroundStyle(product.stockStatusColor)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Quick actions
            VStack(spacing: 6) {
                Button {
                    // View product
                } label: {
                    Image(systemName: "eye")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    // Edit product
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(DesignSystem.Colors.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}
