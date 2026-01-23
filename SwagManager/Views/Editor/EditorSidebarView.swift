import SwiftUI
import Supabase

// MARK: - Editor Sidebar View
// Optimized for performance with smooth animations
// Apple HIG compliant

struct SidebarPanel: View {
    @ObservedObject var store: EditorStore
    @Binding var sidebarCollapsed: Bool
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var expandedCollectionIds: Set<UUID> = []
    @State private var expandedCategoryIds: Set<UUID> = []
    @FocusState private var isSearchFocused: Bool

    // Animation constants - Apple-style springs
    private let smoothSpring = Animation.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0)
    private let quickSpring = Animation.spring(response: 0.25, dampingFraction: 0.9, blendDuration: 0)

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
            // Traffic light spacer (for macOS window buttons)
            Color.clear
                .frame(height: 36)

            // Ultra minimal header with search
            HStack(spacing: 6) {
                SidebarSearchBar(searchText: $searchText, isSearchFocused: $isSearchFocused)

                Button(action: {
                    withAnimation(quickSpring) {
                        store.collapseAllSections()
                    }
                }) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
                .buttonStyle(SidebarButtonStyle())
                .help("Collapse All (⌘⇧C)")
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)

            // Content tree with optimized rendering
            if store.selectedStore == nil && store.stores.isEmpty {
                SidebarEmptyState(onCreateStore: { store.showNewStoreSheet = true })
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if store.isLoading {
                SidebarLoadingState()
                    .transition(.opacity)
            } else {
                sidebarContent
                    .transition(.opacity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSearch"))) { _ in
            isSearchFocused = true
        }
        .task(priority: .userInitiated) {
            await loadInitialData()
        }
        .onChange(of: store.selectedStore?.id) { _, _ in
            Task(priority: .userInitiated) {
                await loadStoreData()
            }
        }
        .onChange(of: searchText) { _, newValue in
            handleSearchChange(newValue)
        }
    }

    // MARK: - Data Loading (Optimized)

    private func loadInitialData() async {
        guard store.selectedStore != nil else { return }

        // Load in parallel for faster startup
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await store.loadBrowserSessions() }
            group.addTask { await store.loadOrders() }
            group.addTask { await store.loadLocations() }
            group.addTask { await store.loadEmailCounts() }
            group.addTask { await store.loadAIAgents() }
            group.addTask { await store.loadMCPServers() }
        }
    }

    private func loadStoreData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await store.loadBrowserSessions() }
            group.addTask { await store.loadOrders() }
            group.addTask { await store.loadLocations() }
            group.addTask { await store.loadEmailCounts() }
            group.addTask { await store.loadAIAgents() }
        }
    }

    private func handleSearchChange(_ newValue: String) {
        searchTask?.cancel()

        if newValue.isEmpty {
            withAnimation(quickSpring) {
                debouncedSearchText = ""
            }
            return
        }

        // Shorter debounce for snappier feel
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(quickSpring) {
                        debouncedSearchText = newValue
                    }
                }
            }
        }
    }

    // MARK: - Sidebar Content (Optimized)

    @ViewBuilder
    private var sidebarContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // WORKSPACE
                    Section {
                        if !store.workspaceGroupCollapsed {
                            SidebarQueuesSection(store: store)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity
                                ))
                            SidebarLocationsSection(store: store)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity
                                ))
                        }
                    } header: {
                        SectionGroupHeader(
                            title: SidebarGroup.workspace.rawValue,
                            group: .workspace,
                            isCollapsed: $store.workspaceGroupCollapsed
                        )
                        .id("workspace")
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
                        .id("content")
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
                        .id("operations")
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
                        .id("infrastructure")
                    }

                    Spacer().frame(height: 12)
                }
                .padding(.vertical, 2)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.automatic)
            .scrollBounceBehavior(.basedOnSize)
            .scrollClipDisabled(false)
        }
    }
}

// MARK: - Sidebar Button Style (Optimized hover/press states)

struct SidebarButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
                    .padding(-4)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// SidebarLoadingState is defined in Sidebar/SidebarLoadingState.swift
