import SwiftUI
import WebKit
import Supabase
import Darwin
// import SwiftTerm // TODO: Add SwiftTerm package in Xcode: File > Add Package Dependencies > https://github.com/migueldeicaza/SwiftTerm.git

// MARK: - JSON Decoder Extension for Supabase
extension JSONDecoder {
    static var supabaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode date: \(dateString)")
            )
        }
        return decoder
    }
}

// MARK: - App Theme (Dark)


// MARK: - Native Smooth ScrollView (60fps with elastic bounce)

struct SmoothScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    var showsIndicators: Bool = true

    init(showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = SmoothNSScrollView()
        scrollView.hasVerticalScroller = showsIndicators
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        // Overlay scrollers for modern look
        scrollView.scrollerStyle = .overlay

        // Enable elastic bounce on both ends
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none

        // GPU acceleration
        scrollView.wantsLayer = true
        scrollView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layerContentsRedrawPolicy = .onSetNeedsDisplay

        // Create hosting view for SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Flipped clip view for natural scrolling direction
        let flippedView = FlippedClipView()
        flippedView.documentView = hostingView
        flippedView.drawsBackground = false
        flippedView.backgroundColor = .clear
        flippedView.wantsLayer = true
        scrollView.contentView = flippedView

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: flippedView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: flippedView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: flippedView.topAnchor),
        ])

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let hostingView = scrollView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

// Custom NSScrollView with smooth scroll physics
private class SmoothNSScrollView: NSScrollView {
    override class var isCompatibleWithResponsiveScrolling: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        // Use default smooth scrolling behavior
        super.scrollWheel(with: event)
    }
}

// Flipped clip view for correct coordinate system
private class FlippedClipView: NSClipView {
    override var isFlipped: Bool { true }
}

// MARK: - Performant Tree Item Button Style (no SwiftUI hover state)

// Hover effect using NSView tracking area (doesn't cause SwiftUI re-renders during scroll)
struct HoverableView<Content: View>: NSViewRepresentable {
    let content: (Bool) -> Content

    func makeNSView(context: Context) -> NSHostingView<Content> {
        let view = HoverTrackingHostingView(rootView: content(false), coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content(context.coordinator.isHovering)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var isHovering = false
    }
}

private class HoverTrackingHostingView<Content: View>: NSHostingView<Content> {
    weak var coordinator: HoverableView<Content>.Coordinator?
    private var trackingArea: NSTrackingArea?

    init(rootView: Content, coordinator: HoverableView<Content>.Coordinator) {
        self.coordinator = coordinator
        super.init(rootView: rootView)
    }

    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        coordinator?.isHovering = true
    }

    override func mouseExited(with event: NSEvent) {
        coordinator?.isHovering = false
    }
}

// MARK: - Native Chat ScrollView (60fps with auto-scroll)
// Uses native SwiftUI ScrollView for efficient diffing - no NSViewRepresentable overhead

struct SmoothChatScrollView<Content: View>: View {
    let content: Content
    @Binding var scrollToBottom: Bool

    init(scrollToBottom: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._scrollToBottom = scrollToBottom
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity)

                // Invisible anchor at bottom
                Color.clear
                    .frame(height: 1)
                    .id("bottom")
            }
            .scrollBounceBehavior(.always)
            .onChange(of: scrollToBottom) { _, shouldScroll in
                if shouldScroll {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    scrollToBottom = false
                }
            }
        }
    }
}

// MARK: - Main Editor View

struct EditorView: View {
    @StateObject private var store = EditorStore()
    @EnvironmentObject var authManager: AuthManager
    @State private var sidebarCollapsed = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedTab: EditorTab = .preview
    @State private var showStoreSelectorSheet = false

    // MARK: - Main Content View

