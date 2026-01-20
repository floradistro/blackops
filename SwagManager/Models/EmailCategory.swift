import Foundation
import SwiftUI

// MARK: - Email Category
// Type-safe email categorization system
// Following Apple engineering standards

/// Granular email categorization for filtering, analytics, and UI organization
enum EmailCategory: String, CaseIterable, Codable {
    // MARK: - Authentication
    case authPasswordReset = "auth_password_reset"
    case authVerifyEmail = "auth_verify_email"
    case authWelcome = "auth_welcome"
    case auth2FACode = "auth_2fa_code"
    case authSecurityAlert = "auth_security_alert"

    // MARK: - Order Lifecycle
    case orderConfirmation = "order_confirmation"
    case orderProcessing = "order_processing"
    case orderShipped = "order_shipped"
    case orderOutForDelivery = "order_out_for_delivery"
    case orderDelivered = "order_delivered"
    case orderDelayed = "order_delayed"
    case orderCancelled = "order_cancelled"
    case orderRefundInitiated = "order_refund_initiated"
    case orderRefundCompleted = "order_refund_completed"

    // MARK: - Receipts & Payments
    case receiptOrder = "receipt_order"
    case receiptRefund = "receipt_refund"
    case paymentFailed = "payment_failed"
    case paymentReminder = "payment_reminder"

    // MARK: - Customer Support
    case supportTicketCreated = "support_ticket_created"
    case supportTicketReplied = "support_ticket_replied"
    case supportTicketResolved = "support_ticket_resolved"

    // MARK: - Marketing Campaigns
    case campaignPromotional = "campaign_promotional"
    case campaignNewsletter = "campaign_newsletter"
    case campaignSeasonal = "campaign_seasonal"
    case campaignFlashSale = "campaign_flash_sale"

    // MARK: - Loyalty & Retention
    case loyaltyPointsEarned = "loyalty_points_earned"
    case loyaltyRewardAvailable = "loyalty_reward_available"
    case loyaltyTierUpgraded = "loyalty_tier_upgraded"
    case retentionWinback = "retention_winback"
    case retentionAbandonedCart = "retention_abandoned_cart"

    // MARK: - System
    case systemNotification = "system_notification"
    case systemMaintenance = "system_maintenance"
    case adminAlert = "admin_alert"
}

// MARK: - Category Groups

extension EmailCategory {
    /// High-level grouping for UI organization
    enum Group: String, CaseIterable {
        case authentication
        case orders
        case receiptsPayments
        case support
        case campaigns
        case loyalty
        case system

        var displayName: String {
            switch self {
            case .authentication: return "Authentication"
            case .orders: return "Orders"
            case .receiptsPayments: return "Receipts & Payments"
            case .support: return "Customer Support"
            case .campaigns: return "Marketing Campaigns"
            case .loyalty: return "Loyalty & Retention"
            case .system: return "System"
            }
        }

        var icon: String {
            switch self {
            case .authentication: return "key.fill"
            case .orders: return "shippingbox.fill"
            case .receiptsPayments: return "dollarsign.circle.fill"
            case .support: return "questionmark.bubble.fill"
            case .campaigns: return "megaphone.fill"
            case .loyalty: return "star.fill"
            case .system: return "gear"
            }
        }

        var color: Color {
            switch self {
            case .authentication: return .blue
            case .orders: return .orange
            case .receiptsPayments: return .green
            case .support: return .cyan
            case .campaigns: return .purple
            case .loyalty: return .yellow
            case .system: return .gray
            }
        }

        var categories: [EmailCategory] {
            switch self {
            case .authentication:
                return [.authPasswordReset, .authVerifyEmail, .authWelcome, .auth2FACode, .authSecurityAlert]
            case .orders:
                return [.orderConfirmation, .orderProcessing, .orderShipped, .orderOutForDelivery,
                       .orderDelivered, .orderDelayed, .orderCancelled, .orderRefundInitiated, .orderRefundCompleted]
            case .receiptsPayments:
                return [.receiptOrder, .receiptRefund, .paymentFailed, .paymentReminder]
            case .support:
                return [.supportTicketCreated, .supportTicketReplied, .supportTicketResolved]
            case .campaigns:
                return [.campaignPromotional, .campaignNewsletter, .campaignSeasonal, .campaignFlashSale]
            case .loyalty:
                return [.loyaltyPointsEarned, .loyaltyRewardAvailable, .loyaltyTierUpgraded,
                       .retentionWinback, .retentionAbandonedCart]
            case .system:
                return [.systemNotification, .systemMaintenance, .adminAlert]
            }
        }
    }

