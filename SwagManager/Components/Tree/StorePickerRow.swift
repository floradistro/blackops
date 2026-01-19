import SwiftUI

// MARK: - Store Picker Row
// Extracted from TreeItems.swift following Apple engineering standards
// File size: ~44 lines (under Apple's 300 line "excellent" threshold)

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
