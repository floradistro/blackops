// Extracted from SupabaseService.swift following Apple engineering standards

import Foundation
import Supabase

@MainActor
final class StoreLocationService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Stores

    func fetchStores(limit: Int = 50) async throws -> [Store] {
        // SECURITY: Must query via users table to ensure user has access (matches iOS implementation)
        // Get authenticated user ID
        guard let session = try? await client.auth.session else {
            return []
        }

        let authUserId = session.user.id

        // Query users table filtered by auth_user_id, join with stores table
        struct UserStoreRow: Decodable {
            let store_id: UUID
            let stores: Store?
        }

        let rows: [UserStoreRow] = try await client
            .from("users")
            .select("store_id, stores(id, store_name, slug, email, owner_user_id, status, phone, address, city, state, zip, logo_url, banner_url, store_description, store_tagline, store_type, total_locations, created_at, updated_at)")
            .eq("auth_user_id", value: authUserId.uuidString)
            .limit(limit)
            .execute()
            .value

        // Extract stores from joined data
        let stores = rows.compactMap { $0.stores }
        return stores.sorted { $0.storeName < $1.storeName }
    }

    func fetchStore(id: UUID) async throws -> Store {
        return try await client.from("stores")
            .select("id, store_name, slug, email, owner_user_id, status, phone, address, city, state, zip, logo_url, banner_url, store_description, store_tagline, store_type, total_locations, created_at, updated_at")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createStore(_ store: StoreInsert) async throws -> Store {
        return try await client.from("stores")
            .insert(store)
            .select("id, store_name, slug, email, owner_user_id, status, phone, address, city, state, zip, logo_url, banner_url, store_description, store_tagline, store_type, total_locations, created_at, updated_at")
            .single()
            .execute()
            .value
    }

    // MARK: - Locations

    func fetchLocations(storeId: UUID) async throws -> [Location] {
        return try await client.from("locations")
            .select("*")
            .eq("store_id", value: storeId)
            .order("name", ascending: true)
            .execute()
            .value
    }

    // MARK: - Browser Sessions

    func fetchBrowserSessions(storeId: UUID, limit: Int = 50) async throws -> [BrowserSession] {
        let sessions: [BrowserSession] = try await client.from("browser_sessions")
            .select()
            .eq("store_id", value: storeId)
            .order("last_activity", ascending: false)
            .limit(limit)
            .execute()
            .value

        return sessions
    }

    func fetchBrowserSession(id: UUID) async throws -> BrowserSession? {
        let sessions: [BrowserSession] = try await client.from("browser_sessions")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value

        return sessions.first
    }

    func fetchActiveBrowserSessions(storeId: UUID) async throws -> [BrowserSession] {
        let sessions: [BrowserSession] = try await client.from("browser_sessions")
            .select()
            .eq("store_id", value: storeId)
            .eq("status", value: "active")
            .order("last_activity", ascending: false)
            .execute()
            .value

        return sessions
    }

    func updateBrowserSessionStatus(id: UUID, status: String) async throws {
        try await client.from("browser_sessions")
            .update(["status": status, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id)
            .execute()
    }

    func createBrowserSession(storeId: UUID, name: String) async throws -> BrowserSession {
        let now = Date()
        let formatter = ISO8601DateFormatter()

        struct InsertData: Encodable {
            let store_id: String
            let name: String
            let status: String
            let created_at: String
            let updated_at: String
        }

        let insertData = InsertData(
            store_id: storeId.uuidString,
            name: name,
            status: "active",
            created_at: formatter.string(from: now),
            updated_at: formatter.string(from: now)
        )

        let session: BrowserSession = try await client.from("browser_sessions")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value

        return session
    }

    func deleteBrowserSession(id: UUID) async throws {
        try await client.from("browser_sessions")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func closeBrowserSession(id: UUID) async throws {
        struct UpdateData: Encodable {
            let status: String
            let updated_at: String
        }

        let updateData = UpdateData(
            status: "closed",
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await client.from("browser_sessions")
            .update(updateData)
            .eq("id", value: id)
            .execute()
    }
}
