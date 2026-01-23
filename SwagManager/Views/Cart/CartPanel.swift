import SwiftUI
import Supabase
import Realtime

// MARK: - Cart Panel (POS View)
// Full-screen POS interface with floating cart dock (Apple/Whale pattern)
// Replaces modal-on-modal approach with single unified view

struct CartPanel: View {
    @ObservedObject var store: EditorStore
    let queueEntry: QueueEntry

    @StateObject private var cartStore = CartStore()
    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var selectedProduct: Product?
    @State private var showCheckout = false
    @State private var popoverAnchor: CGRect = .zero
    @State private var selectedRegisterId: UUID? = nil
    @State private var availableRegisters: [Register] = []

    // Create SessionInfo for payment tracking
    private var sessionInfo: SessionInfo {
        SessionInfo(
            storeId: store.selectedStore?.id ?? UUID(),
            locationId: queueEntry.locationId,
            registerId: selectedRegisterId,
            userId: nil // TODO: Add user auth
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.black.ignoresSafeArea()

            // Product grid (edge-to-edge)
            productBrowser

            // Floating glass header (overlaid on top)
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    // Floating glass search bar
                    LiquidGlassSearchBar(
                        "Search products, SKU...",
                        text: $searchText
                    )

                    Spacer(minLength: 0)
                }

                // Category pills
                if !categoriesWithStock.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryPill(name: "All", isSelected: selectedCategory == nil) {
                                selectedCategory = nil
                            }

                            ForEach(categoriesWithStock, id: \.id) { category in
                                CategoryPill(name: category.name, isSelected: selectedCategory?.id == category.id) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // Floating cart at bottom
            VStack {
                Spacer()

                HStack {
                    Spacer()
                    FloatingCartDock(
                        cartStore: cartStore,
                        customerName: customerDisplayName,
                        onCheckout: {
                            showCheckout = true
                        },
                        onClose: {
                            if let activeTab = store.activeTab {
                                store.closeTab(activeTab)
                            }
                        }
                    )
                    Spacer()
                }
            }
        }
        .task {
            await cartStore.loadCart(
                storeId: store.selectedStore?.id ?? UUID(),
                locationId: queueEntry.locationId,
                customerId: queueEntry.customerId
            )

            // Pre-load pricing schemas for instant tier selection
            await loadPricingSchemas()
        }
        .sheet(isPresented: $showCheckout) {
            CheckoutSheet(
                cart: cartStore.cart!,
                queueEntry: queueEntry,
                store: store,
                sessionInfo: sessionInfo,
                onComplete: {
                    showCheckout = false
                    // Clean up after successful payment (matches iOS implementation)
                    Task {
                        NSLog("[CartPanel] Payment complete - removing from queue and clearing cart")

                        // 1. Remove customer from queue first
                        let queueStore = LocationQueueStore.shared(for: queueEntry.locationId)
                        await queueStore.removeFromQueue(cartId: queueEntry.cartId)

                        // 2. Clear the cart (fresh_start=true to remove all items)
                        await cartStore.clearCart()

                        // 3. Close the cart panel/tab
                        if let activeTab = store.activeTab {
                            await MainActor.run {
                                store.closeTab(activeTab)
                            }
                        }
                    }
                }
            )
        }
        .sheet(item: $selectedProduct) { product in
            TierSelectorSheet(
                product: product,
                pricingSchemas: store.pricingSchemas,
                onSelectTier: { tier in
                    Task {
                        await addToCart(product: product, quantity: 1, tier: tier)
                    }
                }
            )
        }
    }


    // MARK: - Product Browser

