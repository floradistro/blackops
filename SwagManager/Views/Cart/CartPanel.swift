import SwiftUI

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

    var body: some View {
        ZStack {
            // Main content - product browser
            VStack(spacing: 0) {
                // Header with search
                headerBar

                Divider()

                // Product grid
                productBrowser
            }
            .background(Color(NSColor.controlBackgroundColor))

            // Floating cart at bottom (Apple/Whale pattern)
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
        }
        .background(Color.black)
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
                onComplete: {
                    showCheckout = false
                }
            )
        }
        .sheet(item: $selectedProduct) { product in
            QuickAddSheet(
                product: product,
                pricingSchemas: store.pricingSchemas,
                onAdd: { quantity, tier in
                    Task {
                        await addToCart(product: product, quantity: quantity, tier: tier)
                    }
                }
            )
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))

                TextField("Search products...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(8)

            // Category picker (compact)
            Menu {
                Button("All Categories") {
                    selectedCategory = nil
                }

                Divider()

                ForEach(store.categories) { category in
                    Button(category.name) {
                        selectedCategory = category
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 13))
                    Text(selectedCategory?.name ?? "All")
                        .font(.system(size: 13))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(8)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Product Browser

    private var productBrowser: some View {
        ScrollView {
            if filteredProducts.isEmpty {
                emptyState
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                    spacing: 12
                ) {
                    ForEach(filteredProducts) { product in
                        ProductTile(product: product) {
                            selectedProduct = product
                        }
                    }
                }
                .padding(16)
            }
        }
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

    private var filteredProducts: [Product] {
        store.products.filter { product in
            // In stock filter
            guard let status = product.stockStatus else { return false }
            let inStock = status.lowercased() == "in_stock" || status.lowercased() == "instock"
            guard inStock else { return false }

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
        await cartStore.addProduct(
            productId: product.id,
            quantity: quantity,
            tierLabel: tier?.label,
            tierQuantity: tier?.quantity,
            variantId: nil
        )
    }
}

// MARK: - Product Tile (Compact)

struct ProductTile: View {
    let product: Product
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Image
                if let imageURL = product.featuredImage, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        placeholderView
                    }
                    .frame(height: 140)
                    .clipped()
                } else {
                    placeholderView.frame(height: 140)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    if let price = product.wholesalePrice {
                        Text(formatCurrency(price))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var placeholderView: some View {
        ZStack {
            Rectangle().fill(Color(NSColor.controlBackgroundColor))
            Image(systemName: "leaf")
                .font(.system(size: 32))
                .foregroundStyle(.secondary.opacity(0.3))
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

// MARK: - Floating Cart Dock (Whale pattern)

struct FloatingCartDock: View {
    @ObservedObject var cartStore: CartStore
    let customerName: String
    let onCheckout: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack {
            Spacer()

            // Customer tab
            HStack(spacing: 8) {
                Spacer()

                HStack(spacing: 8) {
                    // Customer initials
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(customerInitials)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        )

                    Text(customerName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)

                    if let cart = cartStore.cart, !cart.isEmpty {
                        Text("\(cart.itemCount)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.horizontal, 16)

            // Cart pill
            if let cart = cartStore.cart, !cart.isEmpty {
                HStack(spacing: 12) {
                    // Items summary
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(cart.itemCount) items")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(formatCurrency(cart.totals.total))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // Checkout button
                    Button {
                        onCheckout()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard")
                            Text("Checkout")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
            }
        }
        .padding(.bottom, 16)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: cartStore.cart?.isEmpty)
    }

    private var customerInitials: String {
        let parts = customerName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(customerName.prefix(2)).uppercased()
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

// MARK: - Quick Add Sheet (Simple, native)

struct QuickAddSheet: View {
    let product: Product
    let pricingSchemas: [PricingSchema]
    let onAdd: (Int, PricingTier?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: PricingTier?
    @State private var quantity: Int = 1

    private var tiers: [PricingTier] {
        NSLog("[QuickAddSheet] Loading tiers for product: %@", product.name)
        NSLog("[QuickAddSheet] pricingSchemas count: %d", pricingSchemas.count)
        NSLog("[QuickAddSheet] product.pricingSchemaId: %@", product.pricingSchemaId?.uuidString ?? "nil")

        guard let schemaId = product.pricingSchemaId else {
            NSLog("[QuickAddSheet] ❌ No pricingSchemaId for product")
            return []
        }

        guard let schema = pricingSchemas.first(where: { $0.id == schemaId }) else {
            NSLog("[QuickAddSheet] ❌ No matching schema found for id: %@", schemaId.uuidString)
            return []
        }

        let sortedTiers = schema.tiers.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
        NSLog("[QuickAddSheet] ✅ Found %d tiers", sortedTiers.count)
        return sortedTiers
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline)
                    Text(formatCurrency(currentPrice))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            // Content
            Form {
                if !tiers.isEmpty {
                    Picker("Size", selection: $selectedTier) {
                        ForEach(tiers, id: \.id) { tier in
                            HStack {
                                Text(tier.displayLabel)
                                Spacer()
                                if let price = tier.defaultPrice {
                                    Text(formatCurrency(price))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(tier as PricingTier?)
                        }
                    }
                }

                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)

                Section {
                    LabeledContent("Total") {
                        Text(formatCurrency(currentPrice * Decimal(quantity)))
                            .fontWeight(.semibold)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                Spacer()
                Button {
                    onAdd(quantity, selectedTier)
                    dismiss()
                } label: {
                    Text("Add to Cart")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: tiers.isEmpty ? 280 : 450)
        .onAppear {
            selectedTier = tiers.first
        }
    }

    private var currentPrice: Decimal {
        selectedTier?.defaultPrice ?? product.wholesalePrice ?? 0
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

// MARK: - Cart Store

@MainActor
class CartStore: ObservableObject {
    @Published var cart: ServerCart?
    @Published var isLoading = false
    @Published var error: String?

    private let cartService = CartService()

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

    func addProduct(productId: UUID, quantity: Int = 1, tierLabel: String?, tierQuantity: Double?, variantId: UUID?) async {
        NSLog("[CartStore] addProduct called - cartId: \(cart?.id.uuidString ?? "nil"), productId: \(productId.uuidString)")
        NSLog("[CartStore] - quantity: \(quantity), tierLabel: \(tierLabel ?? "nil"), tierQuantity: \(tierQuantity.map { String($0) } ?? "nil")")

        guard let cartId = cart?.id else {
            NSLog("[CartStore] ❌ ERROR: No cart ID available")
            return
        }

        do {
            cart = try await cartService.addToCart(
                cartId: cartId,
                productId: productId,
                quantity: quantity,
                tierLabel: tierLabel,
                tierQuantity: tierQuantity,
                variantId: variantId
            )
            NSLog("[CartStore] ✅ Successfully added \(quantity)x product \(productId) to cart")
        } catch {
            self.error = error.localizedDescription
            NSLog("[CartStore] ❌ Failed to add product: \(error)")
        }
    }
}
