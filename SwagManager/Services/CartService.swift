import Foundation

// MARK: - Cart Service
// Ported from POS - thin wrapper around /cart Edge Function
// All calculations done server-side, client just renders state

// MARK: - Models (copied from iOS app for backend compatibility)

struct ServerCart: Codable, Identifiable {
    let id: UUID
    let storeId: UUID
    let locationId: UUID
    let customerId: UUID?
    let status: String
    let items: [ServerCartItem]
    let totals: CheckoutTotals

    // Computed from totals - these don't exist at root in the database response
    var subtotal: Decimal { totals.subtotal }
    var discountAmount: Decimal { totals.discountAmount }
    var taxRate: Decimal { totals.taxRate }
    var taxAmount: Decimal { totals.taxAmount }
    var total: Decimal { totals.total }
    var itemCount: Int { totals.itemCount }

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case locationId = "location_id"
        case customerId = "customer_id"
        case status
        case items
        case totals
    }
}

struct ServerCartItem: Codable, Identifiable {
    let id: UUID
    let productId: UUID
    let productName: String
    let sku: String?
    let unitPrice: Decimal
    let quantity: Int
    let tierLabel: String?
    let tierQuantity: Double
    let variantId: UUID?
    let variantName: String?
    let lineTotal: Decimal
    let discountAmount: Decimal
    let manualDiscountType: String?
    let manualDiscountValue: Decimal?

    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case productName = "product_name"
        case sku
        case unitPrice = "unit_price"
        case quantity
        case tierLabel = "tier_label"
        case tierQuantity = "tier_quantity"
        case variantId = "variant_id"
        case variantName = "variant_name"
        case lineTotal = "line_total"
        case discountAmount = "discount_amount"
        case manualDiscountType = "manual_discount_type"
        case manualDiscountValue = "manual_discount_value"
    }

    var displayName: String {
        if let variantName = variantName {
            return "\(productName) (\(variantName))"
        }
        return productName
    }

    var hasDiscount: Bool {
        manualDiscountType != nil && (manualDiscountValue ?? 0) > 0
    }
}

struct TaxBreakdownItem: Codable {
    let name: String?
    let rate: Decimal?
    let amount: Decimal?

    // Handle different key formats from database
    enum CodingKeys: String, CodingKey {
        case name
        case rate
        case amount
        case taxName = "tax_name"
        case taxRate = "tax_rate"
        case taxAmount = "tax_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try both formats
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .taxName)
        rate = try container.decodeIfPresent(Decimal.self, forKey: .rate)
            ?? container.decodeIfPresent(Decimal.self, forKey: .taxRate)
        amount = try container.decodeIfPresent(Decimal.self, forKey: .amount)
            ?? container.decodeIfPresent(Decimal.self, forKey: .taxAmount)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(rate, forKey: .rate)
        try container.encodeIfPresent(amount, forKey: .amount)
    }
}

struct CheckoutTotals: Codable {
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

    enum CodingKeys: String, CodingKey {
        case subtotal
        case discountAmount = "discount_amount"
        case taxableAmount = "taxable_amount"
        case taxRate = "tax_rate"
        case taxAmount = "tax_amount"
        case taxBreakdown = "tax_breakdown"
        case total
        case itemCount = "item_count"
        case cashSuggestions = "cash_suggestions"
        case errors
        case isValid = "is_valid"
    }
}

// MARK: - Cart Service

@MainActor
class CartService {
    private let supabase: SupabaseService

    init(supabase: SupabaseService) {
        self.supabase = supabase
    }

    convenience init() {
        self.init(supabase: SupabaseService.shared)
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
        // Use direct HTTP call like iOS app to avoid Supabase SDK wrapping issues
        let baseURL = SupabaseConfig.url.appendingPathComponent("functions/v1")
        let url = baseURL.appendingPathComponent("cart")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        NSLog("[CartService] POST cart - request body: \(payload)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "CartService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        let responseString = String(data: data, encoding: .utf8) ?? "nil"
        NSLog("[CartService] RESPONSE status=\(httpResponse.statusCode): \(responseString.prefix(1000))")

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "CartService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }

        // Parse response - iOS pattern
        struct CartResponse: Codable {
            let success: Bool
            let data: ServerCart?
            let error: String?

            // Custom decoder to handle backend returning partial data (just totals) when no cart exists
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                success = try container.decode(Bool.self, forKey: .success)
                error = try container.decodeIfPresent(String.self, forKey: .error)

                // Try to decode data, but check if it has required fields first
                if container.contains(.data) {
                    // Peek at the data to see if it has an 'id' field (indicates a real cart)
                    let dataContainer = try? container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
                    if dataContainer?.contains(.id) == true {
                        data = try container.decode(ServerCart.self, forKey: .data)
                    } else {
                        // Backend returned partial data (just totals) - treat as no cart
                        data = nil
                    }
                } else {
                    data = nil
                }
            }

            enum CodingKeys: String, CodingKey {
                case success, data, error
            }

            enum DataKeys: String, CodingKey {
                case id
            }
        }

        let decoder = JSONDecoder()
        let cartResponse = try decoder.decode(CartResponse.self, from: data)

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
