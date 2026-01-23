import SwiftUI
import UniformTypeIdentifiers

// MARK: - Product Tree Item
// Minimal monochromatic theme

struct ProductTreeItem: View {
    let product: Product
    let isSelected: Bool
    let isActive: Bool
    var indentLevel: Int = 0
    let onSelect: () -> Void
    @EnvironmentObject private var editorStore: EditorStore

    private var isMultiSelected: Bool {
        editorStore.selectedProductIds.contains(product.id)
    }

    var body: some View {
        HStack(spacing: 6) {
            // Indentation
            if indentLevel > 0 {
                Color.clear.frame(width: CGFloat(indentLevel) * 14)
            }

            // Icon - monochromatic
            Image(systemName: "leaf.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 14)

            // Name
            Text(product.name)
                .font(.system(size: 10.5))
                .foregroundStyle(Color.primary.opacity(isActive ? 0.9 : 0.7))
                .lineLimit(1)

            Spacer(minLength: 4)

            // Price
            Text(product.displayPrice)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.4))

            // Stock status - monochromatic dot
            Circle()
                .fill(Color.primary.opacity(stockOpacity))
                .frame(width: 5, height: 5)
        }
        .frame(height: 24)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill((isActive || isMultiSelected) ? Color.primary.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleClick()
        }
        .onDrag {
            let dragString = DragItemType.encode(.product, uuid: product.id)
            let provider = NSItemProvider(object: dragString as NSString)
            return provider
        }
    }

    private var stockOpacity: Double {
        // Convert stock status to opacity
        if product.stockQuantity == nil || product.stockQuantity == 0 {
            return 0.2 // Out of stock
        } else if (product.stockQuantity ?? 0) < 10 {
            return 0.4 // Low stock
        } else {
            return 0.6 // In stock
        }
    }

    private func handleClick() {
        let modifiers = NSEvent.modifierFlags

        if modifiers.contains(.command) {
            if editorStore.selectedProductIds.contains(product.id) {
                editorStore.selectedProductIds.remove(product.id)
            } else {
                editorStore.selectedProductIds.insert(product.id)
            }
        } else if modifiers.contains(.shift) {
            editorStore.selectedProductIds.insert(product.id)
        } else {
            editorStore.selectedProductIds = [product.id]
            onSelect()
        }
    }
}
