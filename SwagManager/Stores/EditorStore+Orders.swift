import Foundation

// MARK: - EditorStore Orders & Locations
// Extracted following Apple engineering standards

extension EditorStore {
    // MARK: - Orders

    func loadOrders() async {
        guard let store = selectedStore else {
            NSLog("[EditorStore] No store selected, cannot load orders")
            return
        }

        do {
            NSLog("[EditorStore] Loading orders for store: \(store.id)")
            orders = try await supabase.fetchOrders(storeId: store.id)
            NSLog("[EditorStore] Loaded \(orders.count) orders")
        } catch {
            NSLog("[EditorStore] Failed to load orders: \(error)")
            self.error = "Failed to load orders: \(error.localizedDescription)"
        }
    }

    func loadOrdersByStatus(_ status: String) async {
        guard let store = selectedStore else { return }

        do {
            orders = try await supabase.fetchOrdersByStatus(storeId: store.id, status: status)
        } catch {
            NSLog("[EditorStore] Failed to load orders by status: \(error)")
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
            NSLog("[EditorStore] Failed to refresh order: \(error)")
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
            NSLog("[EditorStore] Failed to update order status: \(error)")
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
        orders.filter { $0.locationId == locationId || $0.pickupLocationId == locationId }
    }

    // MARK: - Locations

    func loadLocations() async {
        guard let store = selectedStore else {
            NSLog("[EditorStore] No store selected, cannot load locations")
            return
        }

        do {
            NSLog("[EditorStore] Loading locations for store: \(store.id)")
            locations = try await supabase.fetchLocations(storeId: store.id)
            NSLog("[EditorStore] Loaded \(locations.count) locations")
        } catch {
            NSLog("[EditorStore] Failed to load locations: \(error)")
            self.error = "Failed to load locations: \(error.localizedDescription)"
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
