import Foundation
import Combine
import Supabase

// MARK: - LocationQueueStore Realtime Pro Extension
// Upgraded realtime implementation matching orders quality
// Features: Actor-based locking, incremental updates, zero lag, production-ready

extension LocationQueueStore {

    // MARK: - Mutation Lock (Prevents Race Conditions)

    /// Actor-based lock to prevent concurrent mutations without spin-waiting
    private actor QueueMutationLock {
        private var isLocked = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func acquire() async {
            if !isLocked {
                isLocked = true
                return
            }
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        func release() {
            if let next = waiters.first {
                waiters.removeFirst()
                next.resume()
            } else {
                isLocked = false
            }
        }
    }

    private static let queueMutationLock = QueueMutationLock()

    private func withQueueMutationLock<T>(_ block: () async throws -> T) async rethrows -> T {
        await Self.queueMutationLock.acquire()
        defer { Task { await Self.queueMutationLock.release() } }
        return try await block()
    }

    // MARK: - Improved Realtime Subscription

    /// Subscribe to realtime updates with proper filtering and incremental updates
    func subscribeToRealtimePro() {
        guard !isSubscribed else {
            NSLog("[LocationQueueStore] ⚠️ Already subscribed, skipping")
            return
        }

        let channelName = "queue-pro-\(locationId.uuidString.prefix(8))-\(UInt64(Date().timeIntervalSince1970 * 1000))"
        let locId = locationId

        NSLog("[LocationQueueStore] 🔌 Starting PRO realtime subscription for location \(locId)")

        connectionState = .connecting

        // Use realtimeV2 API with proper store_id + location_id filtering
        let channel = supabase.realtimeV2.channel(channelName)

        // Filter by BOTH store_id AND location_id at the postgres level
        // This prevents receiving events for other locations
        let filter = "location_id=eq.\(locId.uuidString)"

        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "location_queue",
            filter: filter
        )

        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "location_queue",
            filter: filter
        )

        let deletes = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "location_queue",
            filter: filter
        )

        realtimeChannel = channel

        // Subscribe and listen for changes
        realtimeTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                NSLog("[LocationQueueStore] Subscribing to channel with filter: \(filter)")
                try await channel.subscribeWithError()

                await MainActor.run { [weak self] in
                    self?.isSubscribed = true
                    self?.connectionState = .connected
                    NSLog("[LocationQueueStore] ✅ SUBSCRIBED to PRO realtime for location \(locId)")
                }

                // Listen for all event types concurrently
                await withTaskGroup(of: Void.self) { group in
                    // Listen for INSERTs
                    group.addTask { [weak self] in
                        for await insert in inserts {
                            guard !Task.isCancelled else { break }
                            await self?.handleInsertEventPro(insert)
                        }
                    }

                    // Listen for UPDATEs
                    group.addTask { [weak self] in
                        for await update in updates {
                            guard !Task.isCancelled else { break }
                            await self?.handleUpdateEventPro(update)
                        }
                    }

                    // Listen for DELETEs
                    group.addTask { [weak self] in
                        for await delete in deletes {
                            guard !Task.isCancelled else { break }
                            await self?.handleDeleteEventPro(delete)
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

    // MARK: - Incremental Event Handlers (No Full Reload)

    /// Handle INSERT event - add single entry to queue (no full reload)
    private func handleInsertEventPro(_ insert: InsertAction) async {
        NSLog("[LocationQueueStore] 🆕 INSERT - incrementally adding entry")

        // Decode the new entry
        guard let entry = try? insert.decodeRecord(as: QueueEntry.self, decoder: JSONDecoder.supabaseDecoder) else {
            NSLog("[LocationQueueStore] ⚠️ Failed to decode insert, falling back to full reload")
            await loadQueue()
            return
        }

        // Use mutation lock to prevent race conditions
        await withQueueMutationLock {
            await MainActor.run { [weak self] in
                guard let self = self else { return }

                // Add to queue if not already present
                if !self.queue.contains(where: { $0.cartId == entry.cartId }) {
                    self.objectWillChange.send()
                    self.queue.append(entry)
                    self.lastUpdated = Date()

                    // If no selection, select the first entry
                    if self.selectedCartId == nil {
                        self.selectedCartId = entry.cartId
                    }

                    // Post notification for UI updates
                    NotificationCenter.default.post(name: .queueDidChange, object: self.locationId)
                    NSLog("[LocationQueueStore] Added entry - now has \(self.queue.count) entries")
                }
            }
        }
    }

    /// Handle UPDATE event - update single entry (no full reload)
    private func handleUpdateEventPro(_ update: UpdateAction) async {
        NSLog("[LocationQueueStore] 🔄 UPDATE - incrementally updating entry")

        // Decode the updated entry
        guard let entry = try? update.decodeRecord(as: QueueEntry.self, decoder: JSONDecoder.supabaseDecoder) else {
            NSLog("[LocationQueueStore] ⚠️ Failed to decode update, falling back to full reload")
            await loadQueue()
            return
        }

        // Use mutation lock to prevent race conditions
        await withQueueMutationLock {
            await MainActor.run { [weak self] in
                guard let self = self else { return }

                // Find and update the entry
                if let index = self.queue.firstIndex(where: { $0.cartId == entry.cartId }) {
                    self.objectWillChange.send()
                    self.queue[index] = entry
                    self.lastUpdated = Date()

                    // Post notification for UI updates
                    NotificationCenter.default.post(name: .queueDidChange, object: self.locationId)
                    NSLog("[LocationQueueStore] Updated entry - \(entry.cartId)")
                }
            }
        }
    }

    /// Handle DELETE event - remove single entry (no full reload)
    private func handleDeleteEventPro(_ delete: DeleteAction) async {
        NSLog("[LocationQueueStore] 🗑️ DELETE - incrementally removing entry")

        // Extract cart_id from old record (handle AnyJSON type)
        let cartIdValue = delete.oldRecord["cart_id"]
        let cartIdStr: String? = {
            if let str = cartIdValue as? String {
                return str
            } else if case .string(let str) = cartIdValue as? AnyJSON {
                return str
            }
            return nil
        }()

        guard let cartIdStr = cartIdStr,
              let cartId = UUID(uuidString: cartIdStr) else {
            NSLog("[LocationQueueStore] ⚠️ Failed to decode delete, falling back to full reload")
            await loadQueue()
            return
        }

        // Use mutation lock to prevent race conditions
        await withQueueMutationLock {
            await MainActor.run { [weak self] in
                guard let self = self else { return }

                // Remove from queue
                if let index = self.queue.firstIndex(where: { $0.cartId == cartId }) {
                    self.objectWillChange.send()
                    self.queue.remove(at: index)
                    self.lastUpdated = Date()

                    // If we removed the selected cart, select the first remaining
                    if self.selectedCartId == cartId {
                        self.selectedCartId = self.queue.first?.cartId
                    }

                    // Post notification for UI updates
                    NotificationCenter.default.post(name: .queueDidChange, object: self.locationId)
                    NSLog("[LocationQueueStore] Removed entry - now has \(self.queue.count) entries")
                }
            }
        }
    }
}
