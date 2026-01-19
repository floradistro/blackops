import SwiftUI
import Supabase

// MARK: - Catalog Store (Focused on Products & Categories)

/// Manages stores, catalogs, products, and categories
/// Single responsibility: Product catalog management
@MainActor
class CatalogStore: ObservableObject {

    // MARK: - Published State

    @Published var stores: [Store] = []
    @Published var selectedStore: Store?

    @Published var catalogs: [Catalog] = []
    @Published var selectedCatalog: Catalog?

    @Published var products: [Product] = []
    @Published var selectedProduct: Product?
    @Published var selectedProductIds: Set<UUID> = []

    @Published var categories: [Category] = []
    @Published var selectedCategory: Category?

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?

    // MARK: - Private State

    private var productIndex: [UUID: Product] = [:] // O(1) lookups
    private var categoryIndex: [UUID: Category] = [:]
    private var lastSelectedIndex: Int?

    private let supabase = SupabaseService.shared

    // MARK: - Computed Properties

    var selectedProducts: [Product] {
        selectedProductIds.compactMap { productIndex[$0] }
    }

    var activeStoreId: UUID? {
        selectedStore?.id
    }

    // MARK: - Queries

    func productsForCategory(_ categoryId: UUID) -> [Product] {
        products.filter { $0.primaryCategoryId == categoryId }
    }

    func categoriesForCatalog(_ catalogId: UUID) -> [Category] {
        categories.filter { $0.catalogId == catalogId }
    }

    // MARK: - Data Loading

    func loadStores() async {
        isLoading = true
        defer { isLoading = false }

        do {
            stores = try await supabase.fetchStores()
            NSLog("[CatalogStore] Loaded \(stores.count) stores")

            // Auto-select first store if none selected
            if selectedStore == nil, let first = stores.first {
                selectedStore = first
                await loadCatalogsForCurrentStore()
            }
        } catch {
            NSLog("[CatalogStore] Error loading stores: \(error)")
            self.error = "Failed to load stores: \(error.localizedDescription)"
        }
    }

    func loadCatalogsForCurrentStore() async {
        guard let storeId = selectedStore?.id else { return }

        do {
            catalogs = try await supabase.fetchCatalogs(storeId: storeId)
            NSLog("[CatalogStore] Loaded \(catalogs.count) catalogs for store")

            // Auto-select first catalog
            if selectedCatalog == nil, let first = catalogs.first {
                selectedCatalog = first
            }
        } catch {
            NSLog("[CatalogStore] Error loading catalogs: \(error)")
            self.error = "Failed to load catalogs: \(error.localizedDescription)"
        }
    }

    func loadProductsForCurrentStore() async {
        guard let storeId = selectedStore?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            products = try await supabase.fetchProducts(storeId: storeId)
            rebuildProductIndex()
            NSLog("[CatalogStore] Loaded \(products.count) products")
        } catch {
            NSLog("[CatalogStore] Error loading products: \(error)")
            self.error = "Failed to load products: \(error.localizedDescription)"
        }
    }

    func loadCategoriesForCurrentCatalog() async {
        guard let catalogId = selectedCatalog?.id else { return }

        do {
            categories = try await supabase.fetchCategories(catalogId: catalogId)
            rebuildCategoryIndex()
            NSLog("[CatalogStore] Loaded \(categories.count) categories")
        } catch {
            NSLog("[CatalogStore] Error loading categories: \(error)")
            self.error = "Failed to load categories: \(error.localizedDescription)"
        }
    }

    // MARK: - Store Selection

    func selectStore(_ store: Store) async {
        selectedStore = store
        selectedCatalog = nil
        selectedCategory = nil
        products.removeAll()
        categories.removeAll()

        await loadCatalogsForCurrentStore()
        await loadProductsForCurrentStore()
    }

    // MARK: - Product Selection

    func selectProduct(_ product: Product, add: Bool = false, range: Bool = false, in list: [Product] = []) {
        if range, let lastIdx = lastSelectedIndex, let currentIdx = list.firstIndex(where: { $0.id == product.id }) {
            // Shift+click: select range
            let start = min(lastIdx, currentIdx)
            let end = max(lastIdx, currentIdx)
            for i in start...end {
                selectedProductIds.insert(list[i].id)
            }
        } else if add {
            // Cmd+click: toggle selection
            if selectedProductIds.contains(product.id) {
                selectedProductIds.remove(product.id)
                if selectedProduct?.id == product.id {
                    selectedProduct = selectedProducts.first
                }
            } else {
                selectedProductIds.insert(product.id)
            }
        } else {
            // Normal click: single select
            selectedProductIds = [product.id]
        }

        // Update active product
        if selectedProductIds.contains(product.id) {
            selectedProduct = product
            lastSelectedIndex = list.firstIndex(where: { $0.id == product.id })
        }
    }

    func clearProductSelection() {
        selectedProductIds.removeAll()
        selectedProduct = nil
        lastSelectedIndex = nil
    }

    // MARK: - CRUD Operations

    func updateProduct(id: UUID, update: ProductUpdate) async {
        isSaving = true
        defer { isSaving = false }

        do {
            let updated = try await supabase.updateProduct(id: id, update: update)
            updateProductInStore(updated)
            if selectedProduct?.id == id {
                selectedProduct = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteProduct(_ product: Product) async {
        do {
            try await supabase.deleteProduct(id: product.id)
            if selectedProduct?.id == product.id {
                selectedProduct = nil
            }
            selectedProductIds.remove(product.id)
            removeProductFromStore(product.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func rebuildProductIndex() {
        productIndex = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
    }

    private func rebuildCategoryIndex() {
        categoryIndex = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    private func updateProductInStore(_ product: Product) {
        productIndex[product.id] = product
        if let idx = products.firstIndex(where: { $0.id == product.id }) {
            products[idx] = product
        }
    }

    private func removeProductFromStore(_ id: UUID) {
        productIndex.removeValue(forKey: id)
        products.removeAll { $0.id == id }
    }
}
