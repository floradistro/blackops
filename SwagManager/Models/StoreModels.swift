import Foundation
import SwiftUI

// MARK: - Store, Catalog, and Category Models
// Contains: Store, Catalog, Category and their Insert structs

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

