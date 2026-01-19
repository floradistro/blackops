import SwiftUI
import Supabase

// MARK: - Editor Sidebar View
// Extracted from EditorView.swift to improve file organization

struct SidebarPanel: View {
    @ObservedObject var store: EditorStore
    @Binding var sidebarCollapsed: Bool
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var expandedCollectionIds: Set<UUID> = []
    @State private var expandedCategoryIds: Set<UUID> = []
    @FocusState private var isSearchFocused: Bool

    var filteredCreations: [Creation] {
        if debouncedSearchText.isEmpty { return store.creations }
        return store.creations.filter { $0.name.localizedCaseInsensitiveContains(debouncedSearchText) }
    }

    var filteredOrphanCreations: [Creation] {
        if debouncedSearchText.isEmpty { return store.orphanCreations }
        return store.orphanCreations.filter { $0.name.localizedCaseInsensitiveContains(debouncedSearchText) }
    }

    func filteredCreationsForCollection(_ collectionId: UUID) -> [Creation] {
        let creations = store.creationsForCollection(collectionId)
        if debouncedSearchText.isEmpty { return creations }
        return creations.filter { $0.name.localizedCaseInsensitiveContains(debouncedSearchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button {
                        withAnimation(DesignSystem.Animation.fast) { searchText = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 5)
            .background(DesignSystem.Colors.surfaceSecondary)

            Rectangle()
                .fill(DesignSystem.Colors.border)
                .frame(height: 1)

            // Content tree
            if store.selectedStore == nil && store.stores.isEmpty {
                emptyStoreState
            } else if store.isLoading {
                loadingState
            } else {
                sidebarContent
            }
        }
        .background(VisualEffectBackground(material: .sidebar))
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSearch"))) { _ in
            isSearchFocused = true
        }
        .task {
            if store.selectedStore != nil && store.browserSessions.isEmpty {
                await store.loadBrowserSessions()
            }
        }
        .onChange(of: store.selectedStore?.id) { _, _ in
            Task {
                await store.loadBrowserSessions()
            }
        }
        .onChange(of: searchText) { _, newValue in
            // Cancel previous search task
            searchTask?.cancel()

            // If empty, update immediately
            if newValue.isEmpty {
                debouncedSearchText = ""
                return
            }

            // Otherwise, debounce for 300ms
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                if !Task.isCancelled {
                    debouncedSearchText = newValue
                }
            }
        }
    }

    // MARK: - Empty Store State

