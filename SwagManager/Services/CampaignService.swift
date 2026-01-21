import Foundation
import Supabase

@MainActor
class CampaignService {
    // Use service_role client to bypass RLS for admin operations
    private let client: SupabaseClient

    init() {
        // Service role key - bypasses RLS, safe for admin operations in desktop app
        let serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI"

        client = SupabaseClient(
            supabaseURL: URL(string: "https://uaednwpxursknmwdeejn.supabase.co")!,
            supabaseKey: serviceRoleKey
        )
    }

    // MARK: - Email Campaigns

    func loadEmailCampaigns(storeId: UUID) async throws -> [EmailCampaign] {
        let response = try await client
            .from("email_campaigns")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .order("created_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }

        return try decoder.decode([EmailCampaign].self, from: response.data)
    }

    func getEmailCampaign(id: UUID) async throws -> EmailCampaign {
        let response = try await client
            .from("email_campaigns")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }

        return try decoder.decode(EmailCampaign.self, from: response.data)
    }

    // MARK: - Meta Campaigns

    func loadMetaCampaigns(storeId: UUID) async throws -> [MetaCampaign] {
        let response = try await client
            .from("meta_campaigns")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .order("created_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }

        return try decoder.decode([MetaCampaign].self, from: response.data)
    }

    func getMetaCampaign(id: UUID) async throws -> MetaCampaign {
        let response = try await client
            .from("meta_campaigns")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }

        return try decoder.decode(MetaCampaign.self, from: response.data)
    }

    // MARK: - Meta Integrations

    func loadMetaIntegrations(storeId: UUID) async throws -> [MetaIntegration] {
        let response = try await client
            .from("meta_integrations")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }

        return try decoder.decode([MetaIntegration].self, from: response.data)
    }

    func getMetaIntegration(id: UUID) async throws -> MetaIntegration {
        let response = try await client
            .from("meta_integrations")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }

        return try decoder.decode(MetaIntegration.self, from: response.data)
    }

    // MARK: - Marketing Campaigns (unified)

    func loadMarketingCampaigns(storeId: UUID) async throws -> [MarketingCampaign] {
        let response = try await client
            .from("marketing_campaigns")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .order("created_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }

        return try decoder.decode([MarketingCampaign].self, from: response.data)
    }

    // MARK: - SMS Campaigns

    func loadSMSCampaigns(storeId: UUID) async throws -> [SMSCampaign] {
        do {
            let response = try await client
                .from("sms_campaigns")
                .select()
                .eq("store_id", value: storeId.uuidString)
                .order("created_at", ascending: false)
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
            }

            return try decoder.decode([SMSCampaign].self, from: response.data)
        } catch {
            // SMS campaigns table uses custom RLS configuration parameter
            // Return empty array if RLS error
            if error.localizedDescription.contains("app.current_store_id") {
                return []
            }
            throw error
        }
    }
}
