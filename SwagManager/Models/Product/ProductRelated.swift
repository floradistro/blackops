import Foundation

// MARK: - Product Related Models
// Extracted from Product.swift following Apple engineering standards
// Contains: ProductUpdate, FieldSchema, PricingSchema, etc.
// File size: ~200 lines (under Apple's 300 line "excellent" threshold)

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
    var id: String
    var label: String
    var quantity: Double
    var unit: String
    var defaultPrice: Decimal
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, unit, label, quantity
        case sortOrder = "sort_order"
        case defaultPrice = "default_price"
    }

    // Memberwise init for programmatic creation
    init(id: String, label: String, quantity: Double, unit: String, defaultPrice: Decimal, sortOrder: Int?) {
        self.id = id
        self.label = label
        self.quantity = quantity
        self.unit = unit
        self.defaultPrice = defaultPrice
        self.sortOrder = sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // ID - default to UUID if missing
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString

        // Label - default to empty if missing
        label = (try? container.decode(String.self, forKey: .label)) ?? ""

        // Quantity can be Double, Int, or String
        if let double = try? container.decode(Double.self, forKey: .quantity) {
            quantity = double
        } else if let int = try? container.decode(Int.self, forKey: .quantity) {
            quantity = Double(int)
        } else if let str = try? container.decode(String.self, forKey: .quantity), let double = Double(str) {
            quantity = double
        } else {
            quantity = 0
        }

        // Unit - default to empty if missing
        unit = (try? container.decode(String.self, forKey: .unit)) ?? ""

        // Price can be Decimal, Double, Int, or String
        if let decimal = try? container.decode(Decimal.self, forKey: .defaultPrice) {
            defaultPrice = decimal
        } else if let double = try? container.decode(Double.self, forKey: .defaultPrice) {
            defaultPrice = Decimal(double)
        } else if let int = try? container.decode(Int.self, forKey: .defaultPrice) {
            defaultPrice = Decimal(int)
        } else if let str = try? container.decode(String.self, forKey: .defaultPrice), let decimal = Decimal(string: str) {
            defaultPrice = decimal
        } else {
            NSLog("[PricingTier] ⚠️ No valid price found for tier '\(label)', defaulting to 0")
            defaultPrice = 0
        }

        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unit, forKey: .unit)
        try container.encode(defaultPrice, forKey: .defaultPrice)
        try container.encodeIfPresent(sortOrder, forKey: .sortOrder)
    }

    var tierId: String {
        id
    }

    var displayLabel: String {
        label
    }

    var formattedPrice: String {
        String(format: "$%.2f", NSDecimalNumber(decimal: defaultPrice).doubleValue)
    }
}
