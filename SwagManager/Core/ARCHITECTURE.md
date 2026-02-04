# SwagManager Architecture v2

## Apple-Style Architecture

### Layer 1: SwiftData Models (Single Source of Truth)

```swift
@Model
class SDOrder {
    @Attribute(.unique) var id: UUID
    var orderNumber: String
    var status: String
    var totalAmount: Decimal
    var createdAt: Date

    @Relationship var customer: SDCustomer?
    @Relationship var location: SDLocation?
    @Relationship(deleteRule: .cascade) var items: [SDOrderItem]

    // Computed - no storage
    var isActive: Bool {
        ["pending", "confirmed", "preparing", "ready"].contains(status)
    }
}

@Model
class SDLocation {
    @Attribute(.unique) var id: UUID
    var name: String
    var isActive: Bool

    @Relationship(inverse: \SDOrder.location) var orders: [SDOrder]
    @Relationship var queueEntries: [SDQueueEntry]
}
```

### Layer 2: Background Sync Service (One Service)

```swift
@MainActor
class SyncService {
    static let shared = SyncService()

    private let supabase = SupabaseClient(...)
    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        startRealtimeSync()
    }

    // Syncs Supabase → SwiftData in background
    func syncOrders() async {
        let remote = try await supabase.from("orders").select().execute()
        // Upsert into SwiftData
        for order in remote {
            let local = SDOrder(from: order)
            modelContext?.insert(local)
        }
    }
}
```

### Layer 3: Views with @Query (No Store Needed)

```swift
struct SidebarView: View {
    // Automatic, reactive, no manual loading
    @Query(sort: \SDLocation.name) var locations: [SDLocation]
    @Query(filter: #Predicate { $0.isActive }) var activeOrders: [SDOrder]

    var body: some View {
        List {
            Section("Locations") {
                ForEach(locations) { location in
                    NavigationLink(value: location) {
                        Label(location.name, systemImage: "building.2")
                    }
                }
            }

            Section("Active Orders") {
                ForEach(activeOrders) { order in
                    NavigationLink(value: order) {
                        OrderRow(order: order)
                    }
                }
            }
        }
    }
}
```

### Layer 4: NavigationSplitView (Single Selection)

```swift
@main
struct SwagManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [SDOrder.self, SDLocation.self, SDCustomer.self])
        }
    }
}

struct ContentView: View {
    @State private var selection: NavigationItem?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .order(let order):
                OrderDetailView(order: order)
            case .location(let location):
                LocationDetailView(location: location)
            case .none:
                WelcomeView()
            }
        }
    }
}
```

---

## Migration Path

### Phase 1: SwiftData Models
1. Create `@Model` classes for core entities
2. Set up ModelContainer in App
3. Keep existing Supabase services for now

### Phase 2: Background Sync
1. Create SyncService that syncs Supabase → SwiftData
2. Run sync on app launch and periodically
3. SwiftData becomes the read source

### Phase 3: Replace Views
1. Replace `@ObservedObject var store` with `@Query`
2. Remove manual `loadOrders()`, `isLoadingOrders`, etc.
3. Views become stateless

### Phase 4: Cleanup
1. Remove EditorStore, OrderTreeStore, etc.
2. Remove all manual state management
3. Keep only SyncService for Supabase communication

---

## Key Principles

1. **SwiftData is the source of truth** - Views read from SwiftData, not API
2. **Sync in background** - API calls happen in background, update SwiftData
3. **@Query is reactive** - Views auto-update when data changes
4. **No loading states** - Data is always available (from cache), sync happens invisibly
5. **Single navigation state** - One `@State var selection` drives everything
6. **No computed properties in views** - Use SwiftData predicates instead

---

## File Structure

```
SwagManager/
├── App/
│   └── SwagManagerApp.swift      # ModelContainer setup
├── Core/
│   ├── Models/                   # @Model classes
│   │   ├── SDOrder.swift
│   │   ├── SDLocation.swift
│   │   ├── SDCustomer.swift
│   │   └── SDProduct.swift
│   ├── Sync/
│   │   └── SyncService.swift     # Supabase → SwiftData sync
│   └── Navigation/
│       └── NavigationItem.swift  # Unified navigation enum
├── Features/
│   ├── Sidebar/
│   │   └── SidebarView.swift     # @Query, no store
│   ├── Orders/
│   │   ├── OrderListView.swift
│   │   └── OrderDetailView.swift
│   ├── Locations/
│   │   └── LocationDetailView.swift
│   └── Products/
│       └── ProductListView.swift
└── Legacy/                       # Old code during migration
    ├── Stores/
    └── Services/
```

---

## Benefits

| Before | After |
|--------|-------|
| 15+ service files | 1 SyncService |
| Manual state management | Automatic @Query |
| Loading spinners everywhere | Instant from cache |
| Complex view hierarchy | Flat NavigationSplitView |
| Glitchy animations | Native List performance |
| Hard to maintain | Simple, declarative |