    private var productBrowser: some View {
        GeometryReader { geometry in
            let cols = calculateColumns(width: geometry.size.width)
            let width = geometry.size.width / CGFloat(cols)

            ScrollView(showsIndicators: false) {
                if filteredProducts.isEmpty {
                    emptyState
                        .padding(.top, 140)
                        .frame(width: geometry.size.width)
                } else {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(width), spacing: 0), count: cols),
                        spacing: 0
                    ) {
                        ForEach(Array(filteredProducts.enumerated()), id: \.element.id) { index, product in
                            ProductGridCard(
                                product: product,
                                showRightLine: (index + 1) % cols != 0,
                                showBottomLine: index < filteredProducts.count - cols
                            ) {
                                selectedProduct = product
                            }
                        }
                    }
                    .padding(.top, 120) // Space for floating header
                    .padding(.bottom, 140) // Space for floating cart
                }
            }
        }
    }

    private func calculateColumns(width: CGFloat) -> Int {
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 220
        let idealCardWidth: CGFloat = 180

        // Calculate how many cards fit at ideal width
        let idealCols = Int(width / idealCardWidth)

        // Ensure we have at least 3 columns, max 8
        let cols = max(3, min(8, idealCols))

        // Check if cards would be too small or too large
        let actualWidth = width / CGFloat(cols)
        if actualWidth < minCardWidth && cols > 3 {
            return cols - 1
        } else if actualWidth > maxCardWidth && cols < 8 {
            return cols + 1
        }

        return cols
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No products found")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// Categories that have at least one in-stock product at this location
    private var categoriesWithStock: [Category] {
        let productsByCategory = Dictionary(grouping: locationProducts) { $0.primaryCategoryId }
        return store.categories.filter { category in
            productsByCategory[category.id]?.contains { isProductInStock($0) } ?? false
        }
    }

    /// Products available at this specific location
    /// TODO: Add location-based filtering when product-location relationship is established
    private var locationProducts: [Product] {
        // For now, show all products
        // In the future, filter by: product.locationIds?.contains(queueEntry.locationId) ?? false
        store.products
    }

    /// Final filtered products (by location, stock, category, search)
    private var filteredProducts: [Product] {
        locationProducts.filter { product in
            // In stock filter
            guard isProductInStock(product) else { return false }

            // Category filter
            if let category = selectedCategory {
                guard product.primaryCategoryId == category.id else { return false }
            }

            // Search filter
            if !searchText.isEmpty {
                let matchesName = product.name.localizedCaseInsensitiveContains(searchText)
                let matchesSKU = product.sku?.localizedCaseInsensitiveContains(searchText) ?? false
                guard matchesName || matchesSKU else { return false }
            }

            return true
        }
    }

    private func isProductInStock(_ product: Product) -> Bool {
        guard let status = product.stockStatus else { return false }
        return status.lowercased() == "in_stock" || status.lowercased() == "instock"
    }

    // MARK: - Helpers

    private var customerDisplayName: String {
        if let firstName = queueEntry.customerFirstName,
           let lastName = queueEntry.customerLastName {
            return "\(firstName) \(lastName)"
        }
        return "Guest"
    }

    private func loadPricingSchemas() async {
        // Pricing schemas already loaded in EditorStore.loadCatalogData()
        // This is just a placeholder - schemas are pre-loaded
    }

    private func addToCart(product: Product, quantity: Int, tier: PricingTier?) async {
        NSLog("[CartPanel] addToCart - product: \(product.name), quantity: \(quantity), tier: \(tier?.label ?? "nil")")
        NSLog("[CartPanel] - tier.defaultPrice: \(tier.map { String(describing: $0.defaultPrice) } ?? "nil"), tier.quantity: \(tier.map { String($0.quantity) } ?? "nil")")
        await cartStore.addProduct(
            productId: product.id,
            quantity: quantity,
            unitPrice: tier?.defaultPrice,
            tierLabel: tier?.label,
            tierQuantity: tier?.quantity,
            variantId: nil,
            locationId: queueEntry.locationId
        )
    }
}

// MARK: - Legacy Product Tile (DEPRECATED - Use GlassProductCard)
// Kept for backward compatibility, will be removed in future version

// FloatingCartDock moved to separate file (FloatingCartDock.swift)

// QuickAddSheet removed - now using TierSelectorSheet with liquid glass design

// MARK: - Cart Store

@MainActor
class CartStore: ObservableObject {
    @Published var cart: ServerCart?
    @Published var isLoading = false
    @Published var error: String?

    private let cartService = CartService()
    private var cartRealtimeTask: Task<Void, Never>?

