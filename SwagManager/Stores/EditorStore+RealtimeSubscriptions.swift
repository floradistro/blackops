import SwiftUI
import Supabase
import Realtime

// MARK: - EditorStore Realtime Subscriptions Extension
// Handles realtime subscriptions

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

        // Realtime subscriptions disabled - causes performance issues with @Observable
        // Can be re-enabled when needed for specific features
    }
}
