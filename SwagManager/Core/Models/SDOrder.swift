import Foundation
import SwiftData

// MARK: - SwiftData Order Model
// Single source of truth - synced from Supabase

@Model
final class SDOrder {
    @Attribute(.unique) var id: UUID
    var orderNumber: String
    var status: String
    var paymentStatus: String?
    var channel: String
    var subtotal: Decimal
    var totalAmount: Decimal
    var currency: String
    var customerNote: String?
    var shippingName: String?
    var shippingCity: String?
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    @Relationship var location: SDLocation?
    @Relationship var customer: SDCustomer?

    // MARK: - Computed Properties (not stored)

    var isActive: Bool {
        ["pending", "confirmed", "preparing", "packing", "packed", "ready", "ready_to_ship"].contains(status)
    }

    var isPending: Bool { status == "pending" }
    var isProcessing: Bool { ["confirmed", "preparing", "packing", "packed"].contains(status) }
    var isReady: Bool { ["ready", "ready_to_ship"].contains(status) }
    var isCompleted: Bool { ["delivered", "completed"].contains(status) }

    var displayTitle: String {
        if let name = shippingName, !name.isEmpty, name != "Walk-In" {
            return name
        }
        return "#\(orderNumber)"
    }

    var displayTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: totalAmount as NSDecimalNumber) ?? "$0.00"
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        orderNumber: String,
        status: String = "pending",
        paymentStatus: String? = nil,
        channel: String = "online",
        subtotal: Decimal = 0,
        totalAmount: Decimal = 0,
        currency: String = "USD",
        customerNote: String? = nil,
        shippingName: String? = nil,
        shippingCity: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.status = status
        self.paymentStatus = paymentStatus
        self.channel = channel
        self.subtotal = subtotal
        self.totalAmount = totalAmount
        self.currency = currency
        self.customerNote = customerNote
        self.shippingName = shippingName
        self.shippingCity = shippingCity
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Predicates for @Query

extension SDOrder {
    static var activePredicate: Predicate<SDOrder> {
        #Predicate<SDOrder> { order in
            order.status == "pending" ||
            order.status == "confirmed" ||
            order.status == "preparing" ||
            order.status == "packing" ||
            order.status == "packed" ||
            order.status == "ready" ||
            order.status == "ready_to_ship"
        }
    }

    static var pendingPredicate: Predicate<SDOrder> {
        #Predicate<SDOrder> { $0.status == "pending" }
    }

    static var completedPredicate: Predicate<SDOrder> {
        #Predicate<SDOrder> { order in
            order.status == "delivered" || order.status == "completed"
        }
    }
}
