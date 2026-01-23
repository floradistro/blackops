import SwiftUI

// MARK: - Sidebar Creations Section
// Premium monochromatic design

struct SidebarCreationsSection: View {
    @ObservedObject var store: EditorStore
    @Binding var expandedCollectionIds: Set<UUID>
    let filteredOrphanCreations: [Creation]
    let filteredCreationsForCollection: (UUID) -> [Creation]

    var body: some View {
        TreeSectionHeader(
            title: "Creations",
            icon: "sparkles",
            iconColor: nil,
            isExpanded: $store.sidebarCreationsExpanded,
            count: store.creations.count
        )
        .padding(.top, DesignSystem.Spacing.xxs)

        if store.sidebarCreationsExpanded {
            // Collections as folders
            ForEach(store.collections) { collection in
                let isExpanded = expandedCollectionIds.contains(collection.id)
                let collectionCreations = filteredCreationsForCollection(collection.id)

                CollectionTreeItem(
                    collection: collection,
                    isExpanded: isExpanded,
                    itemCount: collectionCreations.count,
                    onToggle: {
                        withAnimation(DesignSystem.Animation.fast) {
                            if expandedCollectionIds.contains(collection.id) {
                                expandedCollectionIds.remove(collection.id)
                            } else {
                                expandedCollectionIds.insert(collection.id)
                            }
                        }
                    }
                )
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        Task { await store.deleteCollection(collection) }
                    }
                }

                if isExpanded {
                    ForEach(collectionCreations) { creation in
                        CreationTreeItem(
                            creation: creation,
                            isSelected: store.selectedCreationIds.contains(creation.id),
                            isActive: store.selectedCreation?.id == creation.id,
                            indentLevel: 1,
                            onSelect: { store.selectCreation(creation, in: store.creations) }
                        )
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task { await store.deleteCreation(creation) }
                            }
                        }
                    }
                }
            }

            // Orphan creations
            ForEach(filteredOrphanCreations) { creation in
                CreationTreeItem(
                    creation: creation,
                    isSelected: store.selectedCreationIds.contains(creation.id),
                    isActive: store.selectedCreation?.id == creation.id,
                    indentLevel: 0,
                    onSelect: { store.selectCreation(creation, in: store.creations) }
                )
                .contextMenu {
                    if store.selectedCreationIds.count > 1 {
                        Button("Delete \(store.selectedCreationIds.count) items", role: .destructive) {
                            Task { await store.deleteSelectedCreations() }
                        }
                    } else {
                        Button("Delete", role: .destructive) {
                            Task { await store.deleteCreation(creation) }
                        }
                    }
                }
            }

            // Empty state
            if store.creations.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("No creations yet")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.primary.opacity(0.4))
                        Button {
                            store.showNewCreationSheet = true
                        } label: {
                            Text("Create one")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.primary.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }
}
