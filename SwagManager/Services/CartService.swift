import Foundation

// MARK: - Cart Service
// Ported from POS - thin wrapper around /cart Edge Function
// All calculations done server-side, client just renders state

// MARK: - Models

struct ServerCart: Codable, Identifiable, Equatable {
    let id: UUID
    let storeId: UUID
    let locationId: UUID
    let customerId: UUID?
    let status: String
    let items: [ServerCartItem]
    let totals: CheckoutTotals
    let createdAt: Date?
    let updatedAt: Date?

    var isEmpty: Bool { items.isEmpty }
    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
}

struct ServerCartItem: Codable, Identifiable, Equatable {
    let id: UUID
    let cartId: UUID
    let productId: UUID
    let productName: String
    let sku: String?
    let unitPrice: Decimal
    let quantity: Int
    let tierLabel: String?
    let tierQuantity: Double?
    let variantId: UUID?
    let variantName: String?
    let lineTotal: Decimal
    let discountAmount: Decimal?
    let manualDiscountType: String?
    let manualDiscountValue: Decimal?
    let inventoryId: UUID?
}

struct CheckoutTotals: Codable, Equatable {
    let subtotal: Decimal
    let discountAmount: Decimal
    let taxableAmount: Decimal
    let taxRate: Decimal
    let taxAmount: Decimal
    let taxBreakdown: [TaxBreakdownItem]?
    let total: Decimal
    let itemCount: Int
    let cashSuggestions: [Decimal]?
    let errors: [String]
    let isValid: Bool
}

struct TaxBreakdownItem: Codable, Equatable {
    let jurisdiction: String
    let rate: Decimal
    let taxableAmount: Decimal
    let taxAmount: Decimal
}

// MARK: - Cart Service

class CartService {
    private let supabase: SupabaseService

    init(supabase: SupabaseService = .shared) {
        self.supabase = supabase
    }

    // MARK: - Cart Operations

    /// Get or create cart for customer at location
    /// fresh_start=true clears existing items (prevents old items from reappearing)
    func getOrCreateCart(
        storeId: UUID,
        locationId: UUID,
        customerId: UUID?,
        freshStart: Bool = true
    ) async throws -> ServerCart {
        let payload: [String: Any] = [
            "action": "get",
            "store_id": storeId.uuidString,
            "location_id": locationId.uuidString,
            "customer_id": customerId?.uuidString as Any,
            "fresh_start": freshStart
        ]

        return try await callCartFunction(payload: payload)
    }

    /// Add product to cart
    func addToCart(
        cartId: UUID,
        productId: UUID,
        quantity: Int = 1,
        unitPrice: Decimal? = nil,
        tierLabel: String? = nil,
        tierQuantity: Double? = nil,
        variantId: UUID? = nil,
        inventoryId: UUID? = nil
    ) async throws -> ServerCart {
        var payload: [String: Any] = [
            "action": "add",
            "cart_id": cartId.uuidString,
            "product_id": productId.uuidString,
            "quantity": quantity
        ]

        if let unitPrice = unitPrice {
            payload["unit_price"] = NSDecimalNumber(decimal: unitPrice).doubleValue
        }
        if let tierLabel = tierLabel {
            payload["tier_label"] = tierLabel
        }
        if let tierQuantity = tierQuantity {
            payload["tier_quantity"] = tierQuantity
        }
        if let variantId = variantId {
            payload["variant_id"] = variantId.uuidString
        }
        if let inventoryId = inventoryId {
            payload["inventory_id"] = inventoryId.uuidString
        }

        return try await callCartFunction(payload: payload)
    }

    /// Update item quantity
    func updateItemQuantity(
        cartId: UUID,
        itemId: UUID,
        quantity: Int
    ) async throws -> ServerCart {
        let payload: [String: Any] = [
            "action": "update",
            "cart_id": cartId.uuidString,
            "item_id": itemId.uuidString,
            "quantity": quantity
        ]

        return try await callCartFunction(payload: payload)
    }

    /// Remove item from cart
    func removeFromCart(
        cartId: UUID,
        itemId: UUID
    ) async throws -> ServerCart {
        let payload: [String: Any] = [
            "action": "remove",
            "cart_id": cartId.uuidString,
            "item_id": itemId.uuidString
        ]

        return try await callCartFunction(payload: payload)
    }

    /// Clear all items from cart
    func clearCart(cartId: UUID) async throws -> ServerCart {
        let payload: [String: Any] = [
            "action": "clear",
            "cart_id": cartId.uuidString
        ]

        return try await callCartFunction(payload: payload)
    }

    /// Apply discount to specific item
    func applyItemDiscount(
        cartId: UUID,
        itemId: UUID,
        type: String, // "percentage" or "fixed"
        value: Decimal
    ) async throws -> ServerCart {
        let payload: [String: Any] = [
            "action": "apply_discount",
            "cart_id": cartId.uuidString,
            "item_id": itemId.uuidString,
            "discount_type": type,
            "discount_value": NSDecimalNumber(decimal: value).doubleValue
        ]

        return try await callCartFunction(payload: payload)
    }

    /// Apply discount to entire cart
    func applyCartDiscount(
        cartId: UUID,
        type: String? = nil, // "percentage" or "fixed"
        value: Decimal? = nil,
        loyaltyPoints: Int? = nil
    ) async throws -> ServerCart {
        var payload: [String: Any] = [
            "action": "apply_discount",
            "cart_id": cartId.uuidString
        ]

        if let type = type {
            payload["discount_type"] = type
        }
        if let value = value {
            payload["discount_value"] = NSDecimalNumber(decimal: value).doubleValue
        }
        if let loyaltyPoints = loyaltyPoints {
            payload["loyalty_points"] = loyaltyPoints
        }

        return try await callCartFunction(payload: payload)
    }

    // MARK: - Private Helpers

    private func callCartFunction(payload: [String: Any]) async throws -> ServerCart {
        let data = try JSONSerialization.data(withJSONObject: payload)

        let response: Data = try await supabase.client.functions.invoke(
            "cart",
            options: .init(
                body: data
            )
        )

        // Parse response
        struct CartResponse: Codable {
            let success: Bool
            let data: ServerCart?
            let error: String?
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let cartResponse = try decoder.decode(CartResponse.self, from: response)

        guard cartResponse.success, let cart = cartResponse.data else {
            throw NSError(
                domain: "CartService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: cartResponse.error ?? "Unknown cart error"]
            )
        }

        return cart
    }
}
