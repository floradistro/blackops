import Foundation

// MARK: - Email Campaign

struct EmailCampaign: Identifiable, Codable, Hashable {
    let id: UUID
    let storeId: UUID?
    let name: String
    let subject: String
    let previewText: String?
    let status: CampaignStatus
    let totalRecipients: Int
    let totalSent: Int
    let totalDelivered: Int
    let totalOpened: Int
    let totalClicked: Int
    let totalBounced: Int
    let totalComplained: Int
    let totalEngaged: Int
    let totalRevenue: Decimal?
    let objective: CampaignObjective?
    let channels: [String]
    let createdAt: Date
    let updatedAt: Date
    let sentAt: Date?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, subject, status, channels
        case storeId = "store_id"
        case previewText = "preview_text"
        case totalRecipients = "total_recipients"
        case totalSent = "total_sent"
        case totalDelivered = "total_delivered"
        case totalOpened = "total_opened"
        case totalClicked = "total_clicked"
        case totalBounced = "total_bounced"
        case totalComplained = "total_complained"
        case totalEngaged = "total_engaged"
        case totalRevenue = "total_revenue"
        case objective
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case sentAt = "sent_at"
        case completedAt = "completed_at"
    }

    var openRate: Double {
        guard totalSent > 0 else { return 0 }
        return Double(totalOpened) / Double(totalSent) * 100
    }

    var clickRate: Double {
        guard totalSent > 0 else { return 0 }
        return Double(totalClicked) / Double(totalSent) * 100
    }

    var deliveryRate: Double {
        guard totalSent > 0 else { return 0 }
        return Double(totalDelivered) / Double(totalSent) * 100
    }
}

enum CampaignStatus: String, Codable {
    case draft
    case scheduled
    case sending
    case sent
    case paused
    case cancelled
    case testing
}

enum CampaignObjective: String, Codable {
    case awareness
    case engagement
    case conversion
    case retention
    case loyalty
}

// MARK: - Meta Integration

struct MetaIntegration: Identifiable, Codable, Hashable {
    let id: UUID
    let storeId: UUID
    let appId: String
    let adAccountId: String?
    let pixelId: String?
    let pageId: String?
    let instagramBusinessId: String?
    let businessId: String?
    let businessName: String?
    let status: MetaIntegrationStatus
    let lastError: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status
        case storeId = "store_id"
        case appId = "app_id"
        case adAccountId = "ad_account_id"
        case pixelId = "pixel_id"
        case pageId = "page_id"
        case instagramBusinessId = "instagram_business_id"
        case businessId = "business_id"
        case businessName = "business_name"
        case lastError = "last_error"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum MetaIntegrationStatus: String, Codable {
    case active
    case disconnected
    case expired
    case error
}

// MARK: - Meta Campaign

struct MetaCampaign: Identifiable, Codable, Hashable {
    let id: UUID
    let storeId: UUID
    let metaCampaignId: String
    let metaAccountId: String
    let name: String
    let objective: String?
    let status: String?
    let effectiveStatus: String?
    let dailyBudget: Decimal?
    let lifetimeBudget: Decimal?
    let budgetRemaining: Decimal?
    let startTime: Date?
    let stopTime: Date?
    let impressions: Int
    let reach: Int
    let clicks: Int
    let spend: Decimal
    let conversions: Int
    let conversionValue: Decimal
    let cpc: Decimal?
    let cpm: Decimal?
    let ctr: Decimal?
    let roas: Decimal?
    let lastSyncedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, objective, status, impressions, reach, clicks, spend, conversions
        case storeId = "store_id"
        case metaCampaignId = "meta_campaign_id"
        case metaAccountId = "meta_account_id"
        case effectiveStatus = "effective_status"
        case dailyBudget = "daily_budget"
        case lifetimeBudget = "lifetime_budget"
        case budgetRemaining = "budget_remaining"
        case startTime = "start_time"
        case stopTime = "stop_time"
        case conversionValue = "conversion_value"
        case cpc, cpm, ctr, roas
        case lastSyncedAt = "last_synced_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var clickRate: Double {
        guard impressions > 0 else { return 0 }
        return Double(clicks) / Double(impressions) * 100
    }

    var costPerClick: Decimal {
        cpc ?? 0
    }
}

// MARK: - SMS Campaign

struct SMSCampaign: Identifiable, Codable, Hashable {
    let id: UUID
    let storeId: UUID
    let name: String
    let messageBody: String
    let status: CampaignStatus
    let totalRecipients: Int
    let totalSent: Int
    let totalDelivered: Int
    let totalFailed: Int
    let totalClicked: Int
    let totalConversions: Int
    let totalRevenue: Decimal
    let totalCost: Decimal
    let createdAt: Date
    let updatedAt: Date
    let sentAt: Date?
    let scheduledFor: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, status
        case storeId = "store_id"
        case messageBody = "message_body"
        case totalRecipients = "total_recipients"
        case totalSent = "total_sent"
        case totalDelivered = "total_delivered"
        case totalFailed = "total_failed"
        case totalClicked = "total_clicked"
        case totalConversions = "total_conversions"
        case totalRevenue = "total_revenue"
        case totalCost = "total_cost"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case sentAt = "sent_at"
        case scheduledFor = "scheduled_for"
    }
}

// MARK: - Marketing Campaign (unified view)

struct MarketingCampaign: Identifiable, Codable, Hashable {
    let id: UUID
    let storeId: UUID
    let name: String
    let subject: String
    let status: String
    let recipientCount: Int
    let sentCount: Int
    let deliveredCount: Int
    let openedCount: Int
    let clickedCount: Int
    let bouncedCount: Int
    let complainedCount: Int
    let createdAt: Date
    let updatedAt: Date
    let scheduledAt: Date?
    let sentAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, subject, status
        case storeId = "store_id"
        case recipientCount = "recipient_count"
        case sentCount = "sent_count"
        case deliveredCount = "delivered_count"
        case openedCount = "opened_count"
        case clickedCount = "clicked_count"
        case bouncedCount = "bounced_count"
        case complainedCount = "complained_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case scheduledAt = "scheduled_at"
        case sentAt = "sent_at"
    }

    var openRate: Double {
        guard sentCount > 0 else { return 0 }
        return Double(openedCount) / Double(sentCount) * 100
    }

    var clickRate: Double {
        guard sentCount > 0 else { return 0 }
        return Double(clickedCount) / Double(sentCount) * 100
    }
}
