import Foundation
import SwiftData

// MARK: - SwiftData Location Model

@Model
final class SDLocation {
    @Attribute(.unique) var id: UUID
    var storeId: UUID
    var name: String
    var address: String?
    var city: String?
    var state: String?
    var zipCode: String?
    var phone: String?
    var isActive: Bool
    var createdAt: Date

    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \SDOrder.location)
    var orders: [SDOrder] = []

    // MARK: - Computed

    var activeOrderCount: Int {
        orders.filter { $0.isActive }.count
    }

    var pendingOrderCount: Int {
        orders.filter { $0.isPending }.count
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        storeId: UUID,
        name: String,
        address: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zipCode: String? = nil,
        phone: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.storeId = storeId
        self.name = name
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.phone = phone
        self.isActive = isActive
        self.createdAt = createdAt
    }
}
