import SwiftUI

// MARK: - Product Selector Sheet
// Apple-native design: instant, no async UI loading, all data pre-loaded

struct ProductSelectorSheet: View {
    @ObservedObject var store: EditorStore
    @ObservedObject var cartStore: CartStore
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var showTierSelector = false
    @State private var selectedProduct: Product?

    var body: some View {
        HStack(spacing: 0) {
            // Category sidebar
            categoryList
                .frame(width: 200)

            Divider()

            // Main content
            VStack(spacing: 0) {
                // Header with search
                headerBar

                // Product grid - instant scrolling
                productGrid
            }
        }
        .frame(width: 1100, height: 700)
        .sheet(item: $selectedProduct) { product in
            TierSelectorSheet(
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

    // MARK: - Category List

    private var categoryList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Categories")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 1) {
                    categoryRow(title: "In Stock", icon: "checkmark.circle.fill", category: nil)
                    ForEach(store.categories) { category in
                        categoryRow(title: category.name, icon: "folder", category: category)
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func categoryRow(title: String, icon: String, category: Category?) -> some View {
        let isSelected = selectedCategory?.id == category?.id
        return Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                TextField("Search products...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Spacer()

            Button { onDismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Product Grid

    private var productGrid: some View {
        ScrollView {
            if filteredProducts.isEmpty {
                emptyState
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(180), spacing: 0), count: 5),
                    spacing: 0
                ) {
                    ForEach(filteredProducts) { product in
                        ProductCard(product: product) {
                            selectedProduct = product
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No products in stock")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var filteredProducts: [Product] {
        store.products
            .filter { product in
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

    // MARK: - Add to Cart

    private func addToCart(product: Product, quantity: Int, tier: PricingTier?) async {
        guard let cartId = cartStore.cart?.id else { return }

        do {
            cartStore.cart = try await CartService().addToCart(
                cartId: cartId,
                productId: product.id,
                quantity: quantity,
                tierLabel: tier?.label,
                tierQuantity: tier?.quantity,
                variantId: nil
            )
            NSLog("✅ Added \(quantity)x \(product.name) to cart")
        } catch {
            NSLog("❌ Cart error: \(error)")
        }
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: Product
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Product image
                if let imageURL = product.featuredImage, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        placeholderView
                    }
                    .frame(width: 180, height: 180)
                    .clipped()
                } else {
                    placeholderView.frame(width: 180, height: 180)
                }

                // Product info
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    if let price = product.wholesalePrice {
                        Text(formatCurrency(price))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(width: 180, alignment: .leading)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(Rectangle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var placeholderView: some View {
        ZStack {
            Rectangle().fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
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

// MARK: - Tier Selector Sheet (Native macOS Form)

struct TierSelectorSheet: View {
    let product: Product
    let pricingSchemas: [PricingSchema]
    let onAdd: (Int, PricingTier?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: PricingTier?
    @State private var quantity: Int = 1

    private var tiers: [PricingTier] {
        guard let schemaId = product.pricingSchemaId,
              let schema = pricingSchemas.first(where: { $0.id == schemaId }) else {
            return []
        }
        return schema.tiers.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(product.name)
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Native Form
            Form {
                // Tier picker (if available)
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
                    .pickerStyle(.inline)
                }

                // Quantity
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)

                // Price summary
                Section {
                    LabeledContent("Price") {
                        Text(formatCurrency(currentPrice))
                            .fontWeight(.medium)
                    }

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
                Button("Add to Cart") {
                    onAdd(quantity, selectedTier)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 400, height: tiers.isEmpty ? 300 : 500)
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
