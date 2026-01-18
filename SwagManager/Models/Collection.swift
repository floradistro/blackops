import Foundation

struct CreationCollection: Codable, Identifiable, Hashable {
    let id: UUID
    var storeId: UUID
    var locationId: UUID?
    var name: String
    var slug: String
    var description: String?
    var launcherStyle: String?
    var backgroundColor: String?
    var accentColor: String?
    var logoUrl: String?
    var isPublic: Bool?
    var requiresAuth: Bool?
    var createdAt: Date?
    var updatedAt: Date?
    var visibility: String?
    var isPinned: Bool?
    var pinnedAt: Date?
    var pinOrder: Int?
    var isTemplate: Bool?
    var designSystem: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case locationId = "location_id"
        case name, slug, description
        case launcherStyle = "launcher_style"
        case backgroundColor = "background_color"
        case accentColor = "accent_color"
        case logoUrl = "logo_url"
        case isPublic = "is_public"
        case requiresAuth = "requires_auth"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case visibility
        case isPinned = "is_pinned"
        case pinnedAt = "pinned_at"
        case pinOrder = "pin_order"
        case isTemplate = "is_template"
        case designSystem = "design_system"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CreationCollection, rhs: CreationCollection) -> Bool {
        lhs.id == rhs.id
    }
}

struct CollectionInsert: Codable {
    var storeId: UUID
    var name: String
    var slug: String
    var description: String?
    var launcherStyle: String?
    var backgroundColor: String?
    var isPublic: Bool?

    enum CodingKeys: String, CodingKey {
        case storeId = "store_id"
        case name, slug, description
        case launcherStyle = "launcher_style"
        case backgroundColor = "background_color"
        case isPublic = "is_public"
    }
}

struct CollectionUpdate: Codable {
    var name: String?
    var slug: String?
    var description: String?
    var launcherStyle: String?
    var backgroundColor: String?
    var accentColor: String?
    var logoUrl: String?
    var isPublic: Bool?
    var visibility: String?

    enum CodingKeys: String, CodingKey {
        case name, slug, description
        case launcherStyle = "launcher_style"
        case backgroundColor = "background_color"
        case accentColor = "accent_color"
        case logoUrl = "logo_url"
        case isPublic = "is_public"
        case visibility
    }
}

struct CreationCollectionItem: Codable, Identifiable {
    let id: UUID
    var collectionId: UUID
    var creationId: UUID
    var position: Int?
    var label: String?
    var addedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case collectionId = "collection_id"
        case creationId = "creation_id"
        case position, label
        case addedAt = "added_at"
    }
}

struct CollectionItemInsert: Codable {
    var collectionId: UUID
    var creationId: UUID
    var position: Int?
    var label: String?

    enum CodingKeys: String, CodingKey {
        case collectionId = "collection_id"
        case creationId = "creation_id"
        case position, label
    }
}

struct CollectionWithItems: Identifiable {
    let collection: CreationCollection
    var items: [CreationCollectionItem]
    var creations: [Creation]

    var id: UUID { collection.id }
}
