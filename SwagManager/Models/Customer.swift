import Foundation

// MARK: - Customer Model
/// Represents a unified customer model combining data from v_store_customers view
struct Customer: Codable, Identifiable, Hashable {
    let id: UUID
    var platformUserId: UUID?
    var storeId: UUID?
    var firstName: String?
    var middleName: String?
    var lastName: String?
    var email: String?
    var phone: String?
    var dateOfBirth: String?
    var avatarUrl: String?
    var streetAddress: String?
    var city: String?
    var state: String?
    var postalCode: String?
    var driversLicenseNumber: String?
    var idVerified: Bool?
    var isActive: Bool?
    var loyaltyPoints: Int?
    var loyaltyTier: String?
    var totalSpent: Decimal?
    var totalOrders: Int?
    var lifetimeValue: Decimal?
    var emailConsent: Bool?
    var smsConsent: Bool?
    var createdAt: Date?
    var updatedAt: Date?

    // Computed properties for display
    var displayName: String {
        let parts = [firstName, middleName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (email ?? phone ?? "Unknown Customer") : parts.joined(separator: " ")
    }

    var initials: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.map { String($0.prefix(1).uppercased()) }.joined()
    }

    var statusIcon: String {
        if isActive == false { return "person.slash" }
        if idVerified == true { return "checkmark.shield" }
        return "person"
    }

    var statusColor: String {
        if isActive == false { return "gray" }
        if idVerified == true { return "green" }
        return "blue"
    }

    var loyaltyTierColor: String {
        guard let tier = loyaltyTier?.lowercased() else { return "gray" }
        switch tier {
        case "platinum": return "purple"
        case "gold": return "yellow"
        case "silver": return "gray"
        case "bronze": return "orange"
        default: return "gray"
        }
    }

    var loyaltyTierIcon: String {
        guard let tier = loyaltyTier?.lowercased() else { return "star" }
        switch tier {
        case "platinum": return "star.circle.fill"
        case "gold": return "star.fill"
        case "silver": return "star"
        case "bronze": return "star.leadinghalf.filled"
        default: return "star"
        }
    }

    var formattedTotalSpent: String {
        guard let spent = totalSpent else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: spent as NSDecimalNumber) ?? "$0.00"
    }

    var formattedLifetimeValue: String {
        guard let ltv = lifetimeValue else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: ltv as NSDecimalNumber) ?? "$0.00"
    }

    var terminalIcon: String {
        if idVerified == true { return "✓" }
        if isActive == false { return "✗" }
        return "●"
    }

    var terminalColor: String {
        if idVerified == true { return "green" }
        if isActive == false { return "gray" }
        return "blue"
    }

    // Coding keys for snake_case to camelCase conversion
    enum CodingKeys: String, CodingKey {
        case id
        case platformUserId = "platform_user_id"
        case storeId = "store_id"
        case firstName = "first_name"
        case middleName = "middle_name"
        case lastName = "last_name"
        case email
        case phone
        case dateOfBirth = "date_of_birth"
        case avatarUrl = "avatar_url"
        case streetAddress = "street_address"
        case city
        case state
        case postalCode = "postal_code"
        case driversLicenseNumber = "drivers_license_number"
        case idVerified = "id_verified"
        case isActive = "is_active"
        case loyaltyPoints = "loyalty_points"
        case loyaltyTier = "loyalty_tier"
        case totalSpent = "total_spent"
        case totalOrders = "total_orders"
        case lifetimeValue = "lifetime_value"
        case emailConsent = "email_consent"
        case smsConsent = "sms_consent"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Customer Note
struct CustomerNote: Codable, Identifiable, Hashable {
    let id: UUID
    var customerId: UUID
    var note: String
    var noteType: String?
    var createdBy: UUID?
    var isCustomerVisible: Bool?
    var createdAt: Date?

    var noteTypeIcon: String {
        guard let type = noteType else { return "note.text" }
        switch type {
        case "support": return "lifepreserver"
        case "billing": return "dollarsign.circle"
        case "fraud": return "exclamationmark.shield"
        case "vip": return "star.circle"
        default: return "note.text"
        }
    }

    var noteTypeColor: String {
        guard let type = noteType else { return "blue" }
        switch type {
        case "support": return "blue"
        case "billing": return "green"
        case "fraud": return "red"
        case "vip": return "purple"
        default: return "gray"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case note
        case noteType = "note_type"
        case createdBy = "created_by"
        case isCustomerVisible = "is_customer_visible"
        case createdAt = "created_at"
    }
}

// MARK: - Customer Loyalty Details
struct CustomerLoyalty: Codable, Identifiable, Hashable {
    let id: UUID
    var storeId: UUID
    var customerId: UUID
    var pointsBalance: Int?
    var pointsLifetimeEarned: Int?
    var pointsLifetimeRedeemed: Int?
    var currentTier: String?
    var tierQualifiedAt: Date?
    var lastEarnedAt: Date?
    var lastRedeemedAt: Date?
    var lastPurchaseAt: Date?
    var provider: String?
    var tierName: String?
    var tierLevel: Int?
    var lifetimePoints: Int?
    var alpineiqCustomerId: String?
    var lastSyncedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case customerId = "customer_id"
        case pointsBalance = "points_balance"
        case pointsLifetimeEarned = "points_lifetime_earned"
        case pointsLifetimeRedeemed = "points_lifetime_redeemed"
        case currentTier = "current_tier"
        case tierQualifiedAt = "tier_qualified_at"
        case lastEarnedAt = "last_earned_at"
        case lastRedeemedAt = "last_redeemed_at"
        case lastPurchaseAt = "last_purchase_at"
        case provider
        case tierName = "tier_name"
        case tierLevel = "tier_level"
        case lifetimePoints = "lifetime_points"
        case alpineiqCustomerId = "alpineiq_customer_id"
        case lastSyncedAt = "last_synced_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
