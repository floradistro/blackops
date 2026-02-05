import SwiftUI
import Combine

// MARK: - OrderStore
// Domain-specific store for orders
// Isolated from other domains to prevent observation cascade

@MainActor
@Observable
final class OrderStore {
    // MARK: - State

    private(set) var orders: [Order] = []
    private(set) var locations: [Location] = []

    var selectedOrder: Order?
    var selectedLocation: Location?

    private(set) var isLoading = false
    private(set) var error: String?

    // MARK: - Private

    @ObservationIgnored private let supabase = SupabaseService.shared
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    // MARK: - Load Data

    func loadOrders(storeId: UUID) async {
        loadTask?.cancel()

        loadTask = Task {
            isLoading = true
            defer { isLoading = false }

            do {
                // Fetch in parallel
                async let fetchedOrders = supabase.fetchOrders(storeId: storeId)
                async let fetchedLocations = supabase.fetchLocations(storeId: storeId)

                let (orders, locations) = try await (fetchedOrders, fetchedLocations)

                guard !Task.isCancelled else { return }

                self.orders = orders
                self.locations = locations

            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
        }

        await loadTask?.value
    }

    // MARK: - Filtering

    func ordersForLocation(_ locationId: UUID) -> [Order] {
        orders.filter { $0.locationId == locationId }
    }

    func ordersWithStatus(_ status: String) -> [Order] {
        orders.filter { $0.status == status }
    }

    // MARK: - Selection

    func selectOrder(_ order: Order) {
        selectedOrder = order
        selectedLocation = nil
    }

    // MARK: - Clear

    func clear() {
        loadTask?.cancel()
        orders = []
        locations = []
        selectedOrder = nil
        selectedLocation = nil
        error = nil
    }
}

// MARK: - Environment Key

private struct OrderStoreKey: EnvironmentKey {
    static let defaultValue: OrderStore? = nil
}

extension EnvironmentValues {
    var orderStore: OrderStore? {
        get { self[OrderStoreKey.self] }
        set { self[OrderStoreKey.self] = newValue }
    }
}