    func loadCart(storeId: UUID, locationId: UUID, customerId: UUID?) async {
        NSLog("[CartStore] loadCart called - storeId: \(storeId), locationId: \(locationId), customerId: \(customerId?.uuidString ?? "nil")")
        isLoading = true
        error = nil

        do {
            cart = try await cartService.getOrCreateCart(
                storeId: storeId,
                locationId: locationId,
                customerId: customerId,
                freshStart: false
            )
            NSLog("[CartStore] ✅ Cart loaded successfully - cartId: \(cart?.id.uuidString ?? "nil"), items: \(cart?.itemCount ?? 0)")

            // Subscribe to realtime updates for this cart
            if let cartId = cart?.id {
                subscribeToCart(cartId: cartId)
            }
        } catch {
            self.error = error.localizedDescription
            NSLog("[CartStore] ❌ Failed to load cart: \(error)")
        }

        isLoading = false
    }

    func updateQuantity(itemId: UUID, quantity: Int) async {
        guard let cartId = cart?.id else { return }

        do {
            cart = try await cartService.updateItemQuantity(
                cartId: cartId,
                itemId: itemId,
                quantity: quantity
            )
        } catch {
            self.error = error.localizedDescription
            NSLog("[CartStore] Failed to update quantity: \(error)")
        }
    }

    func removeItem(itemId: UUID) async {
        guard let cartId = cart?.id else { return }

        do {
            cart = try await cartService.removeFromCart(
                cartId: cartId,
                itemId: itemId
            )
        } catch {
            self.error = error.localizedDescription
            NSLog("[CartStore] Failed to remove item: \(error)")
        }
    }

    func clearCart() async {
        guard let cartId = cart?.id else { return }

        do {
            cart = try await cartService.clearCart(cartId: cartId)
        } catch {
            self.error = error.localizedDescription
            NSLog("[CartStore] Failed to clear cart: \(error)")
        }
    }

    func addProduct(productId: UUID, quantity: Int = 1, unitPrice: Decimal?, tierLabel: String?, tierQuantity: Double?, variantId: UUID?, locationId: UUID? = nil) async {
        NSLog("[CartStore] addProduct called - cartId: \(cart?.id.uuidString ?? "nil"), productId: \(productId.uuidString)")
        NSLog("[CartStore] - quantity: \(quantity), unitPrice: \(unitPrice.map { String(describing: $0) } ?? "nil"), tierLabel: \(tierLabel ?? "nil"), tierQuantity: \(tierQuantity.map { String($0) } ?? "nil")")

        guard let cartId = cart?.id else {
            NSLog("[CartStore] ❌ ERROR: No cart ID available")
            return
        }

        // Get inventory_id for this product at this location
        var inventoryId: UUID? = nil
        if let locId = locationId ?? cart?.locationId {
            do {
                // Simple struct just for ID query
                struct InventoryID: Codable {
                    let id: UUID
                }

                // Query inventory for this product at this location
                let inventory: [InventoryID] = try await SupabaseService.shared.client
                    .from("inventory")
                    .select("id")
                    .eq("product_id", value: productId.uuidString)
                    .eq("location_id", value: locId.uuidString)
                    .gt("available_quantity", value: 0)
                    .order("available_quantity", ascending: false)
                    .limit(1)
                    .execute()
                    .value

                inventoryId = inventory.first?.id
                if let invId = inventoryId {
                    NSLog("[CartStore] Found inventory: \(invId.uuidString)")
                } else {
                    NSLog("[CartStore] ⚠️ No inventory found for product at location")
                }
            } catch {
                NSLog("[CartStore] ⚠️ Failed to query inventory: \(error)")
            }
        }

        do {
            cart = try await cartService.addToCart(
                cartId: cartId,
                productId: productId,
                quantity: quantity,
                unitPrice: unitPrice,
                tierLabel: tierLabel,
                tierQuantity: tierQuantity,
                variantId: variantId,
                inventoryId: inventoryId
            )
            NSLog("[CartStore] ✅ Successfully added \(quantity)x product \(productId) to cart")
        } catch {
            self.error = error.localizedDescription
            NSLog("[CartStore] ❌ Failed to add product: \(error)")
        }
    }

    // MARK: - Realtime Updates

