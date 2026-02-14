import Foundation
import Supabase
import Auth

// MARK: - Supabase Configuration

enum SupabaseConfig {
    // Production: floradistro.com
    static let url = URL(string: "https://uaednwpxursknmwdeejn.supabase.co")!

    // Anon key - safe for client-side use (RLS protects data)
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA5OTcyMzMsImV4cCI6MjA3NjU3MzIzM30.N8jPwlyCBB5KJB5I-XaK6m-mq88rSR445AWFJJmwRCg"

    // Service role key - for local agent server only (bypasses RLS)
    // NOTE: This runs locally, not exposed to network
    static let serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI"

    /// Unified agent server on Fly.io — handles SSE chat + direct tool execution
    static let agentServerURL = URL(string: "https://whale-agent.fly.dev")!
}

// MARK: - UserDefaults Auth Storage (avoids Keychain prompts during development)

final class UserDefaultsAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let defaults = UserDefaults.standard
    private let keyPrefix = "supabase.auth."

    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: keyPrefix + key)
    }

    func retrieve(key: String) throws -> Data? {
        defaults.data(forKey: keyPrefix + key)
    }

    func remove(key: String) throws {
        defaults.removeObject(forKey: keyPrefix + key)
    }
}

// MARK: - Supabase Service Coordinator

@MainActor
class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    // Admin client - uses service role key for privileged operations (bypasses RLS)
    // ONLY use for local admin operations, NEVER expose to network
    let adminClient: SupabaseClient

    private init() {
        // Using anon key - RLS policies enforce security
        // Using UserDefaults storage to avoid Keychain password prompts during development
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(
                auth: .init(
                    storage: UserDefaultsAuthLocalStorage(),
                    flowType: .implicit,
                    autoRefreshToken: true,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )

        // Admin client with service role key - bypasses RLS
        // Used for agent config and other admin operations that run locally
        adminClient = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.serviceRoleKey
        )
    }

    // MARK: - Stores

    func fetchStores(limit: Int = 100) async throws -> [Store] {
        try await client.from("stores")
            .select()
            .limit(limit)
            .execute()
            .value
    }

    func fetchStore(id: UUID) async throws -> Store {
        try await client.from("stores")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createStore(_ store: StoreInsert) async throws -> Store {
        try await client.from("stores")
            .insert(store)
            .select()
            .single()
            .execute()
            .value
    }

}
