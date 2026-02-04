//
//  PaymentService.swift
//  SwagManager (macOS)
//
//  Payment service that calls /payment-intent Edge Function
//  Copied from iOS POS to ensure orders are tracked properly
//

import Foundation

// MARK: - Payment Service

actor PaymentService {
    static let shared = PaymentService()

    private init() {}

    // MARK: - Process Payment

    func processCashPayment(
        sessionInfo: SessionInfo,
        cart: ServerCart,
        cashTendered: Decimal,
        customerName: String?
    ) async throws -> SaleCompletion {
        let change = cashTendered - cart.totals.total
        guard change >= 0 else {
            throw PaymentError.insufficientCash
        }

        let payload = CreateIntentPayload(
            storeId: sessionInfo.storeId.uuidString,
            locationId: sessionInfo.locationId.uuidString,
            registerId: sessionInfo.registerId?.uuidString ?? UUID().uuidString,
            sessionId: UUID().uuidString, // Generate session ID
            paymentMethod: "cash",
            amount: NSDecimalNumber(decimal: cart.totals.total).doubleValue,
            cartItems: cart.items.map { item in
                CartItemPayload(
                    productId: item.productId.uuidString,
                    productName: item.productName,
                    productSku: item.sku,
                    quantity: item.quantity,
                    tierQty: item.tierQuantity,
                    tierName: item.tierLabel,
                    unitPrice: NSDecimalNumber(decimal: item.unitPrice).doubleValue,
                    inventoryId: item.inventoryId?.uuidString,
                    tierQuantity: item.tierQuantity
                )
            },
            totals: TotalsPayload(
                subtotal: NSDecimalNumber(decimal: cart.totals.subtotal).doubleValue,
                discountAmount: NSDecimalNumber(decimal: cart.totals.discountAmount).doubleValue,
                taxableAmount: NSDecimalNumber(decimal: cart.totals.taxableAmount).doubleValue,
                taxRate: NSDecimalNumber(decimal: cart.totals.taxRate).doubleValue,
                taxAmount: NSDecimalNumber(decimal: cart.totals.taxAmount).doubleValue,
                total: NSDecimalNumber(decimal: cart.totals.total).doubleValue
            ),
            customerId: cart.customerId?.uuidString.lowercased(),
            customerName: customerName ?? "Guest",
            userId: sessionInfo.userId?.uuidString.lowercased(),
            cashTendered: NSDecimalNumber(decimal: cashTendered).doubleValue,
            changeGiven: NSDecimalNumber(decimal: change).doubleValue,
            idempotencyKey: UUID().uuidString
        )

        return try await createPaymentIntent(payload)
    }

    func processInvoicePayment(
        sessionInfo: SessionInfo,
        cart: ServerCart,
        customerEmail: String,
        customerName: String?,
        dueDate: Date
    ) async throws -> SaleCompletion {
        // Invoice processing via backend
        // For now, return a placeholder - need to implement /invoice edge function call
        throw PaymentError.serverError("Invoice processing not yet implemented")
    }

    // MARK: - Private Helpers

    private func createPaymentIntent(_ payload: CreateIntentPayload) async throws -> SaleCompletion {
        let url = SupabaseConfig.url.appendingPathComponent("functions/v1/payment-intent")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let encoder = JSONEncoder()
        // Don't convert to snake_case - Edge Function expects camelCase
        request.httpBody = try encoder.encode(payload)


        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaymentError.serverError("Invalid response")
        }

        let responseString = String(data: data, encoding: .utf8) ?? "nil"

        guard httpResponse.statusCode == 200 else {
            throw PaymentError.serverError("HTTP \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let intentResponse = try decoder.decode(CreateIntentResponse.self, from: data)

        // Poll for completion (backend processes async)
        return try await pollForCompletion(intentId: intentResponse.intentId)
    }

    private func pollForCompletion(intentId: String, maxAttempts: Int = 30) async throws -> SaleCompletion {
        for attempt in 1...maxAttempts {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            // Check intent status
            let intent = try await fetchIntent(intentId)


            switch intent.status {
            case "completed":
                guard let orderId = intent.orderId,
                      let orderNumber = intent.orderNumber else {
                    throw PaymentError.serverError("Intent completed but missing order info")
                }

                return SaleCompletion(
                    orderId: UUID(uuidString: orderId) ?? UUID(),
                    orderNumber: orderNumber,
                    transactionNumber: orderNumber,
                    total: Decimal(intent.amount),
                    paymentMethod: PaymentMethod(rawValue: intent.paymentMethod) ?? .cash,
                    completedAt: Date()
                )

            case "failed":
                throw PaymentError.serverError(intent.error ?? "Payment failed")

            default:
                continue // Still processing
            }
        }

        throw PaymentError.serverError("Payment timeout")
    }

    private func fetchIntent(_ intentId: String) async throws -> PaymentIntent {
        let url = SupabaseConfig.url
            .appendingPathComponent("rest/v1/payment_intents")
            .appending(queryItems: [
                URLQueryItem(name: "id", value: "eq.\(intentId)"),
                URLQueryItem(name: "select", value: "*")
            ])

        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let intents = try decoder.decode([PaymentIntent].self, from: data)
        guard let intent = intents.first else {
            throw PaymentError.serverError("Intent not found")
        }

        return intent
    }
}

// MARK: - Payload Types

private struct CreateIntentPayload: Encodable {
    let storeId: String
    let locationId: String
    let registerId: String
    let sessionId: String
    let paymentMethod: String
    let amount: Double
    let cartItems: [CartItemPayload]
    let totals: TotalsPayload
    let customerId: String?
    let customerName: String
    let userId: String?
    let cashTendered: Double?
    let changeGiven: Double?
    let idempotencyKey: String
}

private struct CartItemPayload: Encodable {
    let productId: String
    let productName: String
    let productSku: String?
    let quantity: Int
    let tierQty: Double
    let tierName: String?
    let unitPrice: Double
    let inventoryId: String?
    let tierQuantity: Double
}

private struct TotalsPayload: Encodable {
    let subtotal: Double
    let discountAmount: Double
    let taxableAmount: Double
    let taxRate: Double
    let taxAmount: Double
    let total: Double
}

private struct CreateIntentResponse: Decodable {
    let intentId: String
    let status: String
}

private struct PaymentIntent: Decodable {
    let id: String
    let status: String
    let paymentMethod: String
    let amount: Double
    let orderId: String?
    let orderNumber: String?
    let error: String?
}
