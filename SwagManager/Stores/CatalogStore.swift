import SwiftUI
import Combine

// MARK: - CatalogStore
// Domain-specific store for catalog, products, and categories
// Isolated from other domains to prevent observation cascade

@MainActor
@Observable
final class CatalogStore {
    // MARK: - State

    private(set) var catalogs: [Catalog] = []
    private(set) var categories: [Category] = []
    private(set) var products: [Product] = []
    private(set) var pricingSchemas: [PricingSchema] = []

    var selectedCatalog: Catalog?
    var selectedCategory: Category?
    var selectedProduct: Product?
    var selectedProductIds: Set<UUID> = []

    private(set) var isLoading = false
    private(set) var error: String?

    // MARK: - Private

    @ObservationIgnored private let supabase = SupabaseService.shared
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    // MARK: - Load Data

    func loadCatalogData(storeId: UUID, catalogId: UUID?) async {
        // Cancel any in-flight request
        loadTask?.cancel()

        loadTask = Task {
            isLoading = true
            defer { isLoading = false }

            do {
                // Fetch in parallel on background threads
                async let fetchedCatalogs = supabase.catalogs.fetchCatalogs(storeId: storeId)
                async let fetchedCategories = supabase.catalogs.fetchCategories(storeId: storeId, catalogId: catalogId)
                async let fetchedProducts = supabase.products.fetchProducts(storeId: storeId, catalogId: catalogId)
                async let fetchedSchemas = supabase.products.fetchPricingSchemas(storeId: storeId)

                let (cats, categories, products, schemas) = try await (
                    fetchedCatalogs,
                    fetchedCategories,
                    fetchedProducts,
                    fetchedSchemas
                )

                // Check if cancelled before updating UI
                guard !Task.isCancelled else { return }

                // Single batch update
                self.catalogs = cats
                self.categories = categories
                self.products = products
                self.pricingSchemas = schemas

                // Auto-select first catalog if none selected
                if selectedCatalog == nil, let first = cats.first {
                    selectedCatalog = first
                }

            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
        }

        await loadTask?.value
    }

    // MARK: - Filtering (Background)

    func productsForCategory(_ categoryId: UUID) -> [Product] {
        products.filter { $0.primaryCategoryId == categoryId }
    }

    func categoriesForCatalog(_ catalogId: UUID) -> [Category] {
        categories.filter { $0.catalogId == catalogId }
    }

    // MARK: - Selection

    func selectProduct(_ product: Product) {
        selectedProduct = product
        selectedProductIds = [product.id]
        selectedCategory = nil
    }

    func selectCategory(_ category: Category) {
        selectedCategory = category
        selectedProduct = nil
        selectedProductIds = []
    }

    func clearSelection() {
        selectedProduct = nil
        selectedCategory = nil
        selectedProductIds = []
    }

    // MARK: - Clear

    func clear() {
        loadTask?.cancel()
        catalogs = []
        categories = []
        products = []
        pricingSchemas = []
        selectedCatalog = nil
        selectedCategory = nil
        selectedProduct = nil
        selectedProductIds = []
        error = nil
    }
}

// MARK: - Environment Key

private struct CatalogStoreKey: EnvironmentKey {
    static let defaultValue: CatalogStore? = nil
}

extension EnvironmentValues {
    var catalogStore: CatalogStore? {
        get { self[CatalogStoreKey.self] }
        set { self[CatalogStoreKey.self] = newValue }
    }
}
