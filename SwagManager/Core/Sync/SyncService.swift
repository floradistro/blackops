import Foundation
import SwiftData
import Supabase

// MARK: - Sync Service
// Minimal sync service shell - orders/locations/customers moved to separate app

@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()

    private let supabase = SupabaseService.shared
    private var modelContext: ModelContext?
    private var storeId: UUID?

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncTime: Date?

    // MARK: - Configure

    func configure(modelContext: ModelContext, storeId: UUID) {
        self.modelContext = modelContext
        self.storeId = storeId
    }

    // MARK: - Sync (placeholder for future use)

    func syncAll() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncTime = Date()
        }

        // No sync operations currently - orders/locations/customers moved to separate app
    }
}
