//
//  RealtimeEventBus.swift
//  Whale
//
//  Created: 2026-01-22
//  Purpose: Centralized, typed realtime event system for Supabase
//
//  IMPORTANT: This works with CURRENT schema (location_queue, carts, cart_items)
//  When migration happens, just update table names (see comments marked MIGRATION)
//

import Foundation
import Supabase
import Combine

// MARK: - Typed Events

/// All realtime events from the database
/// These are TYPE-SAFE - no more unsafe casting!
enum RealtimeEvent: Equatable {

    // MARK: Queue Events

    /// Queue was updated (generic - use when you don't know specific change)
    case queueUpdated(locationId: UUID)

    /// Customer was added to queue
    case queueCustomerAdded(locationId: UUID, customerId: UUID)

    /// Customer was removed from queue
    case queueCustomerRemoved(locationId: UUID, customerId: UUID)

    // MARK: Cart Events

    /// Cart was updated (totals, status, etc.)
    case cartUpdated(cartId: UUID)

    /// Item was added to cart
    case cartItemAdded(cartId: UUID, itemId: UUID)

    /// Item was removed from cart
    case cartItemRemoved(cartId: UUID, itemId: UUID)

    /// Item quantity changed
    case cartItemQuantityChanged(cartId: UUID, itemId: UUID, newQuantity: Int)

    // MARK: Order Events (Future)

    /// Order was created
    case orderCreated(orderId: UUID)

    /// Order status changed
    case orderStatusChanged(orderId: UUID, newStatus: String)

    // MARK: Inventory Events

    /// Inventory was updated (stock levels changed)
    case inventoryUpdated(locationId: UUID)
}

// MARK: - Event Bus

@MainActor
final class RealtimeEventBus: ObservableObject {

    // MARK: Singleton

    static let shared = RealtimeEventBus()

    // MARK: - Published State

