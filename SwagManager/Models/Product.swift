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

struct Product: Identifiable, Hashable {
    let id: UUID
    var name: String
    var slug: String
    var description: String?
    var shortDescription: String?
    var sku: String?
    var type: String?
    var status: String?
    var primaryCategoryId: UUID?
    var storeId: UUID?
    var featuredImage: String?
    var imageGallery: [String]?
    var hasVariations: Bool?
    var manageStock: Bool?
    var stockQuantity: Int?
    var stockStatus: String?
    var weight: Double?
    var length: Double?
    var width: Double?
    var height: Double?
    var costPrice: Decimal?
    var wholesalePrice: Decimal?
    var isWholesale: Bool?
    var wholesaleOnly: Bool?
    var productVisibility: String?
    var customFields: [String: AnyCodable]?  // Maps to custom_fields in database
    var pricingSchemaId: UUID?
    var pricingData: AnyCodable?  // Pricing tiers array (ONLY pricing system)
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description
        case shortDescription = "short_description"
        case sku, type, status
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
        case customFields = "custom_fields"
        case pricingSchemaId = "pricing_schema_id"
        case pricingData = "pricing_data"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Custom decoding helpers for PostgreSQL numeric types
    private static func decodePrice(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Decimal? {
        // Try Decimal first
        if let decimal = try? container.decodeIfPresent(Decimal.self, forKey: key) {
            return decimal
        }
        // Try Double
        if let double = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Decimal(double)
        }
        // Try String
        if let string = try? container.decodeIfPresent(String.self, forKey: key) {
            return Decimal(string: string)
        }
        return nil
    }

