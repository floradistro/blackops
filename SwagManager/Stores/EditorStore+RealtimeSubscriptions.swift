import SwiftUI
import Supabase
import Realtime

// MARK: - EditorStore Realtime Subscriptions Extension
// Extracted from EditorStore+RealtimeSync.swift following Apple engineering standards
// File size: ~50 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // Channel reference for cleanup
    private static var _realtimeChannel: RealtimeChannelV2?

    // MARK: - Realtime Cleanup

    /// Stop all realtime subscriptions - call on store switch or app close
    func stopRealtimeSubscription() {
        realtimeTask?.cancel()
        realtimeTask = nil

        // Unsubscribe from channel
        if let channel = EditorStore._realtimeChannel {
            let channelToCleanup = channel
            EditorStore._realtimeChannel = nil
            Task.detached {
                await channelToCleanup.unsubscribe()
            }
        }
    }

    // MARK: - Realtime Subscriptions

    func startRealtimeSubscription() {
        // Clean up any existing subscription first
        stopRealtimeSubscription()

        realtimeTask = Task { [weak self] in
            guard let self = self else { return }

            let client = self.supabase.client

            // Subscribe to all changes on one channel
            let channel = client.realtimeV2.channel("swag-manager-changes")
            EditorStore._realtimeChannel = channel

            // Creations table
            let creationsInserts = channel.postgresChange(InsertAction.self, table: "creations")
            let creationsUpdates = channel.postgresChange(UpdateAction.self, table: "creations")
            let creationsDeletes = channel.postgresChange(DeleteAction.self, table: "creations")

            // Collections table
            let collectionsInserts = channel.postgresChange(InsertAction.self, table: "creation_collections")
            let collectionsUpdates = channel.postgresChange(UpdateAction.self, table: "creation_collections")
            let collectionsDeletes = channel.postgresChange(DeleteAction.self, table: "creation_collections")

            // Collection items table
            let collectionItemsInserts = channel.postgresChange(InsertAction.self, table: "creation_collection_items")
            let collectionItemsDeletes = channel.postgresChange(DeleteAction.self, table: "creation_collection_items")

            // Browser sessions table
            let browserSessionsInserts = channel.postgresChange(InsertAction.self, table: "browser_sessions")
            let browserSessionsUpdates = channel.postgresChange(UpdateAction.self, table: "browser_sessions")
            let browserSessionsDeletes = channel.postgresChange(DeleteAction.self, table: "browser_sessions")

            do {
                try await channel.subscribeWithError()
            } catch {
                return // Don't try to use the channel if subscription failed
            }

            // Process events (implementation in RealtimeHandlers extension)
            await processRealtimeEvents(
                creationsInserts: creationsInserts,
                creationsUpdates: creationsUpdates,
                creationsDeletes: creationsDeletes,
                collectionsInserts: collectionsInserts,
                collectionsUpdates: collectionsUpdates,
                collectionsDeletes: collectionsDeletes,
                collectionItemsInserts: collectionItemsInserts,
                collectionItemsDeletes: collectionItemsDeletes,
                browserSessionsInserts: browserSessionsInserts,
                browserSessionsUpdates: browserSessionsUpdates,
                browserSessionsDeletes: browserSessionsDeletes
            )
        }
    }
}
