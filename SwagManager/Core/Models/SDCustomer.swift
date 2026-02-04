import Foundation
import SwiftData

// MARK: - SwiftData Customer Model

@Model
final class SDCustomer {
    @Attribute(.unique) var id: UUID
    var storeId: UUID?
    var email: String?
    var phone: String?
    var firstName: String?
    var lastName: String?
    var fullName: String?
    var loyaltyPoints: Int
    var totalSpent: Decimal
    var orderCount: Int
    var createdAt: Date

    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \SDOrder.customer)
    var orders: [SDOrder] = []

    // MARK: - Computed

    var displayName: String {
        if let full = fullName, !full.isEmpty {
            return full
        }
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (phone ?? email ?? "Customer") : parts.joined(separator: " ")
    }

    var initials: String {
        let first = firstName?.prefix(1) ?? ""
        let last = lastName?.prefix(1) ?? ""
        if first.isEmpty && last.isEmpty {
            return "C"
        }
        return "\(first)\(last)".uppercased()
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        storeId: UUID? = nil,
        email: String? = nil,
        phone: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        fullName: String? = nil,
        loyaltyPoints: Int = 0,
        totalSpent: Decimal = 0,
        orderCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.storeId = storeId
        self.email = email
        self.phone = phone
        self.firstName = firstName
        self.lastName = lastName
        self.fullName = fullName
        self.loyaltyPoints = loyaltyPoints
        self.totalSpent = totalSpent
        self.orderCount = orderCount
        self.createdAt = createdAt
    }
}