    @Published private(set) var connectionState: ConnectionState = .disconnected

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected(locationIds: Set<UUID>)
        case error(String)

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
    }

    // MARK: - Private State

    // nonisolated(unsafe) allows capturing in concurrent code for Swift 6
    // Safe because we only call send() on MainActor
    nonisolated(unsafe) private let eventSubject = PassthroughSubject<RealtimeEvent, Never>()
    private var activeChannels: [UUID: ChannelState] = [:]
    private var reconnectTasks: [UUID: Task<Void, Never>] = [:]

    private struct ChannelState {
        let channel: RealtimeChannelV2
        let task: Task<Void, Never>
        var reconnectAttempts: Int = 0
    }

    // MARK: - Initialization

    private init() {
    }

    // MARK: - Public API

    /// Connect to realtime events for a location
    /// Call this ONCE per location (not per view!)
    ///
    /// Example:
    /// ```
    /// Task {
    ///     await RealtimeEventBus.shared.connect(to: locationId)
    /// }
    /// ```
    func connect(to locationId: UUID) async {
        // Already connected?
        guard activeChannels[locationId] == nil else {
            return
        }

        // Cancel any pending reconnect
        reconnectTasks[locationId]?.cancel()
        reconnectTasks[locationId] = nil

        updateConnectionState()

        do {
            let channelState = try await createChannel(for: locationId)
            activeChannels[locationId] = channelState
            updateConnectionState()

        } catch {
            let errorMsg = error.localizedDescription
            // Defer state change to avoid layout recursion
            DispatchQueue.main.async { self.connectionState = .error(errorMsg) }

            // Schedule retry with exponential backoff
            scheduleReconnect(to: locationId)
        }
    }

    /// Disconnect from a location
    /// Call this when location is no longer needed
    func disconnect(from locationId: UUID) async {
        reconnectTasks[locationId]?.cancel()
        reconnectTasks[locationId] = nil

        if let state = activeChannels[locationId] {
            state.task.cancel()
            let supabase = SupabaseService.shared.client
            await state.channel.unsubscribe()
            await supabase.removeChannel(state.channel)
            activeChannels[locationId] = nil
        }

        updateConnectionState()
    }

    /// Get all events (unfiltered)
    func events() -> AnyPublisher<RealtimeEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    /// Get queue events for a specific location
    ///
    /// Example:
    /// ```
    /// RealtimeEventBus.shared.queueEvents(for: locationId)
    ///     .sink { event in
    ///         switch event {
    ///         case .queueUpdated:
    ///             await reloadQueue()
    ///         default:
    ///             break
    ///         }
    ///     }
    /// ```
    func queueEvents(for locationId: UUID) -> AnyPublisher<RealtimeEvent, Never> {
        eventSubject
            .filter { event in
                switch event {
                case .queueUpdated(let loc),
                     .queueCustomerAdded(let loc, _),
                     .queueCustomerRemoved(let loc, _):
                    return loc == locationId
                default:
                    return false
                }
            }
            .eraseToAnyPublisher()
    }

    /// Get cart events for a specific cart
    func cartEvents(for cartId: UUID) -> AnyPublisher<RealtimeEvent, Never> {
        eventSubject
            .filter { event in
                switch event {
                case .cartUpdated(let cart),
                     .cartItemAdded(let cart, _),
                     .cartItemRemoved(let cart, _),
                     .cartItemQuantityChanged(let cart, _, _):
                    return cart == cartId
                default:
                    return false
                }
            }
            .eraseToAnyPublisher()
    }

    /// Get inventory events for a specific location
    func inventoryEvents(for locationId: UUID) -> AnyPublisher<RealtimeEvent, Never> {
        eventSubject
            .filter { event in
                switch event {
                case .inventoryUpdated(let loc):
                    return loc == locationId
                default:
                    return false
                }
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Private Implementation

    private func createChannel(for locationId: UUID) async throws -> ChannelState {
        let supabase = SupabaseService.shared.client
        let channelName = "location-\(locationId.uuidString)"
        let channel = supabase.realtimeV2.channel(channelName)

        // Subscribe to location_queue changes for this location
        let queueChanges = channel.postgresChange(
            AnyAction.self,
            table: "location_queue",
            filter: .eq("location_id", value: locationId.uuidString)
        )

        // Subscribe to carts changes for this location
        let cartChanges = channel.postgresChange(
            AnyAction.self,
            table: "carts",
            filter: .eq("location_id", value: locationId.uuidString)
        )

        // Subscribe to cart_items changes (no filter - can't filter by location directly)
        let cartItemChanges = channel.postgresChange(
            AnyAction.self,
            table: "cart_items"
        )

        // Subscribe to inventory changes for this location
        let inventoryChanges = channel.postgresChange(
            AnyAction.self,
            table: "inventory",
            filter: .eq("location_id", value: locationId.uuidString)
        )

        try await channel.subscribeWithError()

        // Capture values to avoid capturing self in concurrent code
        let eventSubject = self.eventSubject
        let capturedLocationId = locationId

        // Listen to changes and broadcast events - subscribers refetch their own data
        let task = Task {
            await withTaskGroup(of: Void.self) { group in
                // Queue changes
                group.addTask {
                    for await _ in queueChanges {
                        await MainActor.run { eventSubject.send(.queueUpdated(locationId: capturedLocationId)) }
                    }
                }

                // Cart changes - broadcast location update so all carts at this location refetch
                group.addTask {
                    for await _ in cartChanges {
                        await MainActor.run { eventSubject.send(.queueUpdated(locationId: capturedLocationId)) }
                    }
                }

                // Cart item changes - same
                group.addTask {
                    for await _ in cartItemChanges {
                        await MainActor.run { eventSubject.send(.queueUpdated(locationId: capturedLocationId)) }
                    }
                }

                // Inventory changes - notify product grids to refetch
                group.addTask {
                    for await _ in inventoryChanges {
                        await MainActor.run { eventSubject.send(.inventoryUpdated(locationId: capturedLocationId)) }
                    }
                }
            }
        }

        return ChannelState(channel: channel, task: task)
    }

    // MARK: - Reconnection Logic

    private func scheduleReconnect(to locationId: UUID) {
        let attempts = activeChannels[locationId]?.reconnectAttempts ?? 0
        let delay = min(pow(2.0, Double(attempts)), 32.0)  // Max 32 seconds


        let task = Task {
            try? await Task.sleep(for: .seconds(delay))

            guard !Task.isCancelled else { return }

            // Update reconnect attempts
            if var state = activeChannels[locationId] {
                state.reconnectAttempts += 1
                activeChannels[locationId] = state
            }

            await connect(to: locationId)
        }

        reconnectTasks[locationId] = task
    }

    private func updateConnectionState() {
        // Defer state changes to avoid layout recursion when called from view lifecycle
        let isEmpty = activeChannels.isEmpty
        let connectedIds = Set(activeChannels.keys)
        DispatchQueue.main.async {
            if isEmpty {
                self.connectionState = .disconnected
            } else {
                self.connectionState = .connected(locationIds: connectedIds)
            }
        }
    }

    // MARK: - Helper Methods for Parsing Supabase Changes

    /// Extract UUID from JSONObject (handles AnyJSON values)
    private func extractUUID(from jsonObject: JSONObject, key: String) -> UUID? {
        guard let value = jsonObject[key] else { return nil }

        // AnyJSON wraps values - try to extract string representation
        let stringValue: String?
        if case .string(let s) = value {
            stringValue = s
        } else {
            // Fallback: convert to string
            stringValue = "\(value)"
        }

        if let str = stringValue {
            return UUID(uuidString: str)
        }
        return nil
    }

    /// Extract Int from JSONObject (handles AnyJSON values)
    private func extractInt(from jsonObject: JSONObject, key: String) -> Int? {
        guard let value = jsonObject[key] else { return nil }

        switch value {
        case .integer(let i):
            return i
        case .double(let d):
            return Int(d)
        case .string(let s):
            return Int(s)
        default:
            return nil
        }
    }

}
