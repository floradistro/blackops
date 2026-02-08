import Foundation

// MARK: - Store

struct Store: Codable, Identifiable, Hashable {
    let id: UUID
    var storeName: String
    var slug: String
    var email: String
    var ownerUserId: UUID?
    var status: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, email, status
        case storeName = "store_name"
        case ownerUserId = "owner_user_id"
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

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case slug, email
        case ownerUserId = "owner_user_id"
        case status
    }
}
