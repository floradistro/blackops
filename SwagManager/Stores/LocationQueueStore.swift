//
//  LocationQueueStore.swift
//  SwagManager
//
//  Observable store for location queue state.
//  Provides backend-driven customer queue shared across all registers at a location.
//  Uses Supabase Realtime for live updates across all registers.
//

import Foundation
import Combine
import Supabase

extension Notification.Name {
    static let queueDidChange = Notification.Name("queueDidChange")
}

@MainActor
final class LocationQueueStore: ObservableObject {

    // MARK: - Singleton per location (keyed by locationId)

    private static var stores: [UUID: LocationQueueStore] = [:]

    static func shared(for locationId: UUID) -> LocationQueueStore {
        if let existing = stores[locationId] {
            return existing
        }
        let store = LocationQueueStore(locationId: locationId)
        stores[locationId] = store
        return store
    }

    // MARK: - Published State

    @Published private(set) var queue: [QueueEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published var selectedCartId: UUID?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var connectionState: ConnectionState = .disconnected

    enum ConnectionState {
        case connected
        case connecting
        case disconnected
        case error
    }

    /// Callback when queue changes (for views that can't use @ObservedObject)
    var onQueueChanged: (() -> Void)?

    // MARK: - Properties

    let locationId: UUID
    private var refreshTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var isSubscribed = false
    private let supabase: SupabaseClient

    // MARK: - Computed Properties

    var selectedEntry: QueueEntry? {
        guard let cartId = selectedCartId else { return nil }
        return queue.first { $0.cartId == cartId }
    }

    var count: Int { queue.count }
    var isEmpty: Bool { queue.isEmpty }

    // MARK: - Init

    private init(locationId: UUID) {
        self.locationId = locationId
        self.supabase = SupabaseService.shared.client
    }

    // MARK: - Queue Operations

    /// Load queue from backend
    func loadQueue() async {
        isLoading = true
        error = nil

        do {
            let entries = try await LocationQueueService.shared.getQueue(locationId: locationId)

            // Only update if data actually changed (avoid unnecessary UI refreshes)
            let hasChanged = queue.count != entries.count || !queue.elementsEqual(entries)

            if hasChanged {
                objectWillChange.send()
                queue = entries
                lastUpdated = Date()

                // If we have entries but no selection, select the first one
                if selectedCartId == nil, let first = entries.first {
                    selectedCartId = first.cartId
                }

                // If selected cart is no longer in queue, clear selection
                if let selectedId = selectedCartId, !entries.contains(where: { $0.cartId == selectedId }) {
                    selectedCartId = entries.first?.cartId
                }

                // Post notification for UI updates
                NotificationCenter.default.post(name: .queueDidChange, object: locationId)
                NSLog("[LocationQueueStore] Queue updated with \(entries.count) entries")
            }

            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    /// Refresh queue (for pull-to-refresh or manual refresh)
    func refresh() async {
        await loadQueue()
    }

    /// Add customer to queue
    func addToQueue(cartId: UUID, customerId: UUID?, userId: UUID?) async {
        do {
            let entries = try await LocationQueueService.shared.addToQueue(
                locationId: locationId,
                cartId: cartId,
                customerId: customerId,
                userId: userId
            )
            queue = entries
            selectedCartId = cartId
            // Post notification for UI updates
            NotificationCenter.default.post(name: .queueDidChange, object: locationId)
            NSLog("[LocationQueueStore] Added to queue, now \(entries.count) entries")
        } catch {
            self.error = error.localizedDescription
            NSLog("[LocationQueueStore] Failed to add to queue: \(error)")
        }
    }

    /// Remove customer from queue
    func removeFromQueue(cartId: UUID) async {
        do {
            let entries = try await LocationQueueService.shared.removeFromQueue(
                locationId: locationId,
                cartId: cartId
            )
            queue = entries

            // If we removed the selected cart, select the first remaining
            if selectedCartId == cartId {
                selectedCartId = entries.first?.cartId
            }
            // Post notification for UI updates
            NotificationCenter.default.post(name: .queueDidChange, object: locationId)
            NSLog("[LocationQueueStore] Removed from queue, now \(entries.count) entries")
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Clear entire queue
    func clearQueue() async {
        do {
            try await LocationQueueService.shared.clearQueue(locationId: locationId)
            queue = []
            selectedCartId = nil
            // Post notification for UI updates
            NotificationCenter.default.post(name: .queueDidChange, object: locationId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Select a cart from the queue
    func selectCart(_ cartId: UUID) {
        if queue.contains(where: { $0.cartId == cartId }) {
            selectedCartId = cartId
        }
    }

    /// Select cart at index
    func selectCartAtIndex(_ index: Int) {
        guard index >= 0, index < queue.count else { return }
        selectedCartId = queue[index].cartId
    }

    // MARK: - Supabase Realtime

    /// Subscribe to realtime updates for this location's queue
    func subscribeToRealtime() {
        guard !isSubscribed else {
            NSLog("[LocationQueueStore] ⚠️ Already subscribed, skipping")
            return
        }

        let channelName = "location-queue-\(locationId.uuidString)"
        let locId = locationId

        NSLog("[LocationQueueStore] 🔌 Starting realtime subscription for location \(locId)")

        connectionState = .connecting

        // Start polling as backup (every 5 seconds) - Apple's typical refresh interval
        startPolling(interval: 5.0)

        // Use realtimeV2 API (Supabase Swift SDK v2+)
        let channel = supabase.realtimeV2.channel(channelName)

        // Listen for ALL event types WITHOUT filter first to see if events are coming through
        let allInserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "location_queue"
        )

        let allUpdates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "location_queue"
        )

        let allDeletes = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "location_queue"
        )

        NSLog("[LocationQueueStore] ⚠️ DEBUG MODE: Listening to ALL events on location_queue (no filter) to debug")

        realtimeChannel = channel

        // Subscribe and listen for changes
        realtimeTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                NSLog("[LocationQueueStore] Subscribing to channel...")
                try await channel.subscribeWithError()

                await MainActor.run { [weak self] in
                    self?.isSubscribed = true
                    self?.connectionState = .connected
                    NSLog("[LocationQueueStore] ✅ SUBSCRIBED to realtime for location \(locId)")
                }

                // Listen for all event types concurrently
                await withTaskGroup(of: Void.self) { group in
                    // Listen for INSERTs
                    group.addTask { [weak self] in
                        for await insert in allInserts {
                            guard !Task.isCancelled else { break }
                            let eventLocIdStr = String(describing: insert.record["location_id"] ?? "unknown")
                            NSLog("[LocationQueueStore] 📡 INSERT EVENT DETECTED! Location: \(eventLocIdStr)")
                            // Only handle if it's for our location
                            if eventLocIdStr.lowercased() == locId.uuidString.lowercased() {
                                NSLog("[LocationQueueStore] ✅ INSERT is for our location - handling")
                                await self?.handleInsertEvent(insert)
                            } else {
                                NSLog("[LocationQueueStore] ⚠️ INSERT is for different location - ignoring")
                            }
                        }
                    }

                    // Listen for UPDATEs
                    group.addTask { [weak self] in
                        for await update in allUpdates {
                            guard !Task.isCancelled else { break }
                            let eventLocIdStr = String(describing: update.record["location_id"] ?? "unknown")
                            NSLog("[LocationQueueStore] 📡 UPDATE EVENT DETECTED! Location: \(eventLocIdStr)")
                            // Only handle if it's for our location
                            if eventLocIdStr.lowercased() == locId.uuidString.lowercased() {
                                NSLog("[LocationQueueStore] ✅ UPDATE is for our location - handling")
                                await self?.handleUpdateEvent(update)
                            } else {
                                NSLog("[LocationQueueStore] ⚠️ UPDATE is for different location - ignoring")
                            }
                        }
                    }

                    // Listen for DELETEs
                    group.addTask { [weak self] in
                        for await delete in allDeletes {
                            guard !Task.isCancelled else { break }
                            let eventLocIdStr = String(describing: delete.oldRecord["location_id"] ?? "unknown")
                            NSLog("[LocationQueueStore] 📡 DELETE EVENT DETECTED! Location: \(eventLocIdStr)")
                            // Only handle if it's for our location
                            if eventLocIdStr.lowercased() == locId.uuidString.lowercased() {
                                NSLog("[LocationQueueStore] ✅ DELETE is for our location - handling")
                                await self?.handleDeleteEvent(delete)
                            } else {
                                NSLog("[LocationQueueStore] ⚠️ DELETE is for different location - ignoring")
                            }
                        }
                    }

                    await group.waitForAll()
                }

                NSLog("[LocationQueueStore] Realtime listener loop ended")
            } catch {
                NSLog("[LocationQueueStore] ❌ Subscription error: \(error.localizedDescription)")
                await MainActor.run { [weak self] in
                    self?.connectionState = .error
                }
            }

            await MainActor.run { [weak self] in
                self?.isSubscribed = false
                self?.connectionState = .disconnected
            }
        }
    }

    /// Unsubscribe from realtime updates
    func unsubscribeFromRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil

        if let channel = realtimeChannel {
            Task {
                await channel.unsubscribe()
                await supabase.realtimeV2.removeChannel(channel)
                NSLog("[LocationQueueStore] Unsubscribed from realtime")
            }
            realtimeChannel = nil
        }

        isSubscribed = false
    }

    /// Handle INSERT event - new customer added to queue
    private func handleInsertEvent(_ insert: InsertAction) async {
        NSLog("[LocationQueueStore] 🆕 INSERT - reloading queue")
        await loadQueue()
        NSLog("[LocationQueueStore] Queue reloaded - now has \(queue.count) entries")
    }

    /// Handle UPDATE event - customer updated in queue
    private func handleUpdateEvent(_ update: UpdateAction) async {
        NSLog("[LocationQueueStore] 🔄 UPDATE - reloading queue")
        await loadQueue()
        NSLog("[LocationQueueStore] Queue reloaded - now has \(queue.count) entries")
    }

    /// Handle DELETE event - customer removed from queue
    private func handleDeleteEvent(_ delete: DeleteAction) async {
        NSLog("[LocationQueueStore] 🗑️ DELETE - reloading queue")
        await loadQueue()
        NSLog("[LocationQueueStore] Queue reloaded - now has \(queue.count) entries")
    }

    // MARK: - Polling (optional - for real-time sync without websockets)

    /// Start polling for queue updates
    func startPolling(interval: TimeInterval = 5.0) {
        stopPolling()
        pollingTask = Task {
            while !Task.isCancelled {
                await loadQueue()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    /// Stop polling
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Cleanup

    static func removeStore(for locationId: UUID) {
        stores[locationId]?.stopPolling()
        stores[locationId]?.unsubscribeFromRealtime()
        stores.removeValue(forKey: locationId)
    }
}

// MARK: - Convenience Extensions

extension LocationQueueStore {
    /// Get entry at index
    func entry(at index: Int) -> QueueEntry? {
        guard index >= 0, index < queue.count else { return nil }
        return queue[index]
    }

    /// Get index of selected entry
    var selectedIndex: Int? {
        guard let cartId = selectedCartId else { return nil }
        return queue.firstIndex { $0.cartId == cartId }
    }

    /// Check if a cart is in the queue
    func contains(cartId: UUID) -> Bool {
        queue.contains { $0.cartId == cartId }
    }
}
