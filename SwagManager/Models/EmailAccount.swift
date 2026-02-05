import Foundation
import SwiftUI

// MARK: - Connected Email Account

struct EmailAccount: Codable, Identifiable {
    let id: UUID
    let storeId: UUID
    let emailAddress: String
    let displayName: String?
    let provider: String
    let isActive: Bool
    let lastSyncAt: Date?
    let syncError: String?
    let syncEnabled: Bool
    let aiEnabled: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case emailAddress = "email_address"
        case displayName = "display_name"
        case provider
        case isActive = "is_active"
        case lastSyncAt = "last_sync_at"
        case syncError = "sync_error"
        case syncEnabled = "sync_enabled"
        case aiEnabled = "ai_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var providerIcon: String {
        switch provider {
        case "gmail": return "envelope.fill"
        case "outlook": return "envelope.badge.fill"
        default: return "envelope"
        }
    }

    var providerName: String {
        switch provider {
        case "gmail": return "Gmail"
        case "outlook": return "Outlook"
        default: return provider.capitalized
        }
    }

    var statusColor: Color {
        if let _ = syncError {
            return .red
        }
        return isActive ? .green : .secondary
    }

    var statusText: String {
        if let error = syncError {
            return "Error: \(error)"
        }
        return isActive ? "Connected" : "Disconnected"
    }

    var lastSyncText: String {
        guard let date = lastSyncAt else { return "Never synced" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

// MARK: - OAuth Start Response

struct OAuthStartResponse: Codable {
    let authUrl: String
    let state: String

    enum CodingKeys: String, CodingKey {
        case authUrl = "auth_url"
        case state
    }
}
