import Foundation
import SwiftUI

// MARK: - Resend Email Model
// Represents email data from email_sends table (matches send-email Edge Function schema)

struct ResendEmail: Codable, Identifiable, Hashable {
    let id: UUID
    let storeId: UUID? // Optional to handle emails without store assignment
    let customerId: UUID?
    let orderId: UUID?
    let campaignId: UUID?
    let templateId: UUID?
    let emailType: String // transactional, marketing
    let category: String? // Granular category (auth_password_reset, order_shipped, etc.)
    let toEmail: String
    let toName: String?
    let fromEmail: String
    let fromName: String
    let replyTo: String?
    let subject: String
    let resendEmailId: String?
    let status: String // sent, delivered, opened, clicked, bounced, failed
    let errorMessage: String?
    let sentAt: Date?
    let createdAt: Date?
    let deliveredAt: Date?
    let openedAt: Date?
    let clickedAt: Date?
    let bouncedAt: Date?
    let complainedAt: Date?
    let metadata: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case customerId = "customer_id"
        case orderId = "order_id"
        case campaignId = "campaign_id"
        case templateId = "template_id"
        case emailType = "email_type"
        case category
        case toEmail = "to_email"
        case toName = "to_name"
        case fromEmail = "from_email"
        case fromName = "from_name"
        case replyTo = "reply_to"
        case subject
        case resendEmailId = "resend_email_id"
        case status
        case errorMessage = "error_message"
        case sentAt = "sent_at"
        case createdAt = "created_at"
        case deliveredAt = "delivered_at"
        case openedAt = "opened_at"
        case clickedAt = "clicked_at"
        case bouncedAt = "bounced_at"
        case complainedAt = "complained_at"
        case metadata
    }

    // MARK: - Computed Properties

    var statusColor: Color {
        switch status.lowercased() {
        case "sent": return .blue
        case "delivered": return .green
        case "opened": return .cyan
        case "clicked": return .purple
        case "bounced": return .yellow
        case "failed": return .red
        default: return .gray
        }
    }

    var statusLabel: String {
        status.capitalized
    }

    var displayTo: String {
        if let name = toName {
            return "\(name) <\(toEmail)>"
        }
        return toEmail
    }

    var displaySubject: String {
        subject.isEmpty ? "(No Subject)" : subject
    }

    var hasError: Bool {
        errorMessage != nil
    }

    var displayDate: String {
        let date = sentAt ?? createdAt
        guard let date = date else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Category Properties

    /// Parsed email category enum (converts String to EmailCategory)
    var categoryEnum: EmailCategory? {
        guard let category = category else { return nil }
        return EmailCategory(rawValue: category)
    }

    /// Display name for the category (e.g., "Password Reset", "Order Shipped")
    var categoryDisplayName: String {
        categoryEnum?.displayName ?? "Uncategorized"
    }

    /// SF Symbol icon for the category
    var categoryIcon: String {
        categoryEnum?.icon ?? "envelope.fill"
    }

    /// Semantic color for the category
    var categoryColor: Color {
        categoryEnum?.color ?? .gray
    }

    /// The group this email belongs to (Authentication, Orders, Marketing, etc.)
    var categoryGroup: EmailCategory.Group? {
        categoryEnum?.group
    }

    /// Whether this is an authentication-related email
    var isAuthEmail: Bool {
        categoryGroup == .authentication
    }

    /// Whether this is an order-related email
    var isOrderEmail: Bool {
        categoryGroup == .orders
    }

    /// Whether this is a marketing email
    var isMarketingEmail: Bool {
        categoryGroup == .campaigns
    }

    /// Whether this is a loyalty/retention email
    var isLoyaltyEmail: Bool {
        categoryGroup == .loyalty
    }
}

// MARK: - Email Event
// For tracking email events timeline

struct EmailEvent: Codable, Identifiable {
    let id: UUID
    let emailId: UUID
    let event: String // sent, delivered, opened, clicked, bounced, failed
    let timestamp: Date?
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case emailId = "email_id"
        case event
        case timestamp
        case metadata
    }

    var eventColor: Color {
        switch event.lowercased() {
        case "sent": return .blue
        case "delivered": return .green
        case "opened": return .cyan
        case "clicked": return .purple
        case "bounced": return .yellow
        case "failed": return .red
        default: return .gray
        }
    }

    var eventLabel: String {
        event.capitalized
    }
}

// MARK: - Email Status Enum

enum EmailStatus: String, CaseIterable {
    case queued = "queued"
    case sent = "sent"
    case delivered = "delivered"
    case opened = "opened"
    case clicked = "clicked"
    case bounced = "bounced"
    case failed = "failed"

    var label: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .queued: return .orange
        case .sent: return .blue
        case .delivered: return .green
        case .opened: return .cyan
        case .clicked: return .purple
        case .bounced: return .yellow
        case .failed: return .red
        }
    }
}
