import SwiftUI
import Supabase

// MARK: - Editor Sidebar View
// Extracted from EditorView.swift to improve file organization
// Refactored following Apple engineering standards - components extracted to separate files
// File size: ~114 lines (under Apple's 300 line "excellent" threshold)

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
            // Ultra minimal header
            HStack(spacing: 6) {
                SidebarSearchBar(searchText: $searchText, isSearchFocused: $isSearchFocused)

                Button(action: { store.collapseAllSections() }) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Collapse All (⌘⇧C)")
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)

            // Content tree
            if store.selectedStore == nil && store.stores.isEmpty {
                SidebarEmptyState(onCreateStore: { store.showNewStoreSheet = true })
            } else if store.isLoading {
                SidebarLoadingState()
            } else {
                sidebarContent
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSearch"))) { _ in
            isSearchFocused = true
        }
        .task {
            if store.selectedStore != nil {
                if store.browserSessions.isEmpty {
                    await store.loadBrowserSessions()
                }
                if store.orders.isEmpty {
                    await store.loadOrders()
                }
                if store.locations.isEmpty {
                    await store.loadLocations()
                }
                if store.emailTotalCount == 0 {
                    await store.loadEmailCounts()
                }
                if store.aiAgents.isEmpty {
                    await store.loadAIAgents()
                }
            }
            if store.mcpServers.isEmpty {
                await store.loadMCPServers()
            }
        }
        .onChange(of: store.selectedStore?.id) { _, _ in
            Task {
                await store.loadBrowserSessions()
                await store.loadOrders()
                await store.loadLocations()
                await store.loadEmailCounts()
                await store.loadAIAgents()
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

    // MARK: - Sidebar Content

    @ViewBuilder
    private var sidebarContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                // WORKSPACE
                Section {
                    if !store.workspaceGroupCollapsed {
                        SidebarQueuesSection(store: store)
                        SidebarLocationsSection(store: store)
                    }
                } header: {
                    SectionGroupHeader(
                        title: SidebarGroup.workspace.rawValue,
                        group: .workspace,
                        isCollapsed: $store.workspaceGroupCollapsed
                    )
                }

                // CONTENT
                Section {
                    if !store.contentGroupCollapsed {
                        SidebarCatalogsSection(store: store, expandedCategoryIds: $expandedCategoryIds)
                        SidebarCreationsSection(
                            store: store,
                            expandedCollectionIds: $expandedCollectionIds,
                            filteredOrphanCreations: filteredOrphanCreations,
                            filteredCreationsForCollection: filteredCreationsForCollection
                        )
                        SidebarTeamChatSection(store: store)
                    }
                } header: {
                    SectionGroupHeader(
                        title: SidebarGroup.content.rawValue,
                        group: .content,
                        isCollapsed: $store.contentGroupCollapsed
                    )
                }

                // OPERATIONS
                Section {
                    if !store.operationsGroupCollapsed {
                        SidebarBrowserSessionsSection(store: store)
                    }
                } header: {
                    SectionGroupHeader(
                        title: SidebarGroup.operations.rawValue,
                        group: .operations,
                        isCollapsed: $store.operationsGroupCollapsed
                    )
                }

                // INFRASTRUCTURE
                Section {
                    if !store.infrastructureGroupCollapsed {
                        SidebarAgentsSection(store: store)
                        SidebarAgentBuilderSection(store: store)
                        SidebarMCPServersSection(store: store)
                        SidebarResendSection(store: store)
                    }
                } header: {
                    SectionGroupHeader(
                        title: SidebarGroup.infrastructure.rawValue,
                        group: .infrastructure,
                        isCollapsed: $store.infrastructureGroupCollapsed
                    )
                }

                Spacer().frame(height: 12)
            }
            .padding(.vertical, 2)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
        .scrollBounceBehavior(.always)
    }
}
