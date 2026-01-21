import Foundation
import SwiftUI

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
    var pricingSchema: PricingSchema?  // Embedded pricing schema with tiers (from PostgREST join)
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
        case pricingSchema = "pricing_schema"
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
        pricingSchema = try? container.decodeIfPresent(PricingSchema.self, forKey: .pricingSchema)
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
        try container.encodeIfPresent(pricingSchema, forKey: .pricingSchema)
        try container.encodeIfPresent(pricingData, forKey: .pricingData)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Product Update