    @ViewBuilder
    private var emptyStoreState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "building.2")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textQuaternary)

            Text("No Store Selected")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Button {
                store.showNewStoreSheet = true
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "plus")
                    Text("Create Store")
                }
                .font(DesignSystem.Typography.caption1)
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading State

    @ViewBuilder
    private var loadingState: some View {
        Spacer()
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(DesignSystem.Colors.accent)
            Text("Loading...")
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        Spacer()
    }

    // MARK: - Sidebar Content

    @ViewBuilder
    private var sidebarContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                catalogsSection
                Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.top, DesignSystem.Spacing.xxs)

                creationsSection
                Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.vertical, DesignSystem.Spacing.xxs)

                teamChatSection
                Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.vertical, DesignSystem.Spacing.xxs)

                browserSessionsSection
            }
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.always)
    }

    // MARK: - Catalogs Section

    @ViewBuilder
    private var catalogsSection: some View {
        TreeSectionHeader(
            title: "CATALOGS",
            isExpanded: $store.sidebarCatalogExpanded,
            count: store.catalogs.count
        )
        .padding(.top, DesignSystem.Spacing.xxs)

        if store.sidebarCatalogExpanded {
            if store.catalogs.isEmpty {
                Text("No catalogs")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xxs)
            } else {
                ForEach(store.catalogs) { catalog in
                    let isExpanded = store.selectedCatalog?.id == catalog.id

                    CatalogRow(
                        catalog: catalog,
                        isExpanded: isExpanded,
                        itemCount: isExpanded ? store.categories.count : nil,
                        onTap: {
                            Task {
                                if store.selectedCatalog?.id == catalog.id {
                                    store.selectedCatalog = nil
                                } else {
                                    await store.selectCatalog(catalog)
                                }
                            }
                        }
                    )

                    if isExpanded {
                        ForEach(store.topLevelCategories) { category in
                            CategoryHierarchyView(
                                category: category,
                                store: store,
                                expandedCategoryIds: $expandedCategoryIds,
                                indentLevel: 1
                            )
                        }

                        if !store.uncategorizedProducts.isEmpty {
                            ForEach(store.uncategorizedProducts) { product in
                                ProductTreeItem(
                                    product: product,
                                    isSelected: store.selectedProductIds.contains(product.id),
                                    isActive: store.selectedProduct?.id == product.id,
                                    indentLevel: 1,
                                    onSelect: { store.selectProduct(product) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Creations Section

    @ViewBuilder
    private var creationsSection: some View {
        TreeSectionHeader(
            title: "CREATIONS",
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
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(.tertiary)
                        Button {
                            store.showNewCreationSheet = true
                        } label: {
                            Text("Create one")
                                .font(DesignSystem.Typography.caption1)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
    }

    // MARK: - Team Chat Section

    @ViewBuilder
    private var teamChatSection: some View {
        TreeSectionHeader(
            title: "TEAM CHAT",
            isExpanded: $store.sidebarChatExpanded,
            count: store.conversations.count
        )

        if store.sidebarChatExpanded {
            if store.selectedStore == nil {
                Text("Select a store")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            } else if store.conversations.isEmpty {
                Text("No conversations")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            } else {
                // Location chats
                let locationConvos = store.conversations.filter { $0.chatType == "location" }
                if !locationConvos.isEmpty {
                    ChatSectionLabel(title: "Locations")
                    ForEach(locationConvos) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: store.selectedConversation?.id == conversation.id,
                            onTap: { store.openConversation(conversation) }
                        )
                    }
                }

                // Pinned chats
                let pinnedTypes = ["bugs", "alerts", "team"]
                let pinnedConvos = store.conversations.filter { pinnedTypes.contains($0.chatType ?? "") }
                if !pinnedConvos.isEmpty {
                    ChatSectionLabel(title: "Pinned")
                    ForEach(pinnedConvos) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: store.selectedConversation?.id == conversation.id,
                            onTap: { store.openConversation(conversation) }
                        )
                    }
                }

                // Recent AI chats
                let aiConvos = store.conversations.filter { $0.chatType == "ai" }.prefix(10)
                if !aiConvos.isEmpty {
                    ChatSectionLabel(title: "Recent Chats")
                    ForEach(Array(aiConvos)) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: store.selectedConversation?.id == conversation.id,
                            onTap: { store.openConversation(conversation) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Browser Sessions Section

    @ViewBuilder
    private var browserSessionsSection: some View {
        BrowserSessionsSectionHeader(
            isExpanded: $store.sidebarBrowserExpanded,
            count: store.browserSessions.filter { $0.isActive }.count,
            onNewSession: {
                Task {
                    await store.createNewBrowserSession()
                }
            }
        )

        if store.sidebarBrowserExpanded {
            if store.selectedStore == nil {
                Text("Select a store")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            } else if store.browserSessions.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("No browser sessions")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.tertiary)
                    Text("Sessions will appear here when AI browses the web")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
            } else {
                // Active sessions
                let activeSessions = store.browserSessions.filter { $0.isActive }
                if !activeSessions.isEmpty {
                    ChatSectionLabel(title: "Active")
                    ForEach(activeSessions) { session in
                        BrowserSessionItem(
                            session: session,
                            isSelected: store.selectedBrowserSession?.id == session.id,
                            onTap: { store.openBrowserSession(session) },
                            onClose: {
                                Task {
                                    await store.closeBrowserSession(session)
                                }
                            }
                        )
                    }
                }

                // Recent closed sessions
                let closedSessions = store.browserSessions.filter { !$0.isActive }.prefix(5)
                if !closedSessions.isEmpty {
                    ChatSectionLabel(title: "Recent")
                    ForEach(Array(closedSessions)) { session in
                        BrowserSessionItem(
                            session: session,
                            isSelected: store.selectedBrowserSession?.id == session.id,
                            onTap: { store.openBrowserSession(session) },
                            onClose: {
                                Task {
                                    await store.closeBrowserSession(session)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}
