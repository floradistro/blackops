import Foundation
import SwiftUI

// MARK: - Store

struct Store: Codable, Identifiable, Hashable {
    let id: UUID
    var storeName: String
    var slug: String
    var email: String
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

// MARK: - Category

struct Category: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var slug: String
    var description: String?
    var parentId: UUID?
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
        case "outofstock": return .red
        case "onbackorder": return .orange
        default: return .gray
        }
    }

    var stockStatusLabel: String {
        switch stockStatus {
        case "instock": return "In Stock"
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
