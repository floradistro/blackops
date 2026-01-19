import Foundation
import SwiftUI

// MARK: - Store

struct Store: Codable, Identifiable, Hashable {
    let id: UUID
    var storeName: String
    var slug: String
    var email: String
    var ownerUserId: UUID?
    var status: String?
    var phone: String?
    var address: String?
    var city: String?
    var state: String?
    var zip: String?
    var logoUrl: String?
    var bannerUrl: String?
    var storeDescription: String?
    var storeTagline: String?
    var storeType: String?
    var totalLocations: Int?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, email, status, phone, address, city, state, zip
        case storeName = "store_name"
        case ownerUserId = "owner_user_id"
        case logoUrl = "logo_url"
        case bannerUrl = "banner_url"
        case storeDescription = "store_description"
        case storeTagline = "store_tagline"
        case storeType = "store_type"
        case totalLocations = "total_locations"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Store, rhs: Store) -> Bool {
        lhs.id == rhs.id
    }

    var displayName: String {
        storeName
    }
}

// MARK: - Store Insert

struct StoreInsert: Codable {
    var storeName: String
    var slug: String
    var email: String
    var ownerUserId: UUID?
    var status: String?
    var storeType: String?

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case slug, email
        case ownerUserId = "owner_user_id"
        case status
        case storeType = "store_type"
    }
}

// MARK: - Catalog

struct Catalog: Codable, Identifiable, Hashable {
    let id: UUID
    var storeId: UUID
    var name: String
    var slug: String
    var description: String?
    var vertical: String?
    var isActive: Bool?
    var isDefault: Bool?
    var settings: AnyCodable?
    var displayOrder: Int?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, vertical, settings
        case storeId = "store_id"
        case isActive = "is_active"
        case isDefault = "is_default"
        case displayOrder = "display_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Catalog, rhs: Catalog) -> Bool {
        lhs.id == rhs.id
    }

    var displayName: String {
        name
    }

    var verticalIcon: String {
        switch vertical?.lowercased() {
        case "cannabis": return "leaf"
        case "real_estate": return "building.2"
        case "retail": return "bag"
        case "food": return "fork.knife"
        default: return "folder"
        }
    }
}

// MARK: - Catalog Insert

struct CatalogInsert: Codable {
    var storeId: UUID
    var ownerUserId: UUID
    var name: String
    var slug: String
    var description: String?
    var vertical: String?
    var isActive: Bool?
    var isDefault: Bool?

    enum CodingKeys: String, CodingKey {
        case name, slug, description, vertical
        case storeId = "store_id"
        case ownerUserId = "owner_user_id"
        case isActive = "is_active"
        case isDefault = "is_default"
    }
}

// MARK: - Category

struct Category: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var slug: String
    var description: String?
    var parentId: UUID?
    var catalogId: UUID?
    var imageUrl: String?
    var bannerUrl: String?
    var displayOrder: Int?
    var isActive: Bool?
    var featured: Bool?
    var productCount: Int?
    var storeId: UUID?
    var icon: String?
    var featuredImage: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description
        case parentId = "parent_id"
        case catalogId = "catalog_id"
        case imageUrl = "image_url"
        case bannerUrl = "banner_url"
        case displayOrder = "display_order"
        case isActive = "is_active"
        case featured
        case productCount = "product_count"
        case storeId = "store_id"
        case icon
        case featuredImage = "featured_image"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Category Insert

struct CategoryInsert: Codable {
    var name: String
    var slug: String
    var description: String?
    var parentId: UUID?
    var catalogId: UUID?
    var storeId: UUID?
    var displayOrder: Int?
    var isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case name, slug, description
        case parentId = "parent_id"
        case catalogId = "catalog_id"
        case storeId = "store_id"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }
}

// MARK: - Product

struct Product: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var slug: String
    var description: String?
    var shortDescription: String?
    var sku: String?
    var type: String?
    var status: String?
    var regularPrice: Double?
    var salePrice: Double?
    var onSale: Bool?
    var price: Double?
    var primaryCategoryId: UUID?
    var storeId: UUID?
    var featuredImage: String?
    var imageGallery: [String]?
    var hasVariations: Bool?
    var manageStock: Bool?
    var stockQuantity: Double?
    var stockStatus: String?
    var weight: Double?
    var length: Double?
    var width: Double?
    var height: Double?
    var costPrice: Double?
    var wholesalePrice: Double?
    var isWholesale: Bool?
    var wholesaleOnly: Bool?
    var productVisibility: String?
    var fieldValues: [String: AnyCodable]?
    var pricingSchemaId: UUID?
    var pricingData: [PricingTier]?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description
        case shortDescription = "short_description"
        case sku, type, status
        case regularPrice = "regular_price"
        case salePrice = "sale_price"
        case onSale = "on_sale"
        case price
        case primaryCategoryId = "primary_category_id"
        case storeId = "store_id"
        case featuredImage = "featured_image"
        case imageGallery = "image_gallery"
        case hasVariations = "has_variations"
        case manageStock = "manage_stock"
        case stockQuantity = "stock_quantity"
        case stockStatus = "stock_status"
        case weight, length, width, height
        case costPrice = "cost_price"
        case wholesalePrice = "wholesale_price"
        case isWholesale = "is_wholesale"
        case wholesaleOnly = "wholesale_only"
        case productVisibility = "product_visibility"
        case fieldValues = "field_values"
        case pricingSchemaId = "pricing_schema_id"
        case pricingData = "pricing_data"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Product, rhs: Product) -> Bool {
        lhs.id == rhs.id
    }

    // Computed properties
    var displayPrice: String {
        let p = price ?? regularPrice ?? 0
        return String(format: "$%.2f", p)
    }

    var stockStatusColor: Color {
        switch stockStatus {
        case "instock": return .green
        case "lowstock": return .orange
        case "outofstock": return .red
        case "onbackorder": return .orange
        default: return .gray
        }
    }

    var stockStatusLabel: String {
        switch stockStatus {
        case "instock": return "In Stock"
        case "lowstock": return "Low Stock"
        case "outofstock": return "Out of Stock"
        case "onbackorder": return "Backorder"
        default: return stockStatus ?? "Unknown"
        }
    }
}

