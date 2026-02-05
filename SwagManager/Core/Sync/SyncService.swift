import Foundation
import SwiftData
import Supabase

// MARK: - Sync Service
// Single service that syncs Supabase → SwiftData
// Views read from SwiftData (instant), sync happens in background

@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()

    private let supabase = SupabaseService.shared
    private var modelContext: ModelContext?
    private var storeId: UUID?

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncTime: Date?

    // Throttle sync requests
    private var syncTask: Task<Void, Never>?

    // MARK: - Configure

    func configure(modelContext: ModelContext, storeId: UUID) {
        self.modelContext = modelContext
        self.storeId = storeId
    }

    // MARK: - Full Sync (Throttled)

    func syncAll() async {
        // Cancel any pending sync
        syncTask?.cancel()

        guard !isSyncing else { return }
        isSyncing = true

        syncTask = Task {
            defer {
                Task { @MainActor in
                    self.isSyncing = false
                    self.lastSyncTime = Date()
                }
            }

            // Run syncs in parallel, but each sync processes data in batches
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.syncLocations() }
                group.addTask { await self.syncOrders() }
                group.addTask { await self.syncCustomers() }
            }
        }

        await syncTask?.value
    }

    // MARK: - Sync Locations

    func syncLocations() async {
        guard let context = modelContext, let storeId = storeId else { return }

        do {
            let remote = try await supabase.fetchLocations(storeId: storeId)

            for location in remote {
                // Find existing or create new
                let descriptor = FetchDescriptor<SDLocation>(
                    predicate: #Predicate { $0.id == location.id }
                )
                let existing = try? context.fetch(descriptor).first

                if let existing = existing {
                    // Update
                    existing.name = location.name
                    existing.address = location.address
                    existing.city = location.city
                    existing.state = location.state
                    existing.isActive = location.isActive ?? true
                } else {
                    // Insert
                    let new = SDLocation(
                        id: location.id,
                        storeId: storeId,
                        name: location.name,
                        address: location.address,
                        city: location.city,
                        state: location.state,
                        isActive: location.isActive ?? true,
                        createdAt: location.createdAt ?? Date()
                    )
                    context.insert(new)
                }
            }

            try context.save()
        } catch {
        }
    }

    // MARK: - Sync Orders

    func syncOrders() async {
        guard let context = modelContext, let storeId = storeId else { return }

        do {
            // Only sync active orders + recent completed (last 30 days)
            let activeOrders = try await supabase.fetchActiveOrders(storeId: storeId)

            for order in activeOrders {
                let descriptor = FetchDescriptor<SDOrder>(
                    predicate: #Predicate { $0.id == order.id }
                )
                let existing = try? context.fetch(descriptor).first

                if let existing = existing {
                    // Update
                    existing.status = order.status ?? "unknown"
                    existing.paymentStatus = order.paymentStatus
                    existing.totalAmount = order.totalAmount
                    existing.shippingName = order.shippingName
                    existing.updatedAt = order.updatedAt ?? Date()
                } else {
                    // Insert
                    let new = SDOrder(
                        id: order.id,
                        orderNumber: order.orderNumber,
                        status: order.status ?? "unknown",
                        paymentStatus: order.paymentStatus,
                        channel: order.channel.rawValue,
                        subtotal: order.subtotal,
                        totalAmount: order.totalAmount,
                        currency: order.currency ?? "USD",
                        customerNote: order.customerNote,
                        shippingName: order.shippingName,
                        shippingCity: order.shippingCity,
                        createdAt: order.createdAt ?? Date(),
                        updatedAt: order.updatedAt ?? Date()
                    )

                    // Link to location if exists
                    if let locationId = order.locationId {
                        let locDescriptor = FetchDescriptor<SDLocation>(
                            predicate: #Predicate { $0.id == locationId }
                        )
                        new.location = try? context.fetch(locDescriptor).first
                    }

                    context.insert(new)
                }
            }

            try context.save()
        } catch {
        }
    }

    // MARK: - Sync Customers

    func syncCustomers() async {
        guard let context = modelContext, let storeId = storeId else { return }

        do {
            let remote = try await supabase.fetchCustomers(storeId: storeId, limit: 500)

            for customer in remote {
                let descriptor = FetchDescriptor<SDCustomer>(
                    predicate: #Predicate { $0.id == customer.id }
                )
                let existing = try? context.fetch(descriptor).first

                if let existing = existing {
                    // Update
                    existing.email = customer.email
                    existing.phone = customer.phone
                    existing.firstName = customer.firstName
                    existing.lastName = customer.lastName
                    existing.loyaltyPoints = customer.loyaltyPoints ?? 0
                    existing.totalSpent = customer.totalSpent ?? 0
                } else {
                    // Insert - construct fullName from parts
                    let fullName = [customer.firstName, customer.lastName]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")

                    let new = SDCustomer(
                        id: customer.id,
                        storeId: storeId,
                        email: customer.email,
                        phone: customer.phone,
                        firstName: customer.firstName,
                        lastName: customer.lastName,
                        fullName: fullName.isEmpty ? nil : fullName,
                        loyaltyPoints: customer.loyaltyPoints ?? 0,
                        totalSpent: customer.totalSpent ?? 0,
                        orderCount: 0,  // Will be computed from relationship
                        createdAt: customer.createdAt ?? Date()
                    )
                    context.insert(new)
                }
            }

            try context.save()
        } catch {
        }
    }

    // MARK: - Incremental Sync (for realtime updates)

    func syncOrder(id: UUID) async {
        guard let context = modelContext else { return }

        do {
            let order = try await supabase.fetchOrder(id: id)

            let descriptor = FetchDescriptor<SDOrder>(
                predicate: #Predicate { $0.id == id }
            )
            let existing = try? context.fetch(descriptor).first

            if let existing = existing {
                existing.status = order.status ?? "unknown"
                existing.paymentStatus = order.paymentStatus
                existing.totalAmount = order.totalAmount
                existing.updatedAt = Date()
            }

            try context.save()
        } catch {
        }
    }
}
