import SwiftUI

// MARK: - Catalogs List View
// Shows all catalogs for the current store with category counts

struct CatalogsListView: View {
    var store: EditorStore
    @Binding var selection: SDSidebarItem?

    // Cached category counts
    @State private var categoryCounts: [UUID: Int] = [:]

    var body: some View {
        List {
            ForEach(store.catalogs) { catalog in
                NavigationLink(value: SDSidebarItem.catalogDetail(catalog.id)) {
                    CatalogRow(catalog: catalog, categoryCount: categoryCounts[catalog.id] ?? 0)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Catalogs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.showNewCatalogSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { updateCategoryCounts() }
        .onChange(of: store.categories.count) { _, _ in updateCategoryCounts() }
    }

    private func updateCategoryCounts() {
        var counts: [UUID: Int] = [:]
        for category in store.categories {
            if let catalogId = category.catalogId {
                counts[catalogId, default: 0] += 1
            }
        }
        categoryCounts = counts
    }
}

// MARK: - Catalog Row

struct CatalogRow: View {
    let catalog: Catalog
    let categoryCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(catalog.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("\(categoryCount) categories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if catalog.isDefault == true {
                        Text("Default")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Catalog Detail View

struct CatalogDetailView: View {
    let catalogId: UUID
    var store: EditorStore

    @State private var catalog: Catalog?
    @State private var cachedCategories: [Category] = []
    @State private var productCounts: [UUID: Int] = [:]

    var body: some View {
        List {
            ForEach(cachedCategories) { category in
                NavigationLink(value: SDSidebarItem.categoryDetail(category.id)) {
                    CategoryRow(
                        category: category,
                        productCount: productCounts[category.id] ?? 0
                    )
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle(catalog?.name ?? "Catalog")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: SDSidebarItem.catalogSettings(catalogId)) {
                    Image(systemName: "gear")
                }
            }
        }
        .task { loadData() }
        .onChange(of: store.categories.count) { _, _ in loadData() }
        .onChange(of: store.products.count) { _, _ in loadData() }
    }

    private func loadData() {
        catalog = store.catalogs.first { $0.id == catalogId }
        cachedCategories = store.categories
            .filter { $0.catalogId == catalogId }
            .sorted { $0.name < $1.name }

        var counts: [UUID: Int] = [:]
        for product in store.products where product.status != "archived" {
            if let catId = product.primaryCategoryId {
                counts[catId, default: 0] += 1
            }
        }
        productCounts = counts
    }
}

// MARK: - Catalog Settings View (Navigation-based)

struct CatalogSettingsView: View {
    let catalogId: UUID
    var store: EditorStore

    @State private var catalog: Catalog?
    @State private var categoryCount: Int = 0
    @State private var productCount: Int = 0

    var body: some View {
        Form {
            Section("General") {
                LabeledContent("Name", value: catalog?.name ?? "—")
                if let desc = catalog?.description, !desc.isEmpty {
                    LabeledContent("Description", value: desc)
                }
                if catalog?.isDefault == true {
                    LabeledContent("Default") {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                    }
                }
            }

            Section("Info") {
                LabeledContent("ID") {
                    Text(catalogId.uuidString.prefix(8).uppercased())
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Categories", value: "\(categoryCount)")
                LabeledContent("Products", value: "\(productCount)")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Catalog Settings")
        .task { loadData() }
    }

    private func loadData() {
        catalog = store.catalogs.first { $0.id == catalogId }
        let categories = store.categories.filter { $0.catalogId == catalogId }
        categoryCount = categories.count
        let categoryIds = Set(categories.map { $0.id })
        productCount = store.products.filter {
            guard let catId = $0.primaryCategoryId else { return false }
            return categoryIds.contains(catId) && $0.status != "archived"
        }.count
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: Category
    var productCount: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.fill")
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.subheadline.weight(.medium))
                Text("\(productCount) products")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Category Detail View
// Shows category details, products, and schema assignments

struct CategoryDetailView: View {
    let categoryId: UUID
    var store: EditorStore

    @State private var category: Category?
    @State private var searchText = ""
    @State private var allCategoryProducts: [Product] = []
    @State private var displayedProducts: [Product] = []

    var body: some View {
        List {
            ForEach(displayedProducts) { product in
                NavigationLink(value: SDSidebarItem.productDetail(product.id)) {
                    ProductListRow(product: product, showArchiveBadge: false)
                }
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Search products")
        .navigationTitle(category?.name ?? "Category")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: SDSidebarItem.categorySettings(categoryId)) {
                    Image(systemName: "gear")
                }
            }
        }
        .task { loadProducts() }
        .onChange(of: searchText) { _, _ in filterProducts() }
    }

    private func loadProducts() {
        category = store.categories.first { $0.id == categoryId }
        allCategoryProducts = store.products.filter {
            $0.primaryCategoryId == categoryId && $0.status != "archived"
        }
        filterProducts()
    }

    private func filterProducts() {
        if searchText.isEmpty {
            displayedProducts = allCategoryProducts
        } else {
            displayedProducts = allCategoryProducts.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                (product.sku?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(Capsule())
    }
}
