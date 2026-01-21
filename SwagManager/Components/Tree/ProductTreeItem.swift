import SwiftUI
import UniformTypeIdentifiers

// MARK: - Product Tree Item
// Extracted from TreeItems.swift following Apple engineering standards
// File size: ~47 lines (under Apple's 300 line "excellent" threshold)

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
        HStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Colors.success)
                .frame(width: 16)

            Text(product.name)
                .font(.system(size: 13))
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(product.displayPrice)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Circle()
                .fill(product.stockStatusColor)
                .frame(width: 6, height: 6)
        }
        .padding(.leading, 16 + CGFloat(indentLevel) * 16)
        .padding(.trailing, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((isActive || isMultiSelected) ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleClick()
        }
        .onDrag {
            print("🚀 Starting drag for product: \(product.name) (\(product.id))")
            let dragString = DragItemType.encode(.product, uuid: product.id)
            print("🔑 Drag data: \(dragString)")

            let provider = NSItemProvider(object: dragString as NSString)
            print("✅ NSItemProvider created successfully")
            return provider
        }
    }

    private func handleClick() {
        let modifiers = NSEvent.modifierFlags

        if modifiers.contains(.command) {
            // Cmd+Click: Toggle in multi-select
            if editorStore.selectedProductIds.contains(product.id) {
                editorStore.selectedProductIds.remove(product.id)
            } else {
                editorStore.selectedProductIds.insert(product.id)
            }
        } else if modifiers.contains(.shift) {
            // Shift+Click: Range select (simplified - just add to selection)
            editorStore.selectedProductIds.insert(product.id)
        } else {
            // Regular click: Select only this item
            editorStore.selectedProductIds = [product.id]
            onSelect()
        }
    }
}
