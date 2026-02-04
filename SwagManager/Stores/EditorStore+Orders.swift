import Foundation

// MARK: - EditorStore Orders & Locations
// Extracted following Apple engineering standards

// MARK: - Cached Order Counts
// Lightweight struct to avoid recalculating filters on every access
struct OrderCountsCache {
    let pending: Int
    let processing: Int
    let ready: Int
    let shipped: Int
    let completed: Int
    let cancelled: Int
    let total: Int

    init(orders: [Order]) {
        var p = 0, pr = 0, r = 0, s = 0, c = 0, ca = 0
        for order in orders {
            switch order.status {
            case "pending": p += 1
            case "confirmed", "preparing", "packing", "packed": pr += 1
            case "ready", "ready_to_ship": r += 1
            case "shipped", "in_transit", "out_for_delivery": s += 1
            case "delivered", "completed": c += 1
            case "cancelled": ca += 1
            default: break
            }
        }
        self.pending = p
        self.processing = pr
        self.ready = r
        self.shipped = s
        self.completed = c
        self.cancelled = ca
        self.total = orders.count
    }
}

extension EditorStore {
    // MARK: - Cached Order Counts (invalidated when orders change)

    private static var _orderCountsCache: OrderCountsCache?
    private static var _orderCountsCacheId: Int = 0

    /// Get cached order counts - only recalculates when orders array changes
    var orderCounts: OrderCountsCache {
        let currentId = orders.count  // Simple cache key based on count
        if EditorStore._orderCountsCache == nil || EditorStore._orderCountsCacheId != currentId {
            EditorStore._orderCountsCache = OrderCountsCache(orders: orders)
            EditorStore._orderCountsCacheId = currentId
        }
        return EditorStore._orderCountsCache!
    }

    /// Call this when orders array is modified to invalidate cache
    func invalidateOrderCache() {
        EditorStore._orderCountsCache = nil
    }

    // MARK: - Orders

    func loadOrders() async {
        guard let store = selectedStore else {
            return
        }

        await MainActor.run { isLoadingOrders = true }

        do {
            let fetchedOrders = try await supabase.fetchOrders(storeId: store.id)
            await MainActor.run {
                orders = fetchedOrders
                isLoadingOrders = false
            }

            // Gate realtime subscription until UI is idle (reduces input system churn)
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            // Start realtime subscription
            await subscribeToOrders()
        } catch {
            await MainActor.run {
                self.error = "Failed to load orders: \(error.localizedDescription)"
                isLoadingOrders = false
            }
        }
    }

    func loadOrdersByStatus(_ status: String) async {
        guard let store = selectedStore else { return }

        do {
            orders = try await supabase.fetchOrdersByStatus(storeId: store.id, status: status)
        } catch {
            self.error = "Failed to load orders: \(error.localizedDescription)"
        }
    }

    func openOrder(_ order: Order) {
        selectedOrder = order
        selectedCreation = nil
        selectedProduct = nil
        selectedConversation = nil
        selectedBrowserSession = nil
        selectedLocation = nil
        editedCode = nil
        openTab(.order(order))
    }

    func refreshOrder(_ order: Order) async {
        do {
            let updated = try await supabase.fetchOrder(id: order.id)
            // Update in array
            if let index = orders.firstIndex(where: { $0.id == order.id }) {
                orders[index] = updated
            }
            // Update selected if this is the selected one
            if selectedOrder?.id == order.id {
                selectedOrder = updated
            }
            // Update in open tabs
            if let tabIndex = openTabs.firstIndex(where: {
                if case .order(let o) = $0, o.id == order.id { return true }
                return false
            }) {
                openTabs[tabIndex] = .order(updated)
            }
            if case .order(let o) = activeTab, o.id == order.id {
                activeTab = .order(updated)
            }
        } catch {
        }
    }

    func updateOrderStatus(_ order: Order, toStatus: String, note: String? = nil) async {
        do {
            try await supabase.updateOrderStatusWithHistory(
                id: order.id,
                fromStatus: order.status,
                toStatus: toStatus,
                note: note
            )
            await refreshOrder(order)
        } catch {
            self.error = "Failed to update status: \(error.localizedDescription)"
        }
    }

    // MARK: - Order Filtering

    var pendingOrders: [Order] {
        orders.filter { $0.status == "pending" }
    }

    var processingOrders: [Order] {
        orders.filter { ["confirmed", "preparing", "packing", "packed"].contains($0.status) }
    }

    var readyOrders: [Order] {
        orders.filter { ["ready", "ready_to_ship"].contains($0.status) }
    }

    var shippedOrders: [Order] {
        orders.filter { ["shipped", "in_transit", "out_for_delivery"].contains($0.status) }
    }

    var completedOrders: [Order] {
        orders.filter { ["delivered", "completed"].contains($0.status) }
    }

    var cancelledOrders: [Order] {
        orders.filter { $0.status == "cancelled" }
    }

    func ordersForLocation(_ locationId: UUID) -> [Order] {
        // Check both locationId and fulfillment delivery location
        orders.filter { $0.locationId == locationId || $0.deliveryLocationId == locationId }
    }

    // MARK: - Locations

    func loadLocations() async {
        guard let store = selectedStore else {
            return
        }

        await MainActor.run { isLoadingLocations = true }

        do {
            let fetchedLocations = try await supabase.fetchLocations(storeId: store.id)
            await MainActor.run {
                locations = fetchedLocations
                isLoadingLocations = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load locations: \(error.localizedDescription)"
                isLoadingLocations = false
            }
        }
    }

    func openLocation(_ location: Location) {
        selectedLocation = location
        selectedCreation = nil
        selectedProduct = nil
        selectedConversation = nil
        selectedBrowserSession = nil
        selectedOrder = nil
        editedCode = nil
        openTab(.location(location))
    }
}
