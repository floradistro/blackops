import Foundation
import SwiftUI

// MARK: - Store Email Domain Model
// Represents an email domain registered for a store

struct StoreEmailDomain: Codable, Identifiable, Hashable {
    let id: UUID
    let storeId: UUID
    let domain: String
    let inboundSubdomain: String
    let resendDomainId: String?
    let status: String
    let receivingEnabled: Bool
    let sendingVerified: Bool
    let dnsRecords: [DNSRecord]?
    let verifiedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case domain
        case inboundSubdomain = "inbound_subdomain"
        case resendDomainId = "resend_domain_id"
        case status
        case receivingEnabled = "receiving_enabled"
        case sendingVerified = "sending_verified"
        case dnsRecords = "dns_records"
        case verifiedAt = "verified_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    var fullInboundDomain: String {
        "\(inboundSubdomain).\(domain)"
    }

    var statusColor: Color {
        switch status {
        case "verified": return .green
        case "pending", "verifying": return .orange
        case "failed": return .red
        default: return .secondary
        }
    }

    var statusLabel: String {
        status.capitalized
    }

    var statusIcon: String {
        switch status {
        case "verified": return "checkmark.seal.fill"
        case "pending": return "clock.fill"
        case "verifying": return "arrow.triangle.2.circlepath"
        case "failed": return "xmark.seal.fill"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - DNS Record

struct DNSRecord: Codable, Hashable, Identifiable {
    let record: String
    let name: String
    let type: String
    let value: String
    let priority: Int?
    let status: String

    var id: String { "\(record)-\(name)-\(type)" }

    var statusColor: Color {
        switch status {
        case "verified": return .green
        case "pending", "not_started": return .orange
        case "failed": return .red
        default: return .secondary
        }
    }

    var statusIcon: String {
        switch status {
        case "verified": return "checkmark.circle.fill"
        case "pending", "not_started": return "clock.fill"
        case "failed": return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }

    var displayValue: String {
        if value.count > 50 {
            return String(value.prefix(47)) + "..."
        }
        return value
    }
}

// MARK: - Store Email Address Model
// Represents an email address/mailbox configured for a domain

struct StoreEmailAddress: Codable, Identifiable, Hashable {
    let id: UUID
    let storeId: UUID
    let domainId: UUID
    let address: String
    let displayName: String?
    let mailboxType: String
    let aiEnabled: Bool
    let aiAutoReply: Bool
    let isActive: Bool
    let createdAt: Date?
    let updatedAt: Date?

    // Joined domain info (optional)
    let domain: StoreEmailDomainRef?

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case domainId = "domain_id"
        case address
        case displayName = "display_name"
        case mailboxType = "mailbox_type"
        case aiEnabled = "ai_enabled"
        case aiAutoReply = "ai_auto_reply"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case domain
    }

    var fullEmail: String? {
        guard let domain else { return nil }
        return "\(address)@\(domain.inboundSubdomain).\(domain.domain)"
    }

    var mailboxIcon: String {
        switch mailboxType {
        case "support": return "questionmark.bubble.fill"
        case "orders": return "shippingbox.fill"
        case "returns": return "arrow.uturn.left.circle.fill"
        case "info": return "info.circle.fill"
        default: return "envelope.fill"
        }
    }

    var mailboxColor: Color {
        switch mailboxType {
        case "support": return .blue
        case "orders": return .purple
        case "returns": return .orange
        case "info": return .green
        default: return .secondary
        }
    }
}

// Reference struct for joined domain data
struct StoreEmailDomainRef: Codable, Hashable {
    let id: UUID
    let domain: String
    let inboundSubdomain: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case domain
        case inboundSubdomain = "inbound_subdomain"
        case status
    }
}