// MARK: - Product Update

struct ProductUpdate: Codable {
    var name: String?
    var description: String?
    var shortDescription: String?
    var sku: String?
    var status: String?
    var regularPrice: Double?
    var salePrice: Double?
    var price: Double?
    var primaryCategoryId: UUID?
    var featuredImage: String?
    var stockQuantity: Double?
    var stockStatus: String?

    enum CodingKeys: String, CodingKey {
        case name, description
        case shortDescription = "short_description"
        case sku, status
        case regularPrice = "regular_price"
        case salePrice = "sale_price"
        case price
        case primaryCategoryId = "primary_category_id"
        case featuredImage = "featured_image"
        case stockQuantity = "stock_quantity"
        case stockStatus = "stock_status"
    }
}

// MARK: - Field Schema (custom fields for categories)

struct FieldSchema: Codable, Identifiable, Hashable {
    let id: UUID
    var ownerUserId: UUID?
    var catalogId: UUID?
    var name: String
    var slug: String?
    var description: String?
    var icon: String?
    var fields: [FieldDefinition]
    var applicableCategories: [String]?
    var isPublic: Bool?
    var forkedFromId: UUID?
    var installCount: Int?
    var isActive: Bool?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, icon, fields
        case ownerUserId = "owner_user_id"
        case catalogId = "catalog_id"
        case applicableCategories = "applicable_categories"
        case isPublic = "is_public"
        case forkedFromId = "forked_from_id"
        case installCount = "install_count"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FieldSchema, rhs: FieldSchema) -> Bool {
        lhs.id == rhs.id
    }

    // Check if this field schema applies to a category by name
    func appliesTo(categoryName: String) -> Bool {
        guard let categories = applicableCategories, !categories.isEmpty else {
            return true // Empty means applies to all
        }
        return categories.contains { $0.lowercased() == categoryName.lowercased() }
    }
}

// MARK: - Field Definition

struct FieldDefinition: Codable, Hashable {
    var key: String?
    var name: String?
    var label: String?
    var type: String?
    var required: Bool?
    var options: [String]?
    var defaultValue: AnyCodable?
    var unit: String?

    enum CodingKeys: String, CodingKey {
        case key, name, label, type, required, options, unit
        case defaultValue = "default_value"
    }

    var fieldId: String {
        key ?? name ?? label ?? "field"
    }

    var displayLabel: String {
        label ?? name ?? key ?? "Field"
    }

    var fieldType: String {
        type ?? "text"
    }

    var typeIcon: String {
        switch fieldType {
        case "text": return "textformat"
        case "number": return "number"
        case "select": return "list.bullet"
        case "multiselect": return "checklist"
        case "boolean": return "checkmark.square"
        case "date": return "calendar"
        case "url": return "link"
        default: return "questionmark"
        }
    }
}

// MARK: - Pricing Schema (pricing tiers for products)

struct PricingSchema: Codable, Identifiable, Hashable {
    let id: UUID
    var ownerUserId: UUID?
    var catalogId: UUID?
    var name: String
    var slug: String?
    var description: String?
    var tiers: [PricingTier]
    var qualityTier: String?
    var applicableCategories: [String]?
    var isPublic: Bool?
    var forkedFromId: UUID?
    var installCount: Int?
    var isActive: Bool?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, tiers
        case ownerUserId = "owner_user_id"
        case catalogId = "catalog_id"
        case qualityTier = "quality_tier"
        case applicableCategories = "applicable_categories"
        case isPublic = "is_public"
        case forkedFromId = "forked_from_id"
        case installCount = "install_count"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PricingSchema, rhs: PricingSchema) -> Bool {
        lhs.id == rhs.id
    }

    // Check if this schema applies to a category by name
    func appliesTo(categoryName: String) -> Bool {
        guard let categories = applicableCategories, !categories.isEmpty else {
            return true // Empty means applies to all
        }
        return categories.contains { $0.lowercased() == categoryName.lowercased() }
    }
}

// MARK: - Pricing Tier

struct PricingTier: Codable, Hashable {
    var id: String?
    var unit: String?
    var label: String?
    var quantity: Double?
    var sortOrder: Int?
    var defaultPrice: Double?

    enum CodingKeys: String, CodingKey {
        case id, unit, label, quantity
        case sortOrder = "sort_order"
        case defaultPrice = "default_price"
    }

    var tierId: String {
        id ?? label ?? "tier"
    }

    var displayLabel: String {
        label ?? id ?? "Tier"
    }

    var formattedPrice: String {
        guard let price = defaultPrice else { return "-" }
        return String(format: "$%.2f", price)
    }
}