    private func subscribeToCart(cartId: UUID) {
        // Cancel any existing subscription
        unsubscribeFromCart()

        let channelName = "cart-updates-\(cartId.uuidString.prefix(8))-\(UInt64(Date().timeIntervalSince1970 * 1000))"
        let supabase = SupabaseService.shared.client

        NSLog("[CartStore] 🔌 Creating realtime channel: \(channelName)")

        // Use realtimeV2 API matching queue implementation
        let channel = supabase.realtimeV2.channel(channelName)

        // Subscribe to cart table changes (totals, discounts)
        let cartChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "carts",
            filter: "id=eq.\(cartId)"
        )

        // Subscribe to cart_items table changes (items added/removed/updated)
        let itemChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "cart_items",
            filter: "cart_id=eq.\(cartId)"
        )

        // Subscribe and listen in background task (matching queue pattern)
        cartRealtimeTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                NSLog("[CartStore] Subscribing to channel...")
                try await channel.subscribeWithError()

                NSLog("[CartStore] ✅ Subscribed to realtime for cart \(cartId)")

                // Listen for both event types concurrently
                await withTaskGroup(of: Void.self) { group in
                    // Listen for cart changes
                    group.addTask { [weak self] in
                        for await _ in cartChanges {
                            guard !Task.isCancelled else { break }
                            await self?.handleCartUpdate(cartId: cartId)
                        }
                    }

                    // Listen for item changes
                    group.addTask { [weak self] in
                        for await _ in itemChanges {
                            guard !Task.isCancelled else { break }
                            await self?.handleCartUpdate(cartId: cartId)
                        }
                    }

                    await group.waitForAll()
                }

                NSLog("[CartStore] Realtime listener loop ended")
                await channel.unsubscribe()
            } catch {
                NSLog("[CartStore] ❌ Subscription error: \(error.localizedDescription)")
            }
        }
    }

    private func handleCartUpdate(cartId: UUID) async {
        NSLog("[CartStore] 🔄 Cart update received - refetching from server")

        guard let currentCart = cart else { return }

        do {
            // Refetch cart from server to get updated data
            let updatedCart = try await cartService.getOrCreateCart(
                storeId: currentCart.storeId,
                locationId: currentCart.locationId,
                customerId: currentCart.customerId,
                freshStart: false
            )

            cart = updatedCart
            NSLog("[CartStore] ✅ Cart updated from realtime")
        } catch {
            NSLog("[CartStore] ❌ Failed to refetch cart: \(error)")
        }
    }

    private func unsubscribeFromCart() {
        cartRealtimeTask?.cancel()
        cartRealtimeTask = nil
        NSLog("[CartStore] Unsubscribed from cart updates")
    }

}

// MARK: - Product Grid Card (iOS-style, edge-to-edge)

struct ProductGridCard: View {
    let product: Product
    var showRightLine: Bool = true
    var showBottomLine: Bool = true
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Product image - fixed aspect ratio 1:1
                ZStack {
                    if let imageUrl = product.featuredImage, let url = URL(string: imageUrl) {
                        CachedAsyncImage(url: url)
                            .aspectRatio(1, contentMode: .fill)
                            .overlay(Color.black.opacity(0.15))
                    } else {
                        Color.black.opacity(0.3)
                            .aspectRatio(1, contentMode: .fill)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.white.opacity(0.15))
                                    .font(.system(size: 32))
                            )
                    }
                }

                // Product info
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(product.sku ?? " ")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                .padding(10)
                .background(Color.black.opacity(0.7))
            }
            .overlay(alignment: .trailing) {
                if showRightLine {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 0.5)
                }
            }
            .overlay(alignment: .bottom) {
                if showBottomLine {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 0.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(GridCardPressStyle())
    }
}

// MARK: - Grid Card Press Style

struct GridCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Legacy Glass Product Card (kept for compatibility)

struct GlassProductCard: View {
    let product: Product
    let size: CardSize
    let showPrice: Bool
    let showStock: Bool
    let action: () -> Void

    enum CardSize {
        case compact
        case normal
    }

    var body: some View {
        ProductGridCard(product: product, onTap: action)
    }
}
