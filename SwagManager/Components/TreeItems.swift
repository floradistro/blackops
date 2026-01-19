import SwiftUI

// MARK: - Tree Item Components
// Extracted from EditorView.swift to reduce file size and improve organization

// MARK: - Tree Item Button Style

struct TreeItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? DesignSystem.Colors.surfaceActive : Color.clear
            )
    }
}

// MARK: - Tree Section Header

struct TreeSectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool
    let count: Int

    var body: some View {
        Button {
            withAnimation(DesignSystem.Animation.spring) { isExpanded.toggle() }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(DesignSystem.Animation.fast, value: isExpanded)
                    .frame(width: 12)

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(0.5)

                Text("\(count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}

// MARK: - Category Hierarchy View (Recursive)

struct CategoryHierarchyView: View {
    let category: Category
    @ObservedObject var store: EditorStore
    @Binding var expandedCategoryIds: Set<UUID>
    var indentLevel: Int = 0

    private var isExpanded: Bool {
        expandedCategoryIds.contains(category.id)
    }

    private var isSelected: Bool {
        store.selectedCategory?.id == category.id
    }

    private var childCategories: [Category] {
        store.childCategories(of: category.id)
    }

    private var directProducts: [Product] {
        store.productsForCategory(category.id)
    }

    private var hasChildren: Bool {
        !childCategories.isEmpty || !directProducts.isEmpty
    }

    private var totalCount: Int {
        store.totalProductCount(category.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header row
            Button {
                withAnimation(DesignSystem.Animation.fast) {
                    if expandedCategoryIds.contains(category.id) {
                        expandedCategoryIds.remove(category.id)
                    } else {
                        expandedCategoryIds.insert(category.id)
                    }
                }
                store.selectCategory(category)
            } label: {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    // Chevron
                    if hasChildren {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .frame(width: 10)
                    } else {
                        Spacer().frame(width: 10)
                    }

                    Text(category.name)
                        .font(DesignSystem.Typography.caption2)
                        .lineLimit(1)

                    Spacer()

                    if totalCount > 0 {
                        Text("\(totalCount)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .padding(.trailing, DesignSystem.Spacing.xxs)
                    }
                }
                .padding(.leading, DesignSystem.Spacing.sm + CGFloat(indentLevel) * 12)
                .padding(.trailing, DesignSystem.Spacing.xxs)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(TreeItemButtonStyle())

            // Expanded content
            if isExpanded {
                ForEach(childCategories) { childCategory in
                    CategoryHierarchyView(
                        category: childCategory,
                        store: store,
                        expandedCategoryIds: $expandedCategoryIds,
                        indentLevel: indentLevel + 1
                    )
                }

                ForEach(directProducts) { product in
                    ProductTreeItem(
                        product: product,
                        isSelected: store.selectedProductIds.contains(product.id),
                        isActive: store.selectedProduct?.id == product.id,
                        indentLevel: indentLevel + 2,
                        onSelect: { store.selectProduct(product) }
                    )
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            Task { await store.deleteProduct(product) }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Category Tree Item (Simple)

struct CategoryTreeItem: View {
    let category: Category
    let isExpanded: Bool
    var itemCount: Int = 0
    var indentLevel: Int = 0
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            Image(systemName: category.icon ?? (isExpanded ? "folder.fill" : "folder"))
                .font(.system(size: 9))
                .foregroundStyle(.green)
                .frame(width: 14)

            Text(category.name)
                .font(DesignSystem.Typography.caption2)
                .lineLimit(1)

            Spacer()

            if itemCount > 0 {
                Text("\(itemCount)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, DesignSystem.Spacing.xxs)
            }
        }
        .padding(.leading, DesignSystem.Spacing.sm + CGFloat(indentLevel) * 16)
        .padding(.trailing, DesignSystem.Spacing.xxs)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}

// MARK: - Product Tree Item

struct ProductTreeItem: View {
    let product: Product
    let isSelected: Bool
    let isActive: Bool
    var indentLevel: Int = 0
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignSystem.Colors.success)
                    .frame(width: 14)

                Text(product.name)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()

                Text(product.displayPrice)
                    .font(.system(size: 9))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Circle()
                    .fill(product.stockStatusColor)
                    .frame(width: 6, height: 6)
            }
            .padding(.leading, DesignSystem.Spacing.sm + CGFloat(min(indentLevel, 2)) * 12)
            .padding(.trailing, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isActive ? DesignSystem.Colors.selectionActive :
                          isSelected ? DesignSystem.Colors.selection : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}

// MARK: - Collection Tree Item

struct CollectionTreeItem: View {
    let collection: CreationCollection
    let isExpanded: Bool
    var itemCount: Int = 0
    let onToggle: () -> Void

    var body: some View {
        Button {
            withAnimation(DesignSystem.Animation.spring) { onToggle() }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(DesignSystem.Animation.fast, value: isExpanded)
                    .frame(width: 10)

                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.warning)

                Text(collection.name)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                if itemCount > 0 {
                    Text("\(itemCount)")
                        .font(.system(size: 9))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}

// MARK: - Creation Tree Item

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
            HStack(spacing: DesignSystem.Spacing.sm) {
                if indentLevel > 0 {
                    Spacer().frame(width: CGFloat(indentLevel * 16))
                }

                Image(systemName: creation.creationType.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(creation.creationType.color)
                    .frame(width: 16)

                Text(creation.name)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()

                if let status = creation.status {
                    Circle()
                        .fill(status.color)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isActive ? DesignSystem.Colors.selectionActive :
                          isSelected ? DesignSystem.Colors.selection : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
    }
}

// MARK: - Catalog Row

struct CatalogRow: View {
    let catalog: Catalog
    let isExpanded: Bool
    let itemCount: Int?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)

                Text(catalog.name)
                    .font(DesignSystem.Typography.caption2)
                    .lineLimit(1)

                Spacer()

                if let count = itemCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text("#")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)

                Text(conversation.displayTitle)
                    .font(DesignSystem.Typography.caption2)
                    .lineLimit(1)

                Spacer()

                if let count = conversation.messageCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(TreeItemButtonStyle())
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }
}

// MARK: - Chat Section Label

struct ChatSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(DesignSystem.Colors.textTertiary)
            .tracking(0.5)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.xs)
            .padding(.bottom, 3)
    }
}

// MARK: - Store Picker Row

struct StorePickerRow: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        Menu {
            ForEach(store.stores) { s in
                Button {
                    Task { await store.selectStore(s) }
                } label: {
                    HStack {
                        Text(s.storeName)
                        if store.selectedStore?.id == s.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: "storefront")
                    .font(.system(size: 9))
                    .foregroundStyle(.green)

                Text(store.selectedStore?.storeName ?? "Select Store")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 5)
            .background(DesignSystem.Colors.surfaceTertiary)
            .cornerRadius(DesignSystem.Radius.sm)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.bottom, DesignSystem.Spacing.xxs)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.caption1)
                .padding(.horizontal, DesignSystem.Spacing.xs)
                .padding(.vertical, 2)
                .background(isSelected ? Color.accentColor : DesignSystem.Colors.surfaceElevated)
                .foregroundStyle(isSelected ? .white : .secondary)
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collection List Item

struct CollectionListItem: View {
    let collection: CreationCollection

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "folder.fill")
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(.orange)
                .frame(width: 16)

            Text(collection.name)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            if collection.isPublic == true {
                Image(systemName: "globe")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .cornerRadius(DesignSystem.Radius.sm)
    }
}