    /// The group this category belongs to
    var group: Group {
        switch self {
        case .authPasswordReset, .authVerifyEmail, .authWelcome, .auth2FACode, .authSecurityAlert:
            return .authentication
        case .orderConfirmation, .orderProcessing, .orderShipped, .orderOutForDelivery,
             .orderDelivered, .orderDelayed, .orderCancelled, .orderRefundInitiated, .orderRefundCompleted:
            return .orders
        case .receiptOrder, .receiptRefund, .paymentFailed, .paymentReminder:
            return .receiptsPayments
        case .supportTicketCreated, .supportTicketReplied, .supportTicketResolved:
            return .support
        case .campaignPromotional, .campaignNewsletter, .campaignSeasonal, .campaignFlashSale:
            return .campaigns
        case .loyaltyPointsEarned, .loyaltyRewardAvailable, .loyaltyTierUpgraded,
             .retentionWinback, .retentionAbandonedCart:
            return .loyalty
        case .systemNotification, .systemMaintenance, .adminAlert:
            return .system
        }
    }
}

// MARK: - Display Properties

extension EmailCategory {
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .authPasswordReset: return "Password Reset"
        case .authVerifyEmail: return "Email Verification"
        case .authWelcome: return "Welcome Email"
        case .auth2FACode: return "2FA Code"
        case .authSecurityAlert: return "Security Alert"
        case .orderConfirmation: return "Order Confirmation"
        case .orderProcessing: return "Order Processing"
        case .orderShipped: return "Order Shipped"
        case .orderOutForDelivery: return "Out for Delivery"
        case .orderDelivered: return "Order Delivered"
        case .orderDelayed: return "Order Delayed"
        case .orderCancelled: return "Order Cancelled"
        case .orderRefundInitiated: return "Refund Initiated"
        case .orderRefundCompleted: return "Refund Completed"
        case .receiptOrder: return "Order Receipt"
        case .receiptRefund: return "Refund Receipt"
        case .paymentFailed: return "Payment Failed"
        case .paymentReminder: return "Payment Reminder"
        case .supportTicketCreated: return "Ticket Created"
        case .supportTicketReplied: return "Ticket Reply"
        case .supportTicketResolved: return "Ticket Resolved"
        case .campaignPromotional: return "Promotional Campaign"
        case .campaignNewsletter: return "Newsletter"
        case .campaignSeasonal: return "Seasonal Campaign"
        case .campaignFlashSale: return "Flash Sale"
        case .loyaltyPointsEarned: return "Points Earned"
        case .loyaltyRewardAvailable: return "Reward Available"
        case .loyaltyTierUpgraded: return "Tier Upgraded"
        case .retentionWinback: return "Win-back Campaign"
        case .retentionAbandonedCart: return "Abandoned Cart"
        case .systemNotification: return "System Notification"
        case .systemMaintenance: return "Maintenance Notice"
        case .adminAlert: return "Admin Alert"
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .authPasswordReset: return "key.fill"
        case .authVerifyEmail: return "checkmark.shield.fill"
        case .authWelcome: return "hand.wave.fill"
        case .auth2FACode: return "number.square.fill"
        case .authSecurityAlert: return "exclamationmark.shield.fill"
        case .orderConfirmation: return "checkmark.circle.fill"
        case .orderProcessing: return "arrow.clockwise.circle.fill"
        case .orderShipped: return "shippingbox.fill"
        case .orderOutForDelivery: return "location.fill"
        case .orderDelivered: return "checkmark.circle.fill"
        case .orderDelayed: return "clock.fill"
        case .orderCancelled: return "xmark.circle.fill"
        case .orderRefundInitiated: return "arrow.uturn.backward.circle.fill"
        case .orderRefundCompleted: return "dollarsign.circle.fill"
        case .receiptOrder: return "receipt.fill"
        case .receiptRefund: return "receipt.fill"
        case .paymentFailed: return "creditcard.trianglebadge.exclamationmark"
        case .paymentReminder: return "bell.fill"
        case .supportTicketCreated: return "ticket.fill"
        case .supportTicketReplied: return "bubble.left.and.bubble.right.fill"
        case .supportTicketResolved: return "checkmark.bubble.fill"
        case .campaignPromotional: return "megaphone.fill"
        case .campaignNewsletter: return "newspaper.fill"
        case .campaignSeasonal: return "sparkles"
        case .campaignFlashSale: return "bolt.fill"
        case .loyaltyPointsEarned: return "star.circle.fill"
        case .loyaltyRewardAvailable: return "gift.fill"
        case .loyaltyTierUpgraded: return "arrow.up.circle.fill"
        case .retentionWinback: return "arrow.uturn.backward.circle.fill"
        case .retentionAbandonedCart: return "cart.badge.questionmark"
        case .systemNotification: return "bell.badge.fill"
        case .systemMaintenance: return "wrench.and.screwdriver.fill"
        case .adminAlert: return "exclamationmark.triangle.fill"
        }
    }

    /// Semantic color for the category
    var color: Color {
        group.color
    }
}

// MARK: - Filtering Helpers

extension Collection where Element == ResendEmail {
    /// Filter emails by category
    func filter(category: EmailCategory) -> [ResendEmail] {
        filter { $0.categoryEnum == category }
    }

    /// Filter emails by category group
    func filter(group: EmailCategory.Group) -> [ResendEmail] {
        filter { $0.categoryEnum?.group == group }
    }

    /// Group emails by category
    func grouped() -> [EmailCategory.Group: [ResendEmail]] {
        Dictionary(grouping: self) { $0.categoryEnum?.group ?? .system }
    }
}