    @ViewBuilder
    private var mainContentView: some View {
        ZStack {
            if let activeTab = store.activeTab {
                switch activeTab {
                case .creation(let creation):
                    // Creation editor
                    switch selectedTab {
                    case .preview:
                        HotReloadRenderer(
                            code: store.editedCode ?? creation.reactCode ?? "",
                            creationId: creation.id.uuidString,
                            refreshTrigger: store.refreshTrigger
                        )
                    case .code:
                        CodeEditorPanel(
                            code: Binding(
                                get: { store.editedCode ?? store.selectedCreation?.reactCode ?? "" },
                                set: { store.editedCode = $0 }
                            ),
                            onSave: { Task { await store.saveCurrentCreation() } }
                        )
                    case .details:
                        DetailsPanel(creation: creation, store: store)
                    case .settings:
                        SettingsPanel(creation: creation, store: store)
                    }

                case .product(let product):
                    // Product editor
                    ProductEditorPanel(product: product, store: store)

                case .conversation(let conversation):
                    // Chat conversation
                    TeamChatView(store: store)

                case .category(let category):
                    // Category config editor
                    CategoryConfigView(category: category, store: store)

                case .browserSession(let session):
                    // Safari-style browser
                    SafariBrowserWindow(sessionId: session.id)
                        .id("browser-\(session.id)")
                }
            } else if let browserSession = store.selectedBrowserSession {
                // Safari-style browser
                SafariBrowserWindow(sessionId: browserSession.id)
                    .id("browser-\(browserSession.id)")
            } else if let category = store.selectedCategory {
                // Show category config even without tab
                CategoryConfigView(category: category, store: store)
            } else if let conversation = store.selectedConversation {
                // Show conversation even without tab
                TeamChatView(store: store)
            } else if let product = store.selectedProduct {
                // Show product even without tab
                ProductEditorPanel(product: product, store: store)
            } else if let creation = store.selectedCreation {
                // Show creation even without tab
                switch selectedTab {
                case .preview:
                    HotReloadRenderer(
                        code: store.editedCode ?? creation.reactCode ?? "",
                        creationId: creation.id.uuidString,
                        refreshTrigger: store.refreshTrigger
                    )
                case .code:
                    CodeEditorPanel(
                        code: Binding(
                            get: { store.editedCode ?? creation.reactCode ?? "" },
                            set: { store.editedCode = $0 }
                        ),
                        onSave: { Task { await store.saveCurrentCreation() } }
                    )
                case .details:
                    DetailsPanel(creation: creation, store: store)
                case .settings:
                    SettingsPanel(creation: creation, store: store)
                }
            } else {
                // Welcome state
                WelcomeView(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(store.zoomLevel)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            SidebarPanel(store: store, sidebarCollapsed: $sidebarCollapsed)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
                .toolbarBackground(.hidden, for: .windowToolbar)
        } detail: {
            // Main Content Area
            ZStack {
                // Unified glass background for all content
                VisualEffectBackground(material: .underWindowBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    mainContentView
                }
            }
            .toolbar {
                UnifiedToolbarContent(store: store)
            }
            .toolbarBackground(.hidden, for: .windowToolbar)
        }
        .navigationSplitViewStyle(.balanced)
        .animation(DesignSystem.Animation.spring, value: sidebarCollapsed)
        .onChange(of: sidebarCollapsed) { _, collapsed in
            columnVisibility = collapsed ? .detailOnly : .all
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleSidebar"))) { _ in
            withAnimation(DesignSystem.Animation.spring) {
                sidebarCollapsed.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SaveDocument"))) { _ in
            if store.hasUnsavedChanges {
                Task { await store.saveCurrentCreation() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowStoreSelector"))) { _ in
            showStoreSelectorSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowNewStore"))) { _ in
            store.showNewStoreSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ZoomIn"))) { _ in
            store.zoomIn()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ZoomOut"))) { _ in
            store.zoomOut()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ZoomReset"))) { _ in
            store.resetZoom()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowserNewTab"))) { _ in
            if let session = store.selectedBrowserSession ?? (store.activeTab?.isBrowserSession == true ? (store.activeTab as? OpenTabItem).flatMap { tab in
                if case .browserSession(let s) = tab { return s } else { return nil }
            } : nil) {
                BrowserTabManager.forSession(session.id).newTab()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowserReload"))) { _ in
            if let session = store.selectedBrowserSession ?? (store.activeTab?.isBrowserSession == true ? (store.activeTab as? OpenTabItem).flatMap { tab in
                if case .browserSession(let s) = tab { return s } else { return nil }
            } : nil) {
                BrowserTabManager.forSession(session.id).activeTab?.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowserBack"))) { _ in
            if let session = store.selectedBrowserSession ?? (store.activeTab?.isBrowserSession == true ? (store.activeTab as? OpenTabItem).flatMap { tab in
                if case .browserSession(let s) = tab { return s } else { return nil }
            } : nil) {
                BrowserTabManager.forSession(session.id).activeTab?.goBack()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowserForward"))) { _ in
            if let session = store.selectedBrowserSession ?? (store.activeTab?.isBrowserSession == true ? (store.activeTab as? OpenTabItem).flatMap { tab in
                if case .browserSession(let s) = tab { return s } else { return nil }
            } : nil) {
                BrowserTabManager.forSession(session.id).activeTab?.goForward()
            }
        }
        // Store selector sheet removed during refactoring
        // .sheet(isPresented: $showStoreSelectorSheet) {
        //     StoreSelectorSheet(store: store)
        // }
        .task {
            await store.loadCreations()
            // RLS handles filtering - just load stores
            await store.loadStores()
            await store.loadCatalog()
        }
        .sheet(isPresented: $store.showNewCreationSheet) {
            NewCreationSheet(store: store)
        }
        .sheet(isPresented: $store.showNewCollectionSheet) {
            NewCollectionSheet(store: store)
        }
        .sheet(isPresented: $store.showNewStoreSheet) {
            NewStoreSheet(store: store, authManager: authManager)
        }
        .sheet(isPresented: $store.showNewCatalogSheet) {
            NewCatalogSheet(store: store)
        }
        .sheet(isPresented: $store.showNewCategorySheet) {
            NewCategorySheet(store: store)
        }
        .alert("Error", isPresented: Binding(
            get: { store.error != nil },
            set: { if !$0 { store.error = nil } }
        )) {
            Button("OK") { store.error = nil }
        } message: {
            Text(store.error ?? "")
        }
    }
}

enum EditorTab: String, CaseIterable {
    case preview = "Preview"
    case code = "Code"
    case details = "Details"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .preview: return "play.display"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .details: return "info.circle"
        case .settings: return "gear"
        }
    }

    var terminalLabel: String {
        switch self {
        case .preview: return "▶"
        case .code: return "</>"
        case .details: return "ℹ"
        case .settings: return "⚙"
        }
    }
}

// MARK: - Open Tab Model (Safari/Xcode style tabs)

enum OpenTabItem: Identifiable, Hashable {
    case creation(Creation)
    case product(Product)
    case conversation(Conversation)
    case category(Category)
    case browserSession(BrowserSession)

    var id: String {
        switch self {
        case .creation(let c): return "creation-\(c.id)"
        case .product(let p): return "product-\(p.id)"
        case .conversation(let c): return "conversation-\(c.id)"
        case .category(let c): return "category-\(c.id)"
        case .browserSession(let s): return "browser-\(s.id)"
        }
    }

    var name: String {
        switch self {
        case .creation(let c): return c.name
        case .product(let p): return p.name
        case .conversation(let c): return c.displayTitle
        case .category(let c): return c.name
        case .browserSession(let s): return s.displayName
        }
    }

    var icon: String {
        switch self {
        case .creation(let c):
            switch c.creationType {
            case .app: return "app.badge"
            case .display: return "display"
            case .email: return "envelope"
            case .landing: return "globe"
            case .dashboard: return "chart.bar.xaxis"
            case .artifact: return "cube"
            case .store: return "storefront"
            }
        case .product: return "leaf"
        case .conversation(let c): return c.chatTypeIcon
        case .category: return "folder"
        case .browserSession: return "globe"
        }
    }

    var iconColor: Color {
        switch self {
        case .creation(let c): return c.creationType.color
        case .product: return .green
        case .conversation: return .blue
        case .category: return .orange
        case .browserSession: return .cyan
        }
    }

    var isCreation: Bool {
        if case .creation = self { return true }
        return false
    }

    var isBrowserSession: Bool {
        if case .browserSession = self { return true }
        return false
    }

    // Terminal-style icon
    var terminalIcon: String {
        switch self {
        case .creation(let c): return c.creationType.terminalIcon
        case .product: return "•"
        case .conversation: return "◈"
        case .category: return "▢"
        case .browserSession: return "◎"
        }
    }

    // Terminal-style color
    var terminalColor: Color {
        switch self {
        case .creation(let c): return c.creationType.terminalColor
        case .product: return .green
        case .conversation: return .purple
        case .category: return .yellow
        case .browserSession: return .cyan
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: OpenTabItem, rhs: OpenTabItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Editor Store

@MainActor
class EditorStore: ObservableObject {
    // MARK: - Creations State
    @Published var creations: [Creation] = []
    @Published var collections: [CreationCollection] = []
    @Published var collectionItems: [UUID: [UUID]] = [:] // collectionId -> [creationId]
    @Published var selectedCreation: Creation?
    @Published var selectedCreationIds: Set<UUID> = []
    @Published var editedCode: String?

    // MARK: - Catalog State (Products, Categories & Stores)
    @Published var stores: [Store] = []
    @Published var selectedStore: Store?
    @Published var catalogs: [Catalog] = []
    @Published var selectedCatalog: Catalog?
    @Published var products: [Product] = []
    @Published var categories: [Category] = []
    @Published var selectedProduct: Product?
    @Published var selectedProductIds: Set<UUID> = []

    // MARK: - Chat/Conversations State
    @Published var locations: [Location] = []
    @Published var conversations: [Conversation] = []
    @Published var selectedConversation: Conversation?

    // MARK: - Category Config State
    @Published var selectedCategory: Category?

    // MARK: - Browser Sessions State
    @Published var browserSessions: [BrowserSession] = []
    @Published var selectedBrowserSession: BrowserSession?
    @Published var sidebarBrowserExpanded = false

    // MARK: - Tabs (Safari/Xcode style)
    @Published var openTabs: [OpenTabItem] = []
    @Published var activeTab: OpenTabItem?

    // MARK: - UI State
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var refreshTrigger = UUID()
    @Published var error: String?
    @Published var sidebarCreationsExpanded = false
    @Published var sidebarCatalogExpanded = false
    @Published var sidebarChatExpanded = false
    @Published var zoomLevel: CGFloat = 1.0

    // Sheet states
    @Published var showNewCreationSheet = false
    @Published var showNewCollectionSheet = false
    @Published var showNewStoreSheet = false
    @Published var showNewCatalogSheet = false
    @Published var showNewCategorySheet = false

    var lastSelectedIndex: Int?

    let supabase = SupabaseService.shared
    private var realtimeTask: Task<Void, Never>?

    // Default store ID for new items
    let defaultStoreId = UUID(uuidString: "cd2e1122-d511-4edb-be5d-98ef274b4baf")!

    init() {
        startRealtimeSubscription()
    }

    deinit {
        realtimeTask?.cancel()
    }

    // MARK: - Realtime Subscriptions

    private func startRealtimeSubscription() {
        realtimeTask = Task { [weak self] in
            guard let self = self else { return }

            let client = self.supabase.client

            // Subscribe to all changes on one channel
            let channel = client.realtimeV2.channel("swag-manager-changes")

            // Creations table
            let creationsInserts = channel.postgresChange(InsertAction.self, table: "creations")
            let creationsUpdates = channel.postgresChange(UpdateAction.self, table: "creations")
            let creationsDeletes = channel.postgresChange(DeleteAction.self, table: "creations")

            // Collections table
            let collectionsInserts = channel.postgresChange(InsertAction.self, table: "creation_collections")
            let collectionsUpdates = channel.postgresChange(UpdateAction.self, table: "creation_collections")
            let collectionsDeletes = channel.postgresChange(DeleteAction.self, table: "creation_collections")

            // Collection items table
            let collectionItemsInserts = channel.postgresChange(InsertAction.self, table: "creation_collection_items")
            let collectionItemsDeletes = channel.postgresChange(DeleteAction.self, table: "creation_collection_items")

            // Browser sessions table
            let browserSessionsInserts = channel.postgresChange(InsertAction.self, table: "browser_sessions")
            let browserSessionsUpdates = channel.postgresChange(UpdateAction.self, table: "browser_sessions")
            let browserSessionsDeletes = channel.postgresChange(DeleteAction.self, table: "browser_sessions")

            do {
                try await channel.subscribeWithError()
                NSLog("[EditorStore] Realtime: Successfully subscribed to channel")
            } catch {
                NSLog("[EditorStore] Realtime: Failed to subscribe - \(error.localizedDescription)")
                return // Don't try to use the channel if subscription failed
            }

            // Keep processing events in parallel
            await withTaskGroup(of: Void.self) { group in
                // Handle creations inserts
                group.addTask {
                    for await insert in creationsInserts {
                        NSLog("[EditorStore] Realtime: creation INSERT received")
                        await MainActor.run {
                            if let creation = try? insert.decodeRecord(as: Creation.self, decoder: JSONDecoder.supabaseDecoder) {
                                if !self.creations.contains(where: { $0.id == creation.id }) {
                                    self.creations.insert(creation, at: 0)
                                    NSLog("[EditorStore] Realtime: Added creation '\(creation.name)'")
                                }
                            } else {
                                NSLog("[EditorStore] Realtime: Failed to decode creation, reloading all")
                                Task { await self.loadCreations() }
                            }
                        }
                    }
                }

                // Handle creations updates
                group.addTask {
                    for await update in creationsUpdates {
                        NSLog("[EditorStore] Realtime: creation UPDATE received")
                        await MainActor.run {
                            if let creation = try? update.decodeRecord(as: Creation.self, decoder: JSONDecoder.supabaseDecoder) {
                                if let idx = self.creations.firstIndex(where: { $0.id == creation.id }) {
                                    self.creations[idx] = creation
                                    NSLog("[EditorStore] Realtime: Updated creation '\(creation.name)'")
                                    if self.selectedCreation?.id == creation.id {
                                        self.selectedCreation = creation
                                        // Don't overwrite editedCode if user has local changes
                                        if self.editedCode == nil || !self.hasUnsavedChanges {
                                            self.editedCode = creation.reactCode
                                        }
                                        self.refreshTrigger = UUID()
                                    }
                                }
                            }
                        }
                    }
                }

                // Handle creations deletes
                group.addTask {
                    for await delete in creationsDeletes {
                        NSLog("[EditorStore] Realtime: creation DELETE received")
                        await MainActor.run {
                            let oldRecord = delete.oldRecord
                            if let idString = oldRecord["id"]?.stringValue,
                               let id = UUID(uuidString: idString) {
                                self.creations.removeAll { $0.id == id }
                                self.selectedCreationIds.remove(id)
                                if self.selectedCreation?.id == id {
                                    self.selectedCreation = nil
                                    self.editedCode = nil
                                }
                                NSLog("[EditorStore] Realtime: Removed creation \(idString)")
                            }
                        }
                    }
                }

                // Handle collections inserts
                group.addTask {
                    for await insert in collectionsInserts {
                        NSLog("[EditorStore] Realtime: collection INSERT received")
                        await MainActor.run {
                            if let collection = try? insert.decodeRecord(as: CreationCollection.self, decoder: JSONDecoder.supabaseDecoder) {
                                if !self.collections.contains(where: { $0.id == collection.id }) {
                                    self.collections.insert(collection, at: 0)
                                    NSLog("[EditorStore] Realtime: Added collection '\(collection.name)'")
                                }
                            } else {
                                NSLog("[EditorStore] Realtime: Failed to decode collection, reloading")
                                Task {
                                    self.collections = try await self.supabase.fetchCollections()
                                }
                            }
                        }
                    }
                }

                // Handle collections updates
                group.addTask {
                    for await update in collectionsUpdates {
                        NSLog("[EditorStore] Realtime: collection UPDATE received")
                        await MainActor.run {
                            if let collection = try? update.decodeRecord(as: CreationCollection.self, decoder: JSONDecoder.supabaseDecoder) {
                                if let idx = self.collections.firstIndex(where: { $0.id == collection.id }) {
                                    self.collections[idx] = collection
                                    NSLog("[EditorStore] Realtime: Updated collection '\(collection.name)'")
                                }
                            }
                        }
                    }
                }

                // Handle collections deletes
                group.addTask {
                    for await delete in collectionsDeletes {
                        NSLog("[EditorStore] Realtime: collection DELETE received")
                        await MainActor.run {
                            let oldRecord = delete.oldRecord
                            if let idString = oldRecord["id"]?.stringValue,
                               let id = UUID(uuidString: idString) {
                                self.collections.removeAll { $0.id == id }
                                self.collectionItems.removeValue(forKey: id)
                                NSLog("[EditorStore] Realtime: Removed collection \(idString)")
                            }
                        }
                    }
                }

                // Handle collection items inserts
                group.addTask {
                    for await insert in collectionItemsInserts {
                        NSLog("[EditorStore] Realtime: collection_item INSERT received")
                        await MainActor.run {
                            let record = insert.record
                            if let collectionIdStr = record["collection_id"]?.stringValue,
                               let creationIdStr = record["creation_id"]?.stringValue,
                               let collectionId = UUID(uuidString: collectionIdStr),
                               let creationId = UUID(uuidString: creationIdStr) {
                                if self.collectionItems[collectionId] == nil {
                                    self.collectionItems[collectionId] = []
                                }
                                if !self.collectionItems[collectionId]!.contains(creationId) {
                                    self.collectionItems[collectionId]!.append(creationId)
                                    NSLog("[EditorStore] Realtime: Added item to collection")
                                }
                            }
                        }
                    }
                }

                // Handle collection items deletes
                group.addTask {
                    for await delete in collectionItemsDeletes {
                        NSLog("[EditorStore] Realtime: collection_item DELETE received")
                        await MainActor.run {
                            let oldRecord = delete.oldRecord
                            if let collectionIdStr = oldRecord["collection_id"]?.stringValue,
                               let creationIdStr = oldRecord["creation_id"]?.stringValue,
                               let collectionId = UUID(uuidString: collectionIdStr),
                               let creationId = UUID(uuidString: creationIdStr) {
                                self.collectionItems[collectionId]?.removeAll { $0 == creationId }
                                NSLog("[EditorStore] Realtime: Removed item from collection")
                            }
                        }
                    }
                }

                // Handle browser sessions inserts
                group.addTask {
                    for await insert in browserSessionsInserts {
                        NSLog("[EditorStore] Realtime: browser_session INSERT received")
                        await MainActor.run {
                            if let session = try? insert.decodeRecord(as: BrowserSession.self, decoder: JSONDecoder.supabaseDecoder) {
                                // Only add if it belongs to current store
                                if session.storeId == self.selectedStore?.id {
                                    if !self.browserSessions.contains(where: { $0.id == session.id }) {
                                        self.browserSessions.insert(session, at: 0)
                                        NSLog("[EditorStore] Realtime: Added browser session '\(session.displayName)'")
                                    }
                                }
                            } else {
                                NSLog("[EditorStore] Realtime: Failed to decode browser session")
                            }
                        }
                    }
                }

                // Handle browser sessions updates
                group.addTask {
                    for await update in browserSessionsUpdates {
                        NSLog("[EditorStore] Realtime: browser_session UPDATE received")
                        await MainActor.run {
                            if let session = try? update.decodeRecord(as: BrowserSession.self, decoder: JSONDecoder.supabaseDecoder) {
                                if let idx = self.browserSessions.firstIndex(where: { $0.id == session.id }) {
                                    self.browserSessions[idx] = session
                                    NSLog("[EditorStore] Realtime: Updated browser session '\(session.displayName)'")
                                    // Update selected if this is the selected one
                                    if self.selectedBrowserSession?.id == session.id {
                                        self.selectedBrowserSession = session
                                    }
                                    // Update in open tabs
                                    if let tabIndex = self.openTabs.firstIndex(where: {
                                        if case .browserSession(let s) = $0, s.id == session.id { return true }
                                        return false
                                    }) {
                                        self.openTabs[tabIndex] = .browserSession(session)
                                    }
                                    if case .browserSession(let s) = self.activeTab, s.id == session.id {
                                        self.activeTab = .browserSession(session)
                                    }
                                }
                            }
                        }
                    }
                }

                // Handle browser sessions deletes
                group.addTask {
                    for await delete in browserSessionsDeletes {
                        NSLog("[EditorStore] Realtime: browser_session DELETE received")
                        await MainActor.run {
                            let oldRecord = delete.oldRecord
                            if let idString = oldRecord["id"]?.stringValue,
                               let id = UUID(uuidString: idString) {
                                self.browserSessions.removeAll { $0.id == id }
                                if self.selectedBrowserSession?.id == id {
                                    self.selectedBrowserSession = nil
                                }
                                // Close tab if open
                                self.openTabs.removeAll {
                                    if case .browserSession(let s) = $0, s.id == id { return true }
                                    return false
                                }
                                if case .browserSession(let s) = self.activeTab, s.id == id {
                                    self.activeTab = self.openTabs.first
                                }
                                NSLog("[EditorStore] Realtime: Removed browser session \(idString)")
                            }
                        }
                    }
                }
            }
        }
    }

    var hasUnsavedChanges: Bool {
        guard let edited = editedCode, let original = selectedCreation?.reactCode else { return false }
        return edited != original
    }

    var selectedCreations: [Creation] {
        creations.filter { selectedCreationIds.contains($0.id) }
    }

    // Get creations for a specific collection
    func creationsForCollection(_ collectionId: UUID) -> [Creation] {
        guard let creationIds = collectionItems[collectionId] else { return [] }
        return creations.filter { creationIds.contains($0.id) }
    }

    // Get creations not in any collection
    var orphanCreations: [Creation] {
        let allCollectionCreationIds = Set(collectionItems.values.flatMap { $0 })
        return creations.filter { !allCollectionCreationIds.contains($0.id) }
    }

    func loadCreations() async {
        isLoading = true
        do {
            creations = try await supabase.fetchCreations()
        } catch {
            print("Error loading creations: \(error)")
            self.error = "Failed to load creations: \(error.localizedDescription)"
        }

        // Load collections separately so one failure doesn't block the other
        do {
            NSLog("[EditorStore] Fetching collections...")
            collections = try await supabase.fetchCollections()
            NSLog("[EditorStore] Loaded %d collections", collections.count)

            // Load all collection items
            var itemsMap: [UUID: [UUID]] = [:]
            for collection in collections {
                let items = try await supabase.fetchCollectionItems(collectionId: collection.id)
                itemsMap[collection.id] = items.map { $0.creationId }
            }
            collectionItems = itemsMap
            NSLog("[EditorStore] Loaded collection items for %d collections", itemsMap.count)
        } catch {
            NSLog("[EditorStore] Error loading collections: %@", String(describing: error))
            // Don't override error if creations also failed
            if self.error == nil {
                self.error = "Failed to load collections: \(error.localizedDescription)"
            }
        }
        isLoading = false
    }

    func selectCreation(_ creation: Creation, add: Bool = false, range: Bool = false, in list: [Creation] = []) {
        if range, let lastIdx = lastSelectedIndex, let currentIdx = list.firstIndex(where: { $0.id == creation.id }) {
            // Shift+click: select range
            let start = min(lastIdx, currentIdx)
            let end = max(lastIdx, currentIdx)
            for i in start...end {
                selectedCreationIds.insert(list[i].id)
            }
        } else if add {
            // Cmd+click: toggle selection
            if selectedCreationIds.contains(creation.id) {
                selectedCreationIds.remove(creation.id)
                if selectedCreation?.id == creation.id {
                    selectedCreation = selectedCreations.first
                    editedCode = selectedCreation?.reactCode
                }
            } else {
                selectedCreationIds.insert(creation.id)
            }
        } else {
            // Normal click: single select
            selectedCreationIds = [creation.id]
        }

        // Update active creation for editing
        if selectedCreationIds.contains(creation.id) {
            selectedCreation = creation
            editedCode = creation.reactCode
            selectedProduct = nil
            selectedProductIds.removeAll()
            lastSelectedIndex = list.firstIndex(where: { $0.id == creation.id })
            openTab(.creation(creation))
        }
    }

    func clearSelection() {
        selectedCreationIds.removeAll()
        selectedCreation = nil
        editedCode = nil
        lastSelectedIndex = nil
    }

    func saveCurrentCreation() async {
        guard let creation = selectedCreation, let code = editedCode else { return }
        isSaving = true
        do {
            let update = CreationUpdate(reactCode: code)
            let updated = try await supabase.updateCreation(id: creation.id, update: update)
            selectedCreation = updated
            editedCode = updated.reactCode
            refreshTrigger = UUID()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func updateCreationSettings(id: UUID, status: CreationStatus? = nil, isPublic: Bool? = nil, visibility: String? = nil, name: String? = nil, description: String? = nil) async {
        isSaving = true
        do {
            let update = CreationUpdate(name: name, description: description, status: status, isPublic: isPublic, visibility: visibility)
            let updated = try await supabase.updateCreation(id: id, update: update)
            if let idx = creations.firstIndex(where: { $0.id == id }) {
                creations[idx] = updated
            }
            if selectedCreation?.id == id {
                selectedCreation = updated
            }
            refreshTrigger = UUID()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func deleteCreation(_ creation: Creation) async {
        do {
            try await supabase.deleteCreation(id: creation.id)
            if selectedCreation?.id == creation.id {
                selectedCreation = nil
                editedCode = nil
            }
            selectedCreationIds.remove(creation.id)
            await loadCreations()
        } catch {
            print("Delete failed for \(creation.name): \(error)")
            self.error = "Failed to delete '\(creation.name)': \(error.localizedDescription)"
        }
    }

    func deleteSelectedCreations() async {
        let idsToDelete = selectedCreationIds
        var failedCount = 0
        var errors: [String] = []

        for id in idsToDelete {
            do {
                try await supabase.deleteCreation(id: id)
            } catch {
                failedCount += 1
                errors.append(error.localizedDescription)
            }
        }

        // Clear selection
        selectedCreationIds.removeAll()
        selectedCreation = nil
        editedCode = nil
        lastSelectedIndex = nil

        // Reload once at the end
        await loadCreations()

        // Report errors if any
        if failedCount > 0 {
            self.error = "Failed to delete \(failedCount) item(s): \(errors.first ?? "Unknown error")"
        }
    }

    func triggerRefresh() {
        refreshTrigger = UUID()
    }

    // MARK: - Zoom Functions

    func zoomIn() {
        zoomLevel = min(zoomLevel + 0.1, 3.0)
    }

    func zoomOut() {
        zoomLevel = max(zoomLevel - 0.1, 0.5)
    }

    func resetZoom() {
        zoomLevel = 1.0
    }

    // MARK: - Create Functions

    func createCreation(name: String, type: CreationType, description: String?) async {
        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let insert = CreationInsert(
            creationType: type,
            name: name,
            slug: slug,
            description: description,
            status: .draft,
            reactCode: defaultReactCode(for: type, name: name)
        )

        do {
            let created = try await supabase.createCreation(insert)
            await loadCreations()
            selectCreation(created, in: creations)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createCollection(name: String, description: String?) async {
        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let insert = CollectionInsert(
            storeId: defaultStoreId,
            name: name,
            slug: slug,
            description: description,
            isPublic: false
        )

        do {
            _ = try await supabase.createCollection(insert)
            collections = try await supabase.fetchCollections()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteCollection(_ collection: CreationCollection) async {
        do {
            try await supabase.deleteCollection(id: collection.id)
            collections = try await supabase.fetchCollections()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func defaultReactCode(for type: CreationType, name: String) -> String {
        """
        const App = () => {
          return (
            <div className="min-h-screen bg-black text-white flex items-center justify-center">
              <div className="text-center">
                <h1 className="text-4xl font-bold mb-4">\(name)</h1>
                <p className="text-gray-400">Start building your \(type.displayName.lowercased())</p>
              </div>
            </div>
          );
        };
        """
    }

    // MARK: - Catalog (Products, Categories & Stores)

    func loadStores() async {
        do {
            // Check if user is authenticated first
            let session = try? await supabase.client.auth.session
            NSLog("[EditorStore] Auth session: %@", session != nil ? "authenticated" : "NOT authenticated")

            // RLS automatically filters to stores the user owns/works at
            stores = try await supabase.fetchStores()
            NSLog("[EditorStore] Loaded %d stores", stores.count)
            // Auto-select first store if none selected
            if selectedStore == nil, let first = stores.first {
                selectedStore = first
                NSLog("[EditorStore] Auto-selected store: %@", first.storeName)
            }
        } catch {
            NSLog("[EditorStore] Error loading stores: %@", String(describing: error))
            self.error = "Failed to load stores: \(error.localizedDescription)"
        }
    }

    func selectStore(_ store: Store) async {
        selectedStore = store
        // Clear old data
        selectedCatalog = nil
        catalogs = []
        categories = []
        products = []
        conversations = []
        locations = []
        // Reload all data for new store
        await loadCatalog()
    }

    func createStore(name: String, email: String, ownerUserId: UUID?) async {
        do {
            let slug = name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

            let insert = StoreInsert(
                storeName: name,
                slug: slug,
                email: email,
                ownerUserId: nil,  // DB trigger will auto-set from logged-in user
                status: "active",
                storeType: "standard"
            )

            let newStore = try await supabase.createStore(insert)
            stores.append(newStore)
            selectedStore = newStore
            await loadCatalog()
            NSLog("[EditorStore] Created store: %@", name)
        } catch {
            NSLog("[EditorStore] Error creating store: %@", String(describing: error))
            self.error = "Failed to create store: \(error.localizedDescription)"
        }
    }

    /// Current store ID for catalog queries
    var currentStoreId: UUID {
        selectedStore?.id ?? defaultStoreId
    }

    // MARK: - Catalogs

    func loadCatalogs() async {
        do {
            NSLog("[EditorStore] Loading catalogs for store: %@ (%@)", selectedStore?.storeName ?? "unknown", currentStoreId.uuidString)
            catalogs = try await supabase.fetchCatalogs(storeId: currentStoreId)
            NSLog("[EditorStore] Found %d catalogs for store %@:", catalogs.count, selectedStore?.storeName ?? "unknown")
            for cat in catalogs {
                NSLog("[EditorStore]   - %@ (id: %@, store_id: %@)", cat.name, cat.id.uuidString, cat.storeId.uuidString)
            }

            // Auto-create default catalog if none exist but categories do
            if catalogs.isEmpty {
                NSLog("[EditorStore] No catalogs found, checking for orphan categories...")
                let orphanCategories = try await supabase.fetchCategories(storeId: currentStoreId, catalogId: nil)
                let orphanCount = orphanCategories.filter { $0.catalogId == nil }.count
                NSLog("[EditorStore] Found %d total categories, %d without catalog_id", orphanCategories.count, orphanCount)

                if orphanCount > 0 {
                    NSLog("[EditorStore] Creating default Distro catalog and migrating %d categories...", orphanCount)
                    await createDefaultCatalogAndMigrate()
                    return // createDefaultCatalogAndMigrate will reload catalogs
                }
            } else if let defaultCatalog = catalogs.first(where: { $0.isDefault == true }) ?? catalogs.first {
                // Catalogs exist - assign ALL categories for this store to the default catalog
                // This ensures categories don't belong to other/orphaned catalogs
                let allCategories = try await supabase.fetchCategories(storeId: currentStoreId, catalogId: nil)
                let wrongCatalogCount = allCategories.filter { $0.catalogId != defaultCatalog.id }.count
                if wrongCatalogCount > 0 {
                    NSLog("[EditorStore] Found %d categories not in default catalog, migrating to %@...", wrongCatalogCount, defaultCatalog.name)
                    let migrated = try await supabase.assignCategoriesToCatalog(storeId: currentStoreId, catalogId: defaultCatalog.id, onlyOrphans: false)
                    NSLog("[EditorStore] Migrated %d categories to %@", migrated, defaultCatalog.name)
                }
            }

            // Don't auto-select - let user expand catalog to see contents
            NSLog("[EditorStore] Loaded %d catalogs for store %@", catalogs.count, selectedStore?.storeName ?? "default")
        } catch {
            NSLog("[EditorStore] Error loading catalogs: %@", String(describing: error))
            // Don't show error if table doesn't exist yet
        }
    }

    private func createDefaultCatalogAndMigrate() async {
        guard let ownerUserId = selectedStore?.ownerUserId else {
            NSLog("[EditorStore] Cannot create catalog: store owner_user_id is nil")
            return
        }

        do {
            // First check if catalog already exists
            catalogs = try await supabase.fetchCatalogs(storeId: currentStoreId)

            if let existingCatalog = catalogs.first {
                // Use existing catalog for migration but don't auto-select
                NSLog("[EditorStore] Found existing catalog: %@ (id: %@)", existingCatalog.name, existingCatalog.id.uuidString)

                // Migrate orphan categories
                let migratedCount = try await supabase.assignCategoriesToCatalog(storeId: currentStoreId, catalogId: existingCatalog.id)
                if migratedCount > 0 {
                    NSLog("[EditorStore] Migrated %d categories to %@", migratedCount, existingCatalog.name)
                }
                return
            }

            NSLog("[EditorStore] Creating default Distro catalog for store: %@", currentStoreId.uuidString)

            // Create default "Distro" catalog
            let insert = CatalogInsert(
                storeId: currentStoreId,
                ownerUserId: ownerUserId,
                name: "Distro",
                slug: "distro-\(Int(Date().timeIntervalSince1970))",
                description: "Main product catalog",
                vertical: "cannabis",
                isActive: true,
                isDefault: true
            )

            let newCatalog = try await supabase.createCatalog(insert)
            NSLog("[EditorStore] Created catalog: %@ (id: %@)", newCatalog.name, newCatalog.id.uuidString)

            // Migrate orphan categories
            let migratedCount = try await supabase.assignCategoriesToCatalog(storeId: currentStoreId, catalogId: newCatalog.id)
            NSLog("[EditorStore] Migrated %d categories", migratedCount)

            catalogs = [newCatalog]
            // Don't auto-select - keep collapsed
        } catch {
            NSLog("[EditorStore] Error in createDefaultCatalogAndMigrate: %@", String(describing: error))
            // Don't show error to user - just load what we have
            await loadCatalogData()
        }
    }

    func selectCatalog(_ catalog: Catalog) async {
        selectedCatalog = catalog
        await loadCatalogData()
    }

    func createCatalog(name: String, vertical: String?, isDefault: Bool = false) async {
        guard let ownerUserId = selectedStore?.ownerUserId else {
            NSLog("[EditorStore] Cannot create catalog: store owner_user_id is nil")
            self.error = "Cannot create catalog: store owner not found"
            return
        }

        do {
            let slug = name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

            let insert = CatalogInsert(
                storeId: currentStoreId,
                ownerUserId: ownerUserId,
                name: name,
                slug: slug,
                description: nil,
                vertical: vertical,
                isActive: true,
                isDefault: isDefault
            )

            let newCatalog = try await supabase.createCatalog(insert)
            await loadCatalogs()
            selectedCatalog = newCatalog
            await loadCatalogData()
            NSLog("[EditorStore] Created catalog: %@", name)
        } catch {
            NSLog("[EditorStore] Error creating catalog: %@", String(describing: error))
            self.error = "Failed to create catalog: \(error.localizedDescription)"
        }
    }

    func deleteCatalog(_ catalog: Catalog) async {
        do {
            try await supabase.deleteCatalog(id: catalog.id)
            if selectedCatalog?.id == catalog.id {
                selectedCatalog = nil
            }
            await loadCatalogs()
            await loadCatalogData()
            NSLog("[EditorStore] Deleted catalog: %@", catalog.name)
        } catch {
            NSLog("[EditorStore] Error deleting catalog: %@", String(describing: error))
            self.error = "Failed to delete catalog: \(error.localizedDescription)"
        }
    }

    // MARK: - Load Catalog Data (Categories & Products)

    func loadCatalog() async {
        await loadCatalogs()
        await loadCatalogData()
        await loadConversations()
    }

    func loadCatalogData() async {
        do {
            categories = try await supabase.fetchCategories(storeId: currentStoreId, catalogId: selectedCatalog?.id)
            products = try await supabase.fetchProducts(storeId: currentStoreId)
            NSLog("[EditorStore] Loaded %d categories, %d products for store %@, catalog %@", categories.count, products.count, selectedStore?.storeName ?? "default", selectedCatalog?.name ?? "all")
        } catch {
            NSLog("[EditorStore] Error loading catalog data: %@", String(describing: error))
            if self.error == nil {
                self.error = "Failed to load catalog: \(error.localizedDescription)"
            }
        }
    }

    func createCategory(name: String, parentId: UUID? = nil) async {
        do {
            let slug = name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

            let insert = CategoryInsert(
                name: name,
                slug: slug,
                description: nil,
                parentId: parentId,
                catalogId: selectedCatalog?.id,
                storeId: currentStoreId,
                displayOrder: categories.count,
                isActive: true
            )

            _ = try await supabase.createCategory(insert)
            await loadCatalogData()
            NSLog("[EditorStore] Created category: %@", name)
        } catch {
            NSLog("[EditorStore] Error creating category: %@", String(describing: error))
            self.error = "Failed to create category: \(error.localizedDescription)"
        }
    }

    func deleteCategory(_ category: Category) async {
        do {
            try await supabase.deleteCategory(id: category.id)
            await loadCatalogData()
            NSLog("[EditorStore] Deleted category: %@", category.name)
        } catch {
            NSLog("[EditorStore] Error deleting category: %@", String(describing: error))
            self.error = "Failed to delete category: \(error.localizedDescription)"
        }
    }

    func productsForCategory(_ categoryId: UUID) -> [Product] {
        products.filter { $0.primaryCategoryId == categoryId }
    }

    var uncategorizedProducts: [Product] {
        products.filter { $0.primaryCategoryId == nil }
    }

    // MARK: - Category Hierarchy Helpers

    /// Top-level categories (no parent)
    var topLevelCategories: [Category] {
        categories.filter { $0.parentId == nil }
    }

    /// Get child categories for a given parent
    func childCategories(of parentId: UUID) -> [Category] {
        categories.filter { $0.parentId == parentId }
    }

    /// Check if category has children
    func hasChildCategories(_ categoryId: UUID) -> Bool {
        categories.contains { $0.parentId == categoryId }
    }

    /// Get all descendant category IDs (recursive)
    func allDescendantCategoryIds(of parentId: UUID) -> Set<UUID> {
        var result = Set<UUID>()
        let children = childCategories(of: parentId)
        for child in children {
            result.insert(child.id)
            result.formUnion(allDescendantCategoryIds(of: child.id))
        }
        return result
    }

    /// Get products in a category and all its subcategories
    func productsInCategoryTree(_ categoryId: UUID) -> [Product] {
        var categoryIds = Set([categoryId])
        categoryIds.formUnion(allDescendantCategoryIds(of: categoryId))
        return products.filter { product in
            guard let catId = product.primaryCategoryId else { return false }
            return categoryIds.contains(catId)
        }
    }

    /// Count of direct products in category (not including subcategories)
    func directProductCount(_ categoryId: UUID) -> Int {
        products.filter { $0.primaryCategoryId == categoryId }.count
    }

    /// Total count including all subcategory products
    func totalProductCount(_ categoryId: UUID) -> Int {
        productsInCategoryTree(categoryId).count
    }

    func selectProduct(_ product: Product) {
        selectedProduct = product
        selectedProductIds = [product.id]
        selectedCreation = nil
        selectedCreationIds.removeAll()
        selectedCategory = nil
        openTab(.product(product))
    }

    func selectCategory(_ category: Category) {
        selectedCategory = category
        selectedProduct = nil
        selectedProductIds.removeAll()
        selectedCreation = nil
        selectedCreationIds.removeAll()
        selectedConversation = nil
        openTab(.category(category))
    }

    func deleteProduct(_ product: Product) async {
        do {
            try await supabase.deleteProduct(id: product.id)
            if selectedProduct?.id == product.id {
                selectedProduct = nil
                closeTab(.product(product))
            }
            selectedProductIds.remove(product.id)
            await loadCatalog()
        } catch {
            self.error = "Failed to delete '\(product.name)': \(error.localizedDescription)"
        }
    }

    func updateProductField(id: UUID, field: String, value: Any?) async {
        isSaving = true
        do {
            var update = ProductUpdate()
            switch field {
            case "name": update.name = value as? String
            case "description": update.description = value as? String
            case "sku": update.sku = value as? String
            case "status": update.status = value as? String
            case "stockQuantity":
                if let doubleVal = value as? Double {
                    update.stockQuantity = Int(doubleVal)
                }
            case "stockStatus": update.stockStatus = value as? String
            default: break
            }
            let updated = try await supabase.updateProduct(id: id, update: update)
            if let idx = products.firstIndex(where: { $0.id == id }) {
                products[idx] = updated
            }
            if selectedProduct?.id == id {
                selectedProduct = updated
                // Update in open tabs
                if let tabIdx = openTabs.firstIndex(where: {
                    if case .product(let p) = $0 { return p.id == id }
                    return false
                }) {
                    openTabs[tabIdx] = .product(updated)
                    if case .product = activeTab { activeTab = .product(updated) }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    // MARK: - Tab Management

    func openTab(_ item: OpenTabItem) {
        if !openTabs.contains(where: { $0.id == item.id }) {
            openTabs.append(item)
        }
        activeTab = item
    }

    func closeTab(_ item: OpenTabItem) {
        openTabs.removeAll { $0.id == item.id }
        if activeTab?.id == item.id {
            activeTab = openTabs.last
            // Update selection based on active tab
            if let tab = activeTab {
                switch tab {
                case .creation(let c):
                    selectedCreation = c
                    editedCode = c.reactCode
                    selectedProduct = nil
                    selectedConversation = nil
                case .product(let p):
                    selectedProduct = p
                    selectedCreation = nil
                    selectedConversation = nil
                    editedCode = nil
                case .conversation(let c):
                    selectedConversation = c
                    selectedCreation = nil
                    selectedProduct = nil
                    selectedCategory = nil
                    editedCode = nil
                case .category(let c):
                    selectedCategory = c
                    selectedCreation = nil
                    selectedProduct = nil
                    selectedConversation = nil
                    editedCode = nil
                case .browserSession(let s):
                    selectedBrowserSession = s
                    selectedCreation = nil
                    selectedProduct = nil
                    selectedConversation = nil
                    selectedCategory = nil
                    editedCode = nil
                }
            } else {
                selectedCreation = nil
                selectedProduct = nil
                selectedConversation = nil
                selectedCategory = nil
                selectedBrowserSession = nil
                editedCode = nil
            }
        }
    }

    func switchToTab(_ item: OpenTabItem) {
        activeTab = item
        switch item {
        case .creation(let c):
            selectedCreation = c
            editedCode = c.reactCode
            selectedProduct = nil
            selectedConversation = nil
            selectedCategory = nil
            selectedBrowserSession = nil
        case .product(let p):
            selectedProduct = p
            selectedCreation = nil
            selectedConversation = nil
            selectedCategory = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .conversation(let c):
            selectedConversation = c
            selectedCreation = nil
            selectedProduct = nil
            selectedCategory = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .category(let c):
            selectedCategory = c
            selectedCreation = nil
            selectedProduct = nil
            selectedConversation = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .browserSession(let s):
            selectedBrowserSession = s
            selectedCreation = nil
            selectedProduct = nil
            selectedConversation = nil
            selectedCategory = nil
            editedCode = nil
        }
    }

    func closeOtherTabs(except tab: OpenTabItem) {
        openTabs = openTabs.filter { $0.id == tab.id }
        activeTab = tab
        switch tab {
        case .creation(let c):
            selectedCreation = c
            editedCode = c.reactCode
            selectedProduct = nil
            selectedConversation = nil
            selectedCategory = nil
            selectedBrowserSession = nil
        case .product(let p):
            selectedProduct = p
            selectedCreation = nil
            selectedConversation = nil
            selectedCategory = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .conversation(let c):
            selectedConversation = c
            selectedCreation = nil
            selectedProduct = nil
            selectedCategory = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .category(let c):
            selectedCategory = c
            selectedCreation = nil
            selectedProduct = nil
            selectedConversation = nil
            selectedBrowserSession = nil
            editedCode = nil
        case .browserSession(let s):
            selectedBrowserSession = s
            selectedCreation = nil
            selectedProduct = nil
            selectedConversation = nil
            selectedCategory = nil
            editedCode = nil
        }
    }

    func closeAllTabs() {
        openTabs.removeAll()
        activeTab = nil
        selectedCreation = nil
        selectedProduct = nil
        selectedConversation = nil
        selectedCategory = nil
        selectedBrowserSession = nil
        editedCode = nil
    }

    func closeTabsToRight(of tab: OpenTabItem) {
        guard let index = openTabs.firstIndex(where: { $0.id == tab.id }) else { return }
        openTabs = Array(openTabs.prefix(through: index))
        // If active tab was closed, switch to the reference tab
        if let active = activeTab, !openTabs.contains(where: { $0.id == active.id }) {
            switchToTab(tab)
        }
    }

    // MARK: - Conversations & Locations

    func loadConversations() async {
        guard let store = selectedStore else {
            NSLog("[EditorStore] No store selected, cannot load conversations")
            return
        }

        do {
            // Load locations first
            NSLog("[EditorStore] Loading locations for store: \(store.id)")
            locations = try await supabase.fetchLocations(storeId: store.id)
            NSLog("[EditorStore] Loaded \(locations.count) locations")

            // Load conversations
            NSLog("[EditorStore] Loading conversations for store: \(store.id)")
            conversations = try await supabase.fetchAllConversationsForStoreLocations(storeId: store.id)
            NSLog("[EditorStore] Loaded \(conversations.count) conversations")
        } catch {
            NSLog("[EditorStore] Failed to load conversations: \(error)")
            self.error = "Failed to load conversations: \(error.localizedDescription)"
        }
    }

    func openConversation(_ conversation: Conversation) {
        selectedConversation = conversation
        selectedCreation = nil
        selectedProduct = nil
        editedCode = nil
        openTab(.conversation(conversation))
    }

    func openLocationChat(_ location: Location) {
        // Find existing conversation for this location, or create a placeholder
        if let existingConvo = conversations.first(where: { $0.locationId == location.id }) {
            openConversation(existingConvo)
        } else {
            // Create a virtual conversation for this location (will be created on first message)
            let virtualConvo = Conversation(
                id: UUID(),
                storeId: selectedStore?.id,
                userId: nil,
                title: location.name,
                status: "new",
                messageCount: 0,
                chatType: "location",
                locationId: location.id,
                metadata: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            openConversation(virtualConvo)
        }
    }

    // MARK: - Browser Sessions

    func loadBrowserSessions() async {
        guard let store = selectedStore else {
            NSLog("[EditorStore] No store selected, cannot load browser sessions")
            return
        }

        do {
            NSLog("[EditorStore] Loading browser sessions for store: \(store.id)")
            browserSessions = try await supabase.fetchBrowserSessions(storeId: store.id)
            NSLog("[EditorStore] Loaded \(browserSessions.count) browser sessions")
        } catch {
            NSLog("[EditorStore] Failed to load browser sessions: \(error)")
            self.error = "Failed to load browser sessions: \(error.localizedDescription)"
        }
    }

    func openBrowserSession(_ session: BrowserSession) {
        selectedBrowserSession = session
        selectedCreation = nil
        selectedProduct = nil
        selectedConversation = nil
        editedCode = nil
        openTab(.browserSession(session))
    }

    func createNewBrowserSession() async {
        guard let store = selectedStore else {
            NSLog("[EditorStore] No store selected, cannot create browser session")
            return
        }

        do {
            let name = "Browser Session \(Date().formatted(date: .omitted, time: .shortened))"
            let newSession = try await supabase.createBrowserSession(storeId: store.id, name: name)

            // Add to list
            browserSessions.insert(newSession, at: 0)

            // Open the new session
            openBrowserSession(newSession)

            NSLog("[EditorStore] Created new browser session: \(newSession.id)")
        } catch {
            NSLog("[EditorStore] Failed to create browser session: \(error)")
            self.error = "Failed to create browser session: \(error.localizedDescription)"
        }
    }

    func closeBrowserSession(_ session: BrowserSession) async {
        do {
            try await supabase.closeBrowserSession(id: session.id)

            // Update in list
            if let index = browserSessions.firstIndex(where: { $0.id == session.id }) {
                var updatedSession = session
                updatedSession.status = "closed"
                browserSessions[index] = updatedSession
            }

            // Close tab if open
            closeTab(.browserSession(session))

            // Clean up the tab manager for this session
            BrowserTabManager.removeSession(session.id)

            // Deselect if selected
            if selectedBrowserSession?.id == session.id {
                selectedBrowserSession = nil
            }

            NSLog("[EditorStore] Closed browser session: \(session.id)")
        } catch {
            NSLog("[EditorStore] Failed to close browser session: \(error)")
            self.error = "Failed to close browser session: \(error.localizedDescription)"
        }
    }

    func refreshBrowserSession(_ session: BrowserSession) async {
        do {
            if let updated = try await supabase.fetchBrowserSession(id: session.id) {
                // Update in array
                if let index = browserSessions.firstIndex(where: { $0.id == session.id }) {
                    browserSessions[index] = updated
                }
                // Update selected if this is the selected one
                if selectedBrowserSession?.id == session.id {
                    selectedBrowserSession = updated
                }
                // Update in open tabs
                if let tabIndex = openTabs.firstIndex(where: {
                    if case .browserSession(let s) = $0, s.id == session.id { return true }
                    return false
                }) {
                    openTabs[tabIndex] = .browserSession(updated)
                }
                if case .browserSession(let s) = activeTab, s.id == session.id {
                    activeTab = .browserSession(updated)
                }
            }
        } catch {
            NSLog("[EditorStore] Failed to refresh browser session: \(error)")
        }
    }
}

// MARK: - Toolbar Tab Strip (Safari-style)


// MARK: - Product Editor Panel

struct ProductEditorPanel: View {
    let product: Product
    @ObservedObject var store: EditorStore

    @State private var editedName: String
    @State private var editedSKU: String
    @State private var editedDescription: String
    @State private var editedShortDescription: String
    @State private var hasChanges = false
    @State private var fieldSchemas: [FieldSchema] = []
    @State private var pricingSchemaName: String?
    @State private var stockByLocation: [(locationName: String, quantity: Int)] = []

    init(product: Product, store: EditorStore) {
        self.product = product
        self.store = store

        _editedName = State(initialValue: product.name)
        _editedSKU = State(initialValue: product.sku ?? "")
        _editedDescription = State(initialValue: product.description ?? "")
        _editedShortDescription = State(initialValue: product.shortDescription ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with image and name
                HStack(spacing: 16) {
                    if let imageUrl = product.featuredImage {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color(white: 0.15))
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Product Name", text: $editedName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18, weight: .semibold))
                            .onChange(of: editedName) { _, _ in hasChanges = true }

                        Text(product.sku ?? "No SKU")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()
                    .padding(.vertical, 8)

                // Product Information
                SectionHeader(title: "Product Information")
                VStack(spacing: 10) {
                    EditableRow(label: "SKU", text: $editedSKU, hasChanges: $hasChanges)
                    InfoRow(label: "Type", value: product.type ?? "-")
                    InfoRow(label: "Status", value: product.status ?? "-")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                Divider()
                    .padding(.vertical, 8)

                // Description
                SectionHeader(title: "Description")
                VStack(spacing: 16) {
                    GlassTextEditor(
                        label: "Full Description",
                        text: $editedDescription,
                        minHeight: 80,
                        hasChanges: $hasChanges
                    )

                    GlassTextEditor(
                        label: "Short Description",
                        text: $editedShortDescription,
                        minHeight: 60,
                        hasChanges: $hasChanges
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                Divider()
                    .padding(.vertical, 8)

                // Pricing
                if let pricingData = product.pricingData {
                    ProductPricingSection(pricingData: pricingData, schemaName: pricingSchemaName)
                        .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)
                }

                // Custom Fields
                if !fieldSchemas.isEmpty {
                    CustomFieldsSection(schemas: fieldSchemas, fieldValues: product.customFields)
                        .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)
                }

                // Stock by Location
                if !stockByLocation.isEmpty {
                    SectionHeader(title: "Stock by Location")
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(stockByLocation, id: \.locationName) { location in
                            HStack {
                                Text(location.locationName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(location.quantity)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(location.quantity > 0 ? DesignSystem.Colors.green : .secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)
                }

                // Costs & Wholesale
                SectionHeader(title: "Costs")
                VStack(spacing: 10) {
                    if let costPrice = product.costPrice {
                        InfoRow(label: "Cost Price", value: String(format: "$%.2f", NSDecimalNumber(decimal: costPrice).doubleValue))
                    }
                    if let wholesalePrice = product.wholesalePrice {
                        InfoRow(label: "Wholesale Price", value: String(format: "$%.2f", NSDecimalNumber(decimal: wholesalePrice).doubleValue))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .toolbar {
            if hasChanges {
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Cancel") {
                        resetChanges()
                    }
                    Button("Save") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            loadData()
        }
    }

    private func loadData() {
        Task {
            // Load field schemas
            if let categoryId = product.primaryCategoryId {
                do {
                    let schemas = try await store.supabase.fetchFieldSchemasForCategory(categoryId: categoryId)
                    await MainActor.run {
                        self.fieldSchemas = schemas
                    }
                } catch {
                    print("Error loading field schemas: \(error)")
                }
            }

            // Load pricing schema name
            if let schemaId = product.pricingSchemaId {
                do {
                    let response = try await store.supabase.client
                        .from("pricing_schemas")
                        .select("name")
                        .eq("id", value: schemaId.uuidString)
                        .single()
                        .execute()

                    if let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
                       let name = json["name"] as? String {
                        await MainActor.run {
                            self.pricingSchemaName = name
                        }
                    }
                } catch {
                    print("Error loading pricing schema: \(error)")
                }
            }

            // Load stock by location
            do {
                let response = try await store.supabase.client
                    .from("inventory_products")
                    .select("quantity, location:locations(name)")
                    .eq("product_id", value: product.id.uuidString)
                    .execute()

                if let items = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                    var locations: [(String, Int)] = []
                    for item in items {
                        if let locationDict = item["location"] as? [String: Any],
                           let locationName = locationDict["name"] as? String,
                           let quantity = item["quantity"] as? Int {
                            locations.append((locationName, quantity))
                        }
                    }
                    await MainActor.run {
                        self.stockByLocation = locations.sorted { $0.0 < $1.0 }
                    }
                }
            } catch {
                print("Error loading stock by location: \(error)")
            }
        }
    }

    private func resetChanges() {
        editedName = product.name
        editedSKU = product.sku ?? ""
        editedDescription = product.description ?? ""
        editedShortDescription = product.shortDescription ?? ""
        hasChanges = false
    }

    private func saveChanges() {
        Task {
            do {
                var updates: [String: Any] = [:]

                if editedName != product.name {
                    updates["name"] = editedName
                }
                if editedSKU != (product.sku ?? "") {
                    updates["sku"] = editedSKU.isEmpty ? nil : editedSKU
                }
                if editedDescription != (product.description ?? "") {
                    updates["description"] = editedDescription.isEmpty ? nil : editedDescription
                }
                if editedShortDescription != (product.shortDescription ?? "") {
                    updates["short_description"] = editedShortDescription.isEmpty ? nil : editedShortDescription
                }

                if !updates.isEmpty {
                    let jsonData = try JSONSerialization.data(withJSONObject: updates)
                    try await store.supabase.client
                        .from("products")
                        .update(jsonData)
                        .eq("id", value: product.id.uuidString)
                        .execute()

                    // Reload products
                    await store.loadCatalogData()

                    await MainActor.run {
                        hasChanges = false
                    }
                }
            } catch {
                print("Error saving changes: \(error)")
            }
        }
    }
}

// Helper components for clean list UI
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 10)
    }
}

struct EditableRow: View {
    let label: String
    @Binding var text: String
    @Binding var hasChanges: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 12))

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignSystem.Colors.surfaceTertiary)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignSystem.Materials.thin)

                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isFocused ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.borderSubtle, lineWidth: 1)
                    }
                }
                .focused($isFocused)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
                .onChange(of: text) { _, _ in hasChanges = true }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ProductFieldRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12))
    }
}

struct GlassTextEditor: View {
    let label: String
    @Binding var text: String
    let minHeight: CGFloat
    @Binding var hasChanges: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .font(.system(size: 12))
                .padding(10)
                .scrollContentBackground(.hidden)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.surfaceTertiary)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Materials.thin)

                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.borderSubtle, lineWidth: 1)
                    }
                }
                .focused($isFocused)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
                .onChange(of: text) { _, _ in hasChanges = true }
        }
    }
}

// MARK: - Custom Fields Section

struct CustomFieldsSection: View {
    let schemas: [FieldSchema]
    let fieldValues: [String: AnyCodable]?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Custom Fields")

            VStack(alignment: .leading, spacing: 18) {
                ForEach(schemas, id: \.id) { schema in
                    // Only show fields that have actual values
                    let fieldsWithValues = schema.fields.filter { hasFieldValue($0) }

                    if !fieldsWithValues.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(schema.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.3)

                            VStack(spacing: 8) {
                                ForEach(fieldsWithValues, id: \.fieldId) { field in
                                    HStack(spacing: 12) {
                                        Text(field.displayLabel)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .leading)
                                            .font(.system(size: 12))
                                        Text(getFieldValue(field))
                                            .font(.system(size: 12))
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func hasFieldValue(_ field: FieldDefinition) -> Bool {
        guard let fieldKey = field.key,
              let fieldValues = fieldValues else {
            return false
        }
        return fieldValues[fieldKey] != nil
    }

    private func getFieldValue(_ field: FieldDefinition) -> String {
        // Try to get actual value from product's custom_fields
        if let fieldKey = field.key,
           let fieldValues = fieldValues,
           let actualValue = fieldValues[fieldKey] {
            return "\(actualValue.value)"
        }

        // Fall back to default value from schema if no actual value exists
        if let defaultValue = field.defaultValue {
            return "\(defaultValue.value)"
        }

        return "-"
    }
}

// MARK: - Pricing Schemas Section

struct ProductPricingSection: View {
    let pricingData: AnyCodable
    let schemaName: String?

    var body: some View {
        let tiers = extractTiers()

        if !tiers.isEmpty {
            let title = schemaName.map { "\($0) Pricing" } ?? "Pricing Tiers"
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: title)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(tiers.enumerated()), id: \.offset) { index, tierDict in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(extractLabel(from: tierDict))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)

                                if let qty = extractQuantity(from: tierDict) {
                                    let unit = tierDict["unit"] as? String ?? "units"
                                    Text("(\(formatQuantity(qty)) \(unit))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(extractPrice(from: tierDict))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.green)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DesignSystem.Colors.surfaceTertiary)

                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DesignSystem.Materials.thin)

                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func extractTiers() -> [[String: Any]] {
        // Case 1: pricing_data is an array of tiers
        if let tiersArray = pricingData.value as? [[String: Any]] {
            return tiersArray
        }

        // Case 2: pricing_data is an object with a "tiers" property
        if let pricingObject = pricingData.value as? [String: Any],
           let tiersArray = pricingObject["tiers"] as? [[String: Any]] {
            return tiersArray
        }

        return []
    }

    private func extractLabel(from dict: [String: Any]) -> String {
        if let label = dict["label"] as? String {
            return label
        }
        if let id = dict["id"] as? String {
            return id
        }
        return "Tier"
    }

    private func extractQuantity(from dict: [String: Any]) -> Double? {
        if let qty = dict["quantity"] as? Double {
            return qty
        }
        if let qty = dict["quantity"] as? Int {
            return Double(qty)
        }
        return nil
    }

    private func extractPrice(from dict: [String: Any]) -> String {
        // Try default_price first (various types for PostgreSQL numeric compatibility)
        if let price = dict["default_price"] as? Double {
            return String(format: "$%.2f", price)
        }
        if let price = dict["default_price"] as? Decimal {
            return String(format: "$%.2f", NSDecimalNumber(decimal: price).doubleValue)
        }
        if let price = dict["default_price"] as? Int {
            return String(format: "$%.2f", Double(price))
        }
        if let priceStr = dict["default_price"] as? String, let price = Double(priceStr) {
            return String(format: "$%.2f", price)
        }

        // Try price field
        if let price = dict["price"] as? Double {
            return String(format: "$%.2f", price)
        }
        if let price = dict["price"] as? Decimal {
            return String(format: "$%.2f", NSDecimalNumber(decimal: price).doubleValue)
        }
        if let price = dict["price"] as? Int {
            return String(format: "$%.2f", Double(price))
        }
        if let priceStr = dict["price"] as? String, let price = Double(priceStr) {
            return String(format: "$%.2f", price)
        }

        return "-"
    }

    private func formatQuantity(_ qty: Double) -> String {
        if qty.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", qty)
        } else {
            return String(format: "%.1f", qty)
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @ObservedObject var store: EditorStore
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Welcome card
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DesignSystem.Colors.accent.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.selectedStore?.storeName ?? "Swag Manager")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text("Ready to build")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                // Stats
                if !store.products.isEmpty || !store.categories.isEmpty || !store.creations.isEmpty {
                    HStack(spacing: 0) {
                        statItem(value: store.products.count, label: "Products", color: DesignSystem.Colors.green)
                        Rectangle().fill(DesignSystem.Colors.border).frame(width: 1, height: 40)
                        statItem(value: store.categories.count, label: "Categories", color: DesignSystem.Colors.yellow)
                        Rectangle().fill(DesignSystem.Colors.border).frame(width: 1, height: 40)
                        statItem(value: store.creations.count, label: "Creations", color: DesignSystem.Colors.cyan)
                    }
                    .padding(.vertical, 16)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Quick actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    HStack(spacing: 12) {
                        QuickActionButton(icon: "plus", label: "New Creation", shortcut: "⌘N") {
                            store.showNewCreationSheet = true
                        }
                        QuickActionButton(icon: "folder.badge.plus", label: "New Collection", shortcut: "⌘⇧N") {
                            store.showNewCollectionSheet = true
                        }
                    }
                }
            }
            .padding(32)
            .background(DesignSystem.Colors.surfaceTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
            .frame(maxWidth: 440)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()

            // Keyboard hints
            HStack(spacing: 32) {
                keyboardHint(keys: ["⌘", "N"], action: "New")
                keyboardHint(keys: ["⌘", "F"], action: "Search")
                keyboardHint(keys: ["⌘", "\\"], action: "Sidebar")
            }
            .padding(.bottom, 40)
            .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(DesignSystem.Animation.slow.delay(0.1)) {
                appeared = true
            }
        }
    }

    private func statItem(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func keyboardHint(keys: [String], action: String) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.surfaceTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            }
            Text(action)
                .font(.system(size: 10))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let label: String
    let shortcut: String
    let action: () -> Void

    @State private var isHovering = false
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(shortcut)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(isHovering ? DesignSystem.Colors.surfaceElevated : DesignSystem.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovering ? DesignSystem.Colors.border : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Sidebar Panel (Extracted to EditorSidebarView.swift)

// MARK: - Category Hierarchy View (Extracted to TreeItems.swift)


struct CreationListItem: View {
    let creation: Creation
    let isSelected: Bool
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: creation.creationType.icon)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 16)

            Text(creation.name)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)

            Spacer()

            Circle()
                .fill(creation.status == .published ? Color.green : Color.orange)
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Editor Tab Bar (VSCode-style)


// MARK: - Hot Reload Renderer

// MARK: - Code Editor Panel

struct CodeEditorPanel: View {
    @Binding var code: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("React Code")
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Text("\(code.count) characters")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding()
            .background(DesignSystem.Colors.surfaceTertiary)

            Rectangle()
                .fill(DesignSystem.Colors.border)
                .frame(height: 1)

            // Editor
            TextEditor(text: $code)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(DesignSystem.Colors.surfaceElevated)
        }
    }
}

// MARK: - Details Panel

struct DetailsPanel: View {
    let creation: Creation
    @ObservedObject var store: EditorStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: creation.creationType.icon)
                            .font(.title)
                            .foregroundStyle(Color.accentColor)
                        Text(creation.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }

                    Text(creation.description ?? "No description")
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatBox(title: "Views", value: "\(creation.viewCount ?? 0)", icon: "eye")
                    StatBox(title: "Installs", value: "\(creation.installCount ?? 0)", icon: "arrow.down.circle")
                    StatBox(title: "Version", value: creation.version ?? "1.0.0", icon: "tag")
                }

                Divider()

                // Metadata
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)

                    MetaRow(label: "ID", value: creation.id.uuidString)
                    MetaRow(label: "Slug", value: creation.slug)
                    MetaRow(label: "Type", value: creation.creationType.displayName)
                    MetaRow(label: "Status", value: creation.status?.displayName ?? "Draft")
                    MetaRow(label: "Visibility", value: creation.visibility ?? "private")

                    if let url = creation.deployedUrl {
                        MetaRow(label: "URL", value: url)
                    }

                    if let created = creation.createdAt {
                        MetaRow(label: "Created", value: created.formatted())
                    }
                }
            }
            .padding(24)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

struct MetaRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.system(size: 13))
    }
}

// MARK: - Settings Panel

struct SettingsPanel: View {
    let creation: Creation
    @ObservedObject var store: EditorStore

    @State private var selectedStatus: CreationStatus = .draft
    @State private var isPublic: Bool = false
    @State private var selectedVisibility: String = "private"

    var body: some View {
        Form {
            Section("Visibility") {
                Picker("Status", selection: $selectedStatus) {
                    ForEach(CreationStatus.allCases, id: \.self) { status in
                        HStack {
                            Circle()
                                .fill(status.color)
                                .frame(width: 8, height: 8)
                            Text(status.displayName)
                        }
                        .tag(status)
                    }
                }
                .onChange(of: selectedStatus) { _, newStatus in
                    Task {
                        await store.updateCreationSettings(id: creation.id, status: newStatus)
                    }
                }

                Toggle("Public", isOn: $isPublic)
                    .onChange(of: isPublic) { _, newValue in
                        Task {
                            await store.updateCreationSettings(id: creation.id, isPublic: newValue)
                        }
                    }

                Picker("Visibility", selection: $selectedVisibility) {
                    Text("Private").tag("private")
                    Text("Public").tag("public")
                    Text("Unlisted").tag("unlisted")
                }
                .onChange(of: selectedVisibility) { _, newValue in
                    Task {
                        await store.updateCreationSettings(id: creation.id, visibility: newValue)
                    }
                }
            }

            Section("Deployment") {
                if let url = creation.deployedUrl {
                    LabeledContent("URL", value: url)
                }
                if let repo = creation.githubRepo {
                    LabeledContent("GitHub", value: repo)
                }
            }

            Section("Info") {
                LabeledContent("ID", value: creation.id.uuidString)
                LabeledContent("Type", value: creation.creationType.displayName)
                if let created = creation.createdAt {
                    LabeledContent("Created", value: created.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            selectedStatus = creation.status ?? .draft
            isPublic = creation.isPublic ?? false
            selectedVisibility = creation.visibility ?? "private"
        }
        .onChange(of: creation.id) { _, _ in
            selectedStatus = creation.status ?? .draft
            isPublic = creation.isPublic ?? false
            selectedVisibility = creation.visibility ?? "private"
        }
    }
}

// MARK: - Empty State

struct EmptyEditorView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No Selection")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Select a creation from the sidebar")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.surfaceTertiary)
    }
}

// MARK: - New Creation Sheet


// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

// MARK: - Browser Controls Bar (Above browser content only)


// MARK: - Unified Toolbar Content (Baked into Window Titlebar)

struct UnifiedToolbarContent: CustomizableToolbarContent {
    @ObservedObject var store: EditorStore
    @State private var urlText: String = ""
    @FocusState private var isURLFieldFocused: Bool

    private var isBrowserActive: Bool {
        if case .browserSession = store.activeTab {
            return true
        }
        return store.selectedBrowserSession != nil
    }

    private var tabManager: BrowserTabManager? {
        if case .browserSession(let session) = store.activeTab {
            return BrowserTabManager.forSession(session.id)
        } else if let session = store.selectedBrowserSession {
            return BrowserTabManager.forSession(session.id)
        }
        return nil
    }

    var body: some CustomizableToolbarContent {
        if let activeTab = store.activeTab {
            switch activeTab {
            case .browserSession(let session):
                let tabManager = BrowserTabManager.forSession(session.id)
                // Back
                ToolbarItem(id: "back") {
                    Button(action: { tabManager.activeTab?.goBack() }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!(tabManager.activeTab?.canGoBack ?? false))
                }

                // Forward
                ToolbarItem(id: "forward") {
                    Button(action: { tabManager.activeTab?.goForward() }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!(tabManager.activeTab?.canGoForward ?? false))
                }

                // Address bar (centered)
                ToolbarItem(id: "address", placement: .principal) {
                    BrowserAddressField(
                        urlText: $urlText,
                        isSecure: tabManager.activeTab?.isSecure ?? false,
                        isLoading: tabManager.activeTab?.isLoading ?? false,
                        isURLFieldFocused: $isURLFieldFocused,
                        onSubmit: { navigateToURL(tabManager: tabManager) }
                    )
                    .frame(maxWidth: 600)
                    .onChange(of: tabManager.activeTab?.currentURL) { _, newURL in
                        if !isURLFieldFocused {
                            urlText = newURL ?? ""
                        }
                    }
                    .onAppear {
                        urlText = tabManager.activeTab?.currentURL ?? ""
                    }
                }

                // Dark mode
                ToolbarItem(id: "darkMode") {
                    Button(action: { tabManager.activeTab?.toggleDarkMode() }) {
                        Image(systemName: tabManager.activeTab?.isDarkMode == true ? "moon.fill" : "moon")
                    }
                }

                // New tab
                ToolbarItem(id: "newTab") {
                    Button(action: { tabManager.newTab() }) {
                        Image(systemName: "plus")
                    }
                }

            case .product(let product):
                ToolbarItem(id: "context", placement: .principal) {
                    Label(product.name, systemImage: "leaf")
                        .font(.system(size: 13, weight: .medium))
                }

            case .conversation(let conversation):
                ToolbarItem(id: "context", placement: .principal) {
                    Label(conversation.displayTitle, systemImage: conversation.chatTypeIcon)
                        .font(.system(size: 13, weight: .medium))
                }

            case .category(let category):
                ToolbarItem(id: "context", placement: .principal) {
                    Label(category.name, systemImage: "folder")
                        .font(.system(size: 13, weight: .medium))
                }

            case .creation(let creation):
                ToolbarItem(id: "context", placement: .principal) {
                    Label(creation.name, systemImage: creation.creationType.icon)
                        .font(.system(size: 13, weight: .medium))
                }
            }
        } else if let browserSession = store.selectedBrowserSession {
            let tabManager = BrowserTabManager.forSession(browserSession.id)
            // Browser controls for selected session
            ToolbarItem(id: "back") {
                Button(action: { tabManager.activeTab?.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!(tabManager.activeTab?.canGoBack ?? false))
            }

            ToolbarItem(id: "forward") {
                Button(action: { tabManager.activeTab?.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!(tabManager.activeTab?.canGoForward ?? false))
            }

            ToolbarItem(id: "address", placement: .principal) {
                BrowserAddressField(
                    urlText: $urlText,
                    isSecure: tabManager.activeTab?.isSecure ?? false,
                    isLoading: tabManager.activeTab?.isLoading ?? false,
                    isURLFieldFocused: $isURLFieldFocused,
                    onSubmit: { navigateToURL(tabManager: tabManager) }
                )
                .frame(maxWidth: 600)
                .onChange(of: tabManager.activeTab?.currentURL) { _, newURL in
                    if !isURLFieldFocused {
                        urlText = newURL ?? ""
                    }
                }
                .onAppear {
                    urlText = tabManager.activeTab?.currentURL ?? ""
                }
            }

            ToolbarItem(id: "darkMode") {
                Button(action: { tabManager.activeTab?.toggleDarkMode() }) {
                    Image(systemName: tabManager.activeTab?.isDarkMode == true ? "moon.fill" : "moon")
                }
            }

            ToolbarItem(id: "newTab") {
                Button(action: { tabManager.newTab() }) {
                    Image(systemName: "plus")
                }
            }
        } else {
            // Empty state - no toolbar items
            ToolbarItem(id: "empty", placement: .principal) {
                Text("")
            }
        }
    }

    private var contextTitle: String {
        if let activeTab = store.activeTab {
            switch activeTab {
            case .creation: return "Creation"
            case .product: return "Product"
            case .conversation: return "Team Chat"
            case .category: return "Category"
            case .browserSession: return "Browser"
            }
        } else if store.selectedBrowserSession != nil {
            return "Browser"
        } else if store.selectedConversation != nil {
            return "Team Chat"
        } else if store.selectedProduct != nil {
            return "Product"
        } else if store.selectedCreation != nil {
            return "Creation"
        } else if store.selectedCategory != nil {
            return "Category"
        }
        return ""
    }

    private func navigateToURL(tabManager: BrowserTabManager) {
        guard !urlText.isEmpty else { return }
        var urlString = urlText.trimmingCharacters(in: .whitespaces)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if urlString.contains(".") {
                urlString = "https://" + urlString
            } else {
                urlString = "https://www.google.com/search?q=" + urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            }
        }
        tabManager.activeTab?.navigate(to: urlString)
        isURLFieldFocused = false
    }
}

// MARK: - Browser Address Field (Titlebar-integrated)


import SwiftUI

