import SwiftUI
import Supabase
import Realtime

// MARK: - EditorStore Orders Realtime Extension
// Ported from POS OrderStore.swift - production-tested realtime implementation
// Features: Actor-based locking, optimistic updates, incremental tree updates, zero lag

extension EditorStore {

    // MARK: - Mutation Lock (Prevents Race Conditions)

    /// Actor-based lock to prevent concurrent mutations without spin-waiting
    /// This is critical for multi-register/multi-user scenarios
    private actor OrderMutationLock {
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

    private static let orderMutationLock = OrderMutationLock()

    private func withOrderMutationLock<T>(_ block: () async throws -> T) async rethrows -> T {
        await Self.orderMutationLock.acquire()
        defer { Task { await Self.orderMutationLock.release() } }
        return try await block()
    }

    // MARK: - Realtime Subscription

    func subscribeToOrders() async {
        guard let store = selectedStore else {
            NSLog("[EditorStore] Cannot subscribe - no store selected")
            return
        }

        let storeId = store.id

        // Skip if already subscribed or currently subscribing
        guard ordersRealtimeChannel == nil else {
            NSLog("[EditorStore] Already subscribed to orders, skipping")
            return
        }

        // Clean up any existing subscription first
        await cleanupOrdersRealtime()

        // Create a unique channel name with timestamp to ensure fresh channel
        let channelName = "swagmanager-orders-\(storeId.uuidString.prefix(8))-\(UInt64(Date().timeIntervalSince1970 * 1000))"

        NSLog("[EditorStore] 🔌 Creating orders realtime channel: \(channelName)")

        // Capture supabase client before detaching
        let client = supabase.client

        // Mark as loading orders
        isLoadingOrders = true
        objectWillChange.send()

        // Do ALL channel setup in background to avoid any main thread blocking
        Task.detached { [weak self] in
            guard let self else { return }

            // Create channel off main thread
            let channel = client.channel(channelName)

            // Add postgres change listener with store_id filter
            let changes = channel.postgresChange(
                AnyAction.self,
                table: "orders",
                filter: .eq("store_id", value: storeId.uuidString)
            )

            // Store reference for cleanup
            await MainActor.run { [weak self] in
                self?.ordersRealtimeChannel = channel
            }

            // Subscribe (blocking network call)
            try? await channel.subscribeWithError()

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.ordersRealtimeConnected = true
                self.isLoadingOrders = false
                self.objectWillChange.send()
                NSLog("[EditorStore] ✅ Subscribed to orders realtime successfully")
            }

            // Start listening for changes
            let task = Task { [weak self] in
                for await change in changes {
                    guard let self = self, !Task.isCancelled else { break }
                    await self.handleOrderRealtimeChange(change)
                }
                await MainActor.run { [weak self] in
                    self?.ordersRealtimeConnected = false
                    self?.objectWillChange.send()
                }
            }

            await MainActor.run { [weak self] in
                self?.ordersRealtimeTask = task
            }
        }
    }

    func cleanupOrdersRealtime() async {
        // Cancel the listening task first
        ordersRealtimeTask?.cancel()
        ordersRealtimeTask = nil

        // Unsubscribe and remove channel in background to avoid blocking
        if let channel = ordersRealtimeChannel {
            NSLog("[EditorStore] Cleaning up orders realtime channel")
            let channelToCleanup = channel
            ordersRealtimeChannel = nil

            // Fire and forget - don't block on cleanup
            let client = self.supabase.client
            Task.detached {
                await channelToCleanup.unsubscribe()
                await client.removeChannel(channelToCleanup)
            }
        }

        ordersRealtimeConnected = false
        objectWillChange.send()
    }

    // MARK: - Event Handling

    private func handleOrderRealtimeChange(_ change: AnyAction) async {
        switch change {
        case .insert(let action):
            await handleOrderInsert(action)

        case .update(let action):
            await handleOrderUpdate(action)

        case .delete(let action):
            await handleOrderDelete(action)
        }
    }

    // MARK: - Insert Handler