    private static func decodeInt(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Int? {
        // Try Int first
        if let int = try? container.decodeIfPresent(Int.self, forKey: key) {
            return int
        }
        // Try Double
        if let double = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Int(double)
        }
        // Try String
        if let string = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(string)
        }
        return nil
    }

    private static func decodeDouble(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Double? {
        // Try Double first
        if let double = try? container.decodeIfPresent(Double.self, forKey: key) {
            return double
        }
        // Try Decimal
        if let decimal = try? container.decodeIfPresent(Decimal.self, forKey: key) {
            return NSDecimalNumber(decimal: decimal).doubleValue
        }
        // Try String
        if let string = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(string)
        }
        return nil
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Product, rhs: Product) -> Bool {
        lhs.id == rhs.id
    }

    // Computed properties
    var displayPrice: String {
        // Get price from first pricing tier
        guard let pricingData = pricingData else {
            return "$0.00"
        }

        // Extract first tier price
        if let tiersArray = pricingData.value as? [[String: Any]],
           let firstTier = tiersArray.first {
            // Try default_price first
            if let price = firstTier["default_price"] as? Double {
                return String(format: "$%.2f", price)
            }
            if let price = firstTier["default_price"] as? Decimal {
                return String(format: "$%.2f", NSDecimalNumber(decimal: price).doubleValue)
            }
            // Try price field
            if let price = firstTier["price"] as? Double {
                return String(format: "$%.2f", price)
            }
            if let price = firstTier["price"] as? Decimal {
                return String(format: "$%.2f", NSDecimalNumber(decimal: price).doubleValue)
            }
        }

        // Handle object format with "tiers" property
        if let pricingObject = pricingData.value as? [String: Any],
           let tiersArray = pricingObject["tiers"] as? [[String: Any]],
           let firstTier = tiersArray.first {
            if let price = firstTier["default_price"] as? Double {
                return String(format: "$%.2f", price)
            }
            if let price = firstTier["default_price"] as? Decimal {
                return String(format: "$%.2f", NSDecimalNumber(decimal: price).doubleValue)
            }
        }

        return "$0.00"
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

// MARK: - Product Codable

extension Product: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        shortDescription = try? container.decodeIfPresent(String.self, forKey: .shortDescription)
        sku = try? container.decodeIfPresent(String.self, forKey: .sku)
        type = try? container.decodeIfPresent(String.self, forKey: .type)
        status = try? container.decodeIfPresent(String.self, forKey: .status)

        primaryCategoryId = try? container.decodeIfPresent(UUID.self, forKey: .primaryCategoryId)
        storeId = try? container.decodeIfPresent(UUID.self, forKey: .storeId)
        featuredImage = try? container.decodeIfPresent(String.self, forKey: .featuredImage)
        imageGallery = try? container.decodeIfPresent([String].self, forKey: .imageGallery)
        hasVariations = try? container.decodeIfPresent(Bool.self, forKey: .hasVariations)
        manageStock = try? container.decodeIfPresent(Bool.self, forKey: .manageStock)

        // Stock quantity - use custom decoder for PostgreSQL numeric
        stockQuantity = Self.decodeInt(from: container, forKey: .stockQuantity)
        stockStatus = try? container.decodeIfPresent(String.self, forKey: .stockStatus)

        // Dimensions - use custom decoder for PostgreSQL numeric
        weight = Self.decodeDouble(from: container, forKey: .weight)
        length = Self.decodeDouble(from: container, forKey: .length)
        width = Self.decodeDouble(from: container, forKey: .width)
        height = Self.decodeDouble(from: container, forKey: .height)

        // Cost/wholesale pricing - use custom decoder for PostgreSQL numeric
        costPrice = Self.decodePrice(from: container, forKey: .costPrice)
        wholesalePrice = Self.decodePrice(from: container, forKey: .wholesalePrice)

        isWholesale = try? container.decodeIfPresent(Bool.self, forKey: .isWholesale)
        wholesaleOnly = try? container.decodeIfPresent(Bool.self, forKey: .wholesaleOnly)
        productVisibility = try? container.decodeIfPresent(String.self, forKey: .productVisibility)

        // JSONB fields
        customFields = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .customFields)
        pricingSchemaId = try? container.decodeIfPresent(UUID.self, forKey: .pricingSchemaId)
        pricingData = try? container.decodeIfPresent(AnyCodable.self, forKey: .pricingData)

        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try? container.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(slug, forKey: .slug)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(shortDescription, forKey: .shortDescription)
        try container.encodeIfPresent(sku, forKey: .sku)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(primaryCategoryId, forKey: .primaryCategoryId)
        try container.encodeIfPresent(storeId, forKey: .storeId)
        try container.encodeIfPresent(featuredImage, forKey: .featuredImage)
        try container.encodeIfPresent(imageGallery, forKey: .imageGallery)
        try container.encodeIfPresent(hasVariations, forKey: .hasVariations)
        try container.encodeIfPresent(manageStock, forKey: .manageStock)
        try container.encodeIfPresent(stockQuantity, forKey: .stockQuantity)
        try container.encodeIfPresent(stockStatus, forKey: .stockStatus)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(length, forKey: .length)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(costPrice, forKey: .costPrice)
        try container.encodeIfPresent(wholesalePrice, forKey: .wholesalePrice)
        try container.encodeIfPresent(isWholesale, forKey: .isWholesale)
        try container.encodeIfPresent(wholesaleOnly, forKey: .wholesaleOnly)
        try container.encodeIfPresent(productVisibility, forKey: .productVisibility)
        try container.encodeIfPresent(customFields, forKey: .customFields)
        try container.encodeIfPresent(pricingSchemaId, forKey: .pricingSchemaId)
        try container.encodeIfPresent(pricingData, forKey: .pricingData)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Product Update

struct ProductUpdate: Codable {
    var name: String?
    var description: String?
    var shortDescription: String?
    var sku: String?
    var status: String?
    var primaryCategoryId: UUID?
    var featuredImage: String?
    var stockQuantity: Int?
    var stockStatus: String?

    enum CodingKeys: String, CodingKey {
        case name, description
        case shortDescription = "short_description"
        case sku, status
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
    var defaultPrice: Decimal?

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
        return String(format: "$%.2f", NSDecimalNumber(decimal: price).doubleValue)
    }
}
