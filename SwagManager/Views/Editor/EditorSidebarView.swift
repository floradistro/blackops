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
            // Clean header - matching sheet design
            HStack(spacing: 8) {
                // Search bar
                SidebarSearchBar(searchText: $searchText, isSearchFocused: $isSearchFocused)

                // Collapse All button
                Button(action: {
                    store.collapseAllSections()
                }) {
                    Image(systemName: "sidebar.squares.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Collapse All Sections (⌘⇧C)")
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DesignSystem.Colors.surfaceSecondary)

            Divider()

            // Content tree
            if store.selectedStore == nil && store.stores.isEmpty {
                SidebarEmptyState(onCreateStore: { store.showNewStoreSheet = true })
            } else if store.isLoading {
                SidebarLoadingState()
            } else {
                sidebarContent
            }
        }
        .background(DesignSystem.Colors.surfaceSecondary)
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
                // WORKSPACE - High Priority, Real-time Operations
                Section {
                    if !store.workspaceGroupCollapsed {
                        SidebarQueuesSection(store: store)
                        Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.vertical, DesignSystem.Spacing.xxs)

                        SidebarLocationsSection(store: store)
                        Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.vertical, DesignSystem.Spacing.xxs)
                    }
                } header: {
                    SectionGroupHeader(
                        title: SidebarGroup.workspace.rawValue,
                        group: .workspace,
                        isCollapsed: $store.workspaceGroupCollapsed
                    )
                }

                // CONTENT - Products, Creations, Communications
                Section {
                    if !store.contentGroupCollapsed {
                        SidebarCatalogsSection(store: store, expandedCategoryIds: $expandedCategoryIds)
                        Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.vertical, DesignSystem.Spacing.xxs)

                        SidebarCreationsSection(
                            store: store,
                            expandedCollectionIds: $expandedCollectionIds,
                            filteredOrphanCreations: filteredOrphanCreations,
                            filteredCreationsForCollection: filteredCreationsForCollection
                        )
                        Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.vertical, DesignSystem.Spacing.xxs)

                        SidebarTeamChatSection(store: store)
                        Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.vertical, DesignSystem.Spacing.xxs)
                    }
                } header: {
                    SectionGroupHeader(
                        title: SidebarGroup.content.rawValue,
                        group: .content,
                        isCollapsed: $store.contentGroupCollapsed
                    )
                }

                // OPERATIONS - Browser Sessions
                Section {
                    if !store.operationsGroupCollapsed {
                        SidebarBrowserSessionsSection(store: store)
                        Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.vertical, DesignSystem.Spacing.xxs)
                    }
                } header: {
                    SectionGroupHeader(
                        title: SidebarGroup.operations.rawValue,
                        group: .operations,
                        isCollapsed: $store.operationsGroupCollapsed
                    )
                }

                // INFRASTRUCTURE - AI Agents, MCP Servers, Agent Builder, Resend
                Section {
                    if !store.infrastructureGroupCollapsed {
                        SidebarAgentsSection(store: store)
                        Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.vertical, DesignSystem.Spacing.xxs)

                        SidebarAgentBuilderSection(store: store)
                        Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.vertical, DesignSystem.Spacing.xxs)

                        SidebarMCPServersSection(store: store)
                        Divider().padding(.horizontal, DesignSystem.Spacing.sm).padding(.vertical, DesignSystem.Spacing.xxs)

                        SidebarResendSection(store: store)
                    }
                } header: {
                    SectionGroupHeader(
                        title: SidebarGroup.infrastructure.rawValue,
                        group: .infrastructure,
                        isCollapsed: $store.infrastructureGroupCollapsed
                    )
                }

                // Bottom padding to ensure content isn't cut off
                Spacer().frame(height: 20)
            }
            .padding(.vertical, DesignSystem.Spacing.xxs)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
        .scrollBounceBehavior(.always)
    }
}
