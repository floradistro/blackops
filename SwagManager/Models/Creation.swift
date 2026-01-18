import Foundation
import SwiftUI

enum CreationType: String, Codable, CaseIterable, Identifiable {
    case app
    case display
    case email
    case landing
    case dashboard
    case artifact
    case store

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .app: return "Apps"
        case .display: return "Displays"
        case .email: return "Emails"
        case .landing: return "Landing Pages"
        case .dashboard: return "Dashboards"
        case .artifact: return "Artifacts"
        case .store: return "Stores"
        }
    }

    var icon: String {
        switch self {
        case .app: return "app.badge"
        case .display: return "display"
        case .email: return "envelope"
        case .landing: return "globe"
        case .dashboard: return "chart.bar.xaxis"
        case .artifact: return "cube"
        case .store: return "storefront"
        }
    }

    var color: Color {
        switch self {
        case .app: return .blue
        case .display: return .purple
        case .email: return .orange
        case .landing: return .green
        case .dashboard: return .cyan
        case .artifact: return .pink
        case .store: return .yellow
        }
    }
}

enum CreationStatus: String, Codable, CaseIterable {
    case draft
    case published

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .published: return "Published"
        }
    }

    var color: Color {
        switch self {
        case .draft: return .gray
        case .published: return .green
        }
    }
}

struct Creation: Codable, Identifiable, Hashable {
    let id: UUID
    var creationType: CreationType
    var name: String
    var slug: String
    var description: String?
    var iconUrl: String?
    var coverImageUrl: String?
    var storeId: UUID?
    var agentConfig: [String: AnyCodable]?
    var status: CreationStatus?
    var isPublic: Bool?
    var isFeatured: Bool?
    var isFree: Bool?
    var priceType: String?
    var priceAmount: Double?
    var priceCurrency: String?
    var installCount: Int?
    var viewCount: Int?
    var ratingAverage: Double?
    var ratingCount: Int?
    var version: String?
    var changelog: [String: AnyCodable]?
    var createdAt: Date?
    var updatedAt: Date?
    var publishedAt: Date?
    var reactCode: String?
    var dataConfig: [String: AnyCodable]?
    var themeConfig: [String: AnyCodable]?
    var layoutConfig: [String: AnyCodable]?
    var locationId: UUID?
    var displayNumber: Int?
    var deployedUrl: String?
    var githubRepo: String?
    var vercelProjectId: String?
    var thumbnailUrl: String?
    var thumbnailGeneratedAt: Date?
    var conversationId: UUID?
    var liveStatus: String?
    var lastHeartbeat: Date?
    var deviceInfo: [String: AnyCodable]?
    var visibility: String?
    var displayMode: String?
    var isPinned: Bool?
    var pinnedAt: Date?
    var pinOrder: Int?
    var isTemplate: Bool?
    var ownerUserId: UUID?
    var templateSourceId: UUID?
    var deletedAt: String?  // Soft delete timestamp (as string to avoid decoding issues)

    enum CodingKeys: String, CodingKey {
        case id
        case creationType = "creation_type"
        case name, slug, description
        case iconUrl = "icon_url"
        case coverImageUrl = "cover_image_url"
        case storeId = "store_id"
        case agentConfig = "agent_config"
        case status
        case isPublic = "is_public"
        case isFeatured = "is_featured"
        case isFree = "is_free"
        case priceType = "price_type"
        case priceAmount = "price_amount"
        case priceCurrency = "price_currency"
        case installCount = "install_count"
        case viewCount = "view_count"
        case ratingAverage = "rating_average"
        case ratingCount = "rating_count"
        case version, changelog
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case publishedAt = "published_at"
        case reactCode = "react_code"
        case dataConfig = "data_config"
        case themeConfig = "theme_config"
        case layoutConfig = "layout_config"
        case locationId = "location_id"
        case displayNumber = "display_number"
        case deployedUrl = "deployed_url"
        case githubRepo = "github_repo"
        case vercelProjectId = "vercel_project_id"
        case thumbnailUrl = "thumbnail_url"
        case thumbnailGeneratedAt = "thumbnail_generated_at"
        case conversationId = "conversation_id"
        case liveStatus = "live_status"
        case lastHeartbeat = "last_heartbeat"
        case deviceInfo = "device_info"
        case visibility
        case displayMode = "display_mode"
        case isPinned = "is_pinned"
        case pinnedAt = "pinned_at"
        case pinOrder = "pin_order"
        case isTemplate = "is_template"
        case ownerUserId = "owner_user_id"
        case templateSourceId = "template_source_id"
        case deletedAt = "deleted_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Creation, rhs: Creation) -> Bool {
        lhs.id == rhs.id
    }
}

struct CreationInsert: Codable {
    var creationType: CreationType
    var name: String
    var slug: String
    var description: String?
    var status: CreationStatus?
    var reactCode: String?
    var storeId: UUID?
    var ownerUserId: UUID?

    enum CodingKeys: String, CodingKey {
        case creationType = "creation_type"
        case name, slug, description, status
        case reactCode = "react_code"
        case storeId = "store_id"
        case ownerUserId = "owner_user_id"
    }
}

struct CreationUpdate: Codable {
    var name: String?
    var slug: String?
    var description: String?
    var status: CreationStatus?
    var reactCode: String?
    var iconUrl: String?
    var coverImageUrl: String?
    var isPublic: Bool?
    var visibility: String?
    var version: String?

    enum CodingKeys: String, CodingKey {
        case name, slug, description, status
        case reactCode = "react_code"
        case iconUrl = "icon_url"
        case coverImageUrl = "cover_image_url"
        case isPublic = "is_public"
        case visibility, version
    }
}