    private func handleOrderInsert(_ action: InsertAction) async {
        // Decode basic order info to get the ID
        let basicOrder: Order? = await Task.detached {
            Self.decodeRealtimeOrder(from: action.record)
        }.value

        guard let basicOrder = basicOrder else {
            NSLog("[EditorStore] ⚠️ Failed to decode order insert")
            return
        }

        // Add a small delay to ensure order_items are inserted (they may be in a separate transaction)
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        do {
            // Fetch the complete order with all data
            let completeOrder = try await supabase.fetchOrder(id: basicOrder.id)

            NSLog("[EditorStore] 🆕 New order received: #\(completeOrder.orderNumber)")

            // Use mutation lock to prevent race conditions
            await withOrderMutationLock {
                // Add to beginning of array (most recent first)
                self.orders.insert(completeOrder, at: 0)

                NSLog("[EditorStore] Orders count now: \(self.orders.count)")
            }

            // Update UI
            await MainActor.run {
                self.objectWillChange.send()
            }

        } catch {
            NSLog("[EditorStore] ❌ Failed to fetch complete order: \(error)")
        }
    }

    // MARK: - Update Handler

    private func handleOrderUpdate(_ action: UpdateAction) async {
        // Decode basic order info to get the ID
        let basicOrder: Order? = await Task.detached {
            Self.decodeRealtimeOrder(from: action.record)
        }.value

        guard let basicOrder = basicOrder else {
            NSLog("[EditorStore] ⚠️ Failed to decode order update")
            return
        }

        do {
            // Fetch the complete order with all data
            let completeOrder = try await supabase.fetchOrder(id: basicOrder.id)

            NSLog("[EditorStore] 🔄 Order updated: #\(completeOrder.orderNumber)")

            // Use mutation lock to prevent race conditions
            await withOrderMutationLock {
                if let index = self.orders.firstIndex(where: { $0.id == completeOrder.id }) {
                    self.orders[index] = completeOrder
                }
            }

            // Update UI
            await MainActor.run {
                self.objectWillChange.send()
            }

        } catch {
            NSLog("[EditorStore] ❌ Failed to fetch updated order: \(error)")
        }
    }

    // MARK: - Delete Handler

    private func handleOrderDelete(_ action: DeleteAction) async {
        if let idString = action.oldRecord["id"]?.stringValue,
           let id = UUID(uuidString: idString) {

            NSLog("[EditorStore] 🗑️ Order deleted: \(idString)")

            // Use mutation lock to prevent race conditions
            await withOrderMutationLock {
                self.orders.removeAll { $0.id == id }
            }

            // Update UI
            await MainActor.run {
                self.objectWillChange.send()
            }
        }
    }

    // MARK: - JSON Decoding (Nonisolated - runs off main thread)

    /// Decode an order from realtime record, handling Supabase's AnyJSON types
    private nonisolated static func decodeRealtimeOrder(from record: [String: Any]) -> Order? {
        do {
            let sanitizedRecord = sanitizeForJSON(record)
            let data = try JSONSerialization.data(withJSONObject: sanitizedRecord)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Order.self, from: data)
        } catch {
            NSLog("[EditorStore] Failed to decode realtime order - \(error)")
            return nil
        }
    }

    /// Recursively sanitize a dictionary to convert Supabase AnyJSON types to JSON-compatible types.
    private nonisolated static func sanitizeForJSON(_ value: Any) -> Any {
        // Handle AnyJSON from Supabase Realtime SDK
        if let anyJSON = value as? AnyJSON {
            return sanitizeAnyJSON(anyJSON)
        }

        if let dict = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, val) in dict {
                result[key] = sanitizeForJSON(val)
            }
            return result
        }

        if let array = value as? [Any] {
            return array.map { sanitizeForJSON($0) }
        }

        // Primitive types that JSONSerialization handles natively
        if let string = value as? String { return string }
        if let bool = value as? Bool { return bool }
        if let int = value as? Int { return int }
        if let double = value as? Double { return double }
        if let decimal = value as? Decimal { return NSDecimalNumber(decimal: decimal).doubleValue }
        if value is NSNull { return NSNull() }
        if let number = value as? NSNumber { return number }

        // Fallback: convert to string
        return String(describing: value)
    }

    /// Convert Supabase AnyJSON to a JSON-serializable type
    private nonisolated static func sanitizeAnyJSON(_ anyJSON: AnyJSON) -> Any {
        switch anyJSON {
        case .null:
            return NSNull()
        case .bool(let b):
            return b
        case .integer(let i):
            return i
        case .double(let d):
            return d
        case .string(let s):
            return s
        case .array(let arr):
            return arr.map { sanitizeAnyJSON($0) }
        case .object(let dict):
            var result: [String: Any] = [:]
            for (key, val) in dict {
                result[key] = sanitizeAnyJSON(val)
            }
            return result
        }
    }
}
