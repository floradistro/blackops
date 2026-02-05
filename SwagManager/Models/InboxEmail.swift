import Foundation
import SwiftUI

// MARK: - Email Thread Model
// Represents a conversation thread grouping related inbound/outbound emails

struct EmailThread: Codable, Identifiable, Hashable {
    let id: UUID
    let storeId: UUID?
    let customerId: UUID?
    let orderId: UUID?
    let subject: String?
    let mailbox: String
    let status: String
    let priority: String
    let intent: String?
    let aiSummary: String?
    let assignedTo: String?
    let messageCount: Int
    let unreadCount: Int
    let lastMessageAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case customerId = "customer_id"
        case orderId = "order_id"
        case subject
        case mailbox
        case status
        case priority
        case intent
        case aiSummary = "ai_summary"
        case assignedTo = "assigned_to"
        case messageCount = "message_count"
        case unreadCount = "unread_count"
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Display Properties

    var displaySubject: String {
        subject ?? "(No Subject)"
    }

    var hasUnread: Bool {
        unreadCount > 0
    }

    var statusColor: Color {
        switch status {
        case "open": return .blue
        case "awaiting_reply": return .orange
        case "resolved": return .green
        case "closed": return .gray
        default: return .secondary
        }
    }

    var statusLabel: String {
        switch status {
        case "open": return "Open"
        case "awaiting_reply": return "Awaiting Reply"
        case "resolved": return "Resolved"
        case "closed": return "Closed"
        default: return status.capitalized
        }
    }

    var priorityColor: Color {
        switch priority {
        case "urgent": return .red
        case "high": return .orange
        case "normal": return .blue
        case "low": return .gray
        default: return .secondary
        }
    }

    var priorityLabel: String {
        priority.capitalized
    }

    var mailboxIcon: String {
        switch mailbox {
        case "support": return "questionmark.bubble"
        case "orders": return "shippingbox"
        case "returns": return "arrow.uturn.left.circle"
        case "info": return "info.circle"
        default: return "envelope"
        }
    }

    var mailboxLabel: String {
        mailbox.capitalized
    }

    var intentLabel: String? {
        guard let intent else { return nil }
        return intent.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var displayDate: String {
        guard let date = lastMessageAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Inbox Email Model
// Represents an individual inbound or outbound message within a thread

struct InboxEmail: Codable, Identifiable, Hashable {
    let id: UUID
    let storeId: UUID?
    let threadId: UUID?
    let resendEmailId: String?
    let direction: String
    let fromEmail: String
    let fromName: String?
    let toEmail: String
    let toName: String?
    let subject: String?
    let bodyHtml: String?
    let bodyText: String?
    let messageId: String?
    let inReplyTo: String?
    let hasAttachments: Bool
    let attachments: [InboxAttachment]?
    let status: String
    let aiDraft: String?
    let aiIntent: String?
    let aiConfidence: Double?
    let customerId: UUID?
    let orderId: UUID?
    let createdAt: Date?
    let readAt: Date?
    let repliedAt: Date?
    let receivedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case threadId = "thread_id"
        case resendEmailId = "resend_email_id"
        case direction
        case fromEmail = "from_email"
        case fromName = "from_name"
        case toEmail = "to_email"
        case toName = "to_name"
        case subject
        case bodyHtml = "body_html"
        case bodyText = "body_text"
        case messageId = "message_id"
        case inReplyTo = "in_reply_to"
        case hasAttachments = "has_attachments"
        case attachments
        case status
        case aiDraft = "ai_draft"
        case aiIntent = "ai_intent"
        case aiConfidence = "ai_confidence"
        case customerId = "customer_id"
        case orderId = "order_id"
        case createdAt = "created_at"
        case readAt = "read_at"
        case repliedAt = "replied_at"
        case receivedAt = "received_at"
    }

    // MARK: - Computed Properties

    var isInbound: Bool {
        direction == "inbound"
    }

    var displayFrom: String {
        if let name = fromName, !name.isEmpty {
            return name
        }
        return fromEmail
    }

    var displayBody: String {
        bodyText ?? bodyHtml?.strippingHTML ?? ""
    }

    var previewText: String {
        let text = displayBody
        if text.count > 120 {
            return String(text.prefix(120)) + "..."
        }
        return text
    }

    var displayDate: String {
        guard let date = receivedAt ?? createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var hasAIDraft: Bool {
        aiDraft != nil && !aiDraft!.isEmpty
    }

    var confidenceLabel: String? {
        guard let confidence = aiConfidence else { return nil }
        return "\(Int(confidence * 100))%"
    }

    var bubbleColor: Color {
        isInbound ? Color(nsColor: .controlBackgroundColor) : Color.accentColor.opacity(0.15)
    }
}

// MARK: - Inbox Attachment

struct InboxAttachment: Codable, Identifiable, Hashable {
    let id: String
    let filename: String
    let contentType: String
    let contentDisposition: String?

    enum CodingKeys: String, CodingKey {
        case id
        case filename
        case contentType = "content_type"
        case contentDisposition = "content_disposition"
    }

    var icon: String {
        if contentType.hasPrefix("image/") { return "photo" }
        if contentType.hasPrefix("application/pdf") { return "doc.richtext" }
        if contentType.hasPrefix("text/") { return "doc.text" }
        return "paperclip"
    }
}

// MARK: - Mailbox Enum

enum InboxMailbox: String, CaseIterable, Identifiable {
    case all
    case support
    case orders
    case returns
    case info
    case general

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All Mail"
        case .support: return "Support"
        case .orders: return "Orders"
        case .returns: return "Returns"
        case .info: return "Info"
        case .general: return "General"
        }
    }

    var icon: String {
        switch self {
        case .all: return "tray"
        case .support: return "questionmark.bubble"
        case .orders: return "shippingbox"
        case .returns: return "arrow.uturn.left.circle"
        case .info: return "info.circle"
        case .general: return "envelope"
        }
    }

    var filterValue: String? {
        self == .all ? nil : rawValue
    }
}

// MARK: - Thread Status

enum ThreadStatus: String, CaseIterable, Identifiable {
    case open
    case awaitingReply = "awaiting_reply"
    case resolved
    case closed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open: return "Open"
        case .awaitingReply: return "Awaiting Reply"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }

    var color: Color {
        switch self {
        case .open: return .blue
        case .awaitingReply: return .orange
        case .resolved: return .green
        case .closed: return .gray
        }
    }
}

// MARK: - String HTML Stripping Extension

private extension String {
    var strippingHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
