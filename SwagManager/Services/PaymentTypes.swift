//
//  PaymentTypes.swift
//  SwagManager (macOS)
//
//  Payment-related types copied from iOS POS
//  All payment logic runs in backend - these are for UI state only
//

import Foundation

// MARK: - Session Info

struct SessionInfo: Sendable {
    let storeId: UUID
    let locationId: UUID
    let registerId: UUID?
    let userId: UUID?
}

// MARK: - Payment Method

enum PaymentMethod: String, Codable, CaseIterable {
    case cash = "cash"
    case card = "card"
    case split = "split"
    case invoice = "invoice"

    var label: String {
        switch self {
        case .cash: return "Cash"
        case .card: return "Card"
        case .split: return "Split"
        case .invoice: return "Invoice"
        }
    }

    var icon: String {
        switch self {
        case .cash: return "dollarsign.circle"
        case .card: return "creditcard"
        case .split: return "arrow.left.arrow.right"
        case .invoice: return "paperplane"
        }
    }
}

// MARK: - Sale Completion

struct SaleCompletion: Codable {
    let orderId: UUID
    let orderNumber: String
    let transactionNumber: String
    let total: Decimal
    let paymentMethod: PaymentMethod
    let completedAt: Date
    var paymentUrl: String?
    var invoiceNumber: String?
}

// MARK: - Payment Error

enum PaymentError: LocalizedError {
    case insufficientCash
    case invalidAmount
    case terminalError(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .insufficientCash:
            return "Insufficient cash tendered"
        case .invalidAmount:
            return "Invalid amount"
        case .terminalError(let message):
            return "Terminal error: \(message)"
        case .serverError(let message):
            return message
        }
    }
}
