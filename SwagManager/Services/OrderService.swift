// OrderService.swift
// Extracted following Apple engineering standards

import Foundation
import Supabase

@MainActor
public final class OrderService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Column Definitions
    // Updated for Oracle+Apple schema: channel replaces order_type, fulfillments table replaces delivery_type/pickup_location_id

    private let orderSelectColumns = """
        id, order_number, customer_id, headless_customer_id, store_id, location_id, status,
        payment_status, fulfillment_status, channel,
        subtotal, tax_amount, shipping_amount, discount_amount, total_amount,
        currency, customer_note, staff_notes, payment_method, payment_method_title,
        shipping_name, shipping_city, shipping_state,
        tracking_number, tracking_url, order_date, paid_date, completed_at, created_at, updated_at,
        created_by_user_id, prepared_by_user_id, shipped_by_user_id, delivered_by_user_id,
        employee_id, updated_by_user_id, prepared_at, shipped_at, delivered_at,
        fulfillments(
            id, order_id, type, status,
            delivery_location_id, delivery_address,
            carrier, tracking_number, tracking_url, shipping_cost,
            created_at, shipped_at, delivered_at
        )
    """

    // MARK: - Fetch Orders

    func fetchOrders(storeId: UUID, status: String? = nil) async throws -> [Order] {
        // Direct table query (works with authenticated users via RLS)
        // Paginate to get ALL orders (Supabase hard limit is 1000 per query)
        var allOrders: [Order] = []
        let batchSize = 1000
        var offset = 0

        while true {
            var query = client.from("orders")
                .select(orderSelectColumns)
                .eq("store_id", value: storeId)

            if let status = status {
                query = query.eq("status", value: status)
            }

            let batch: [Order] = try await query
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + batchSize - 1)
                .execute()
                .value

            allOrders.append(contentsOf: batch)

            if batch.count < batchSize {
                break // No more orders
            }
            offset += batchSize
        }
        return allOrders
    }

    func fetchOrder(id: UUID) async throws -> Order {
        return try await client.from("orders")
            .select(orderSelectColumns)
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func fetchOrdersByLocation(locationId: UUID) async throws -> [Order] {
        // Paginate to get ALL orders for location (Supabase hard limit is 1000 per query)
        var allOrders: [Order] = []
        let batchSize = 1000
        var offset = 0

        while true {
            let batch: [Order] = try await client.from("orders")
                .select(orderSelectColumns)
                .eq("location_id", value: locationId)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + batchSize - 1)
                .execute()
                .value

            allOrders.append(contentsOf: batch)

            if batch.count < batchSize {
                break // No more orders
            }
            offset += batchSize
        }

        return allOrders
    }

    func fetchOrdersByStatus(storeId: UUID, status: String) async throws -> [Order] {
        // Paginate to get ALL orders by status (Supabase hard limit is 1000 per query)
        var allOrders: [Order] = []
        let batchSize = 1000
        var offset = 0

        while true {
            let batch: [Order] = try await client.from("orders")
                .select(orderSelectColumns)
                .eq("store_id", value: storeId)
                .eq("status", value: status)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + batchSize - 1)
                .execute()
                .value

            allOrders.append(contentsOf: batch)

            if batch.count < batchSize {
                break // No more orders
            }
            offset += batchSize
        }

        return allOrders
    }

    func fetchRecentOrders(storeId: UUID, limit: Int = 20) async throws -> [Order] {
        return try await client.from("orders")
            .select(orderSelectColumns)
            .eq("store_id", value: storeId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    // Note: fetchRecentOrders keeps a limit parameter for performance on dashboards/widgets

    // MARK: - Update Order

    func updateOrderStatus(id: UUID, status: String) async throws {
        struct UpdateData: Encodable {
            let status: String
            let updated_at: String
        }

        let updateData = UpdateData(
            status: status,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await client.from("orders")
            .update(updateData)
            .eq("id", value: id)
            .execute()
    }

    func updateOrderFulfillmentStatus(id: UUID, fulfillmentStatus: String) async throws {
        struct UpdateData: Encodable {
            let fulfillment_status: String
            let updated_at: String
        }

        let updateData = UpdateData(
            fulfillment_status: fulfillmentStatus,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await client.from("orders")
            .update(updateData)
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Order Counts

    func fetchOrderCounts(storeId: UUID) async throws -> [String: Int] {
        // Fetch orders and count by status locally
        let orders: [Order] = try await client.from("orders")
            .select("id, status")
            .eq("store_id", value: storeId)
            .execute()
            .value

        var counts: [String: Int] = [:]
        for order in orders {
            let status = order.status ?? "unknown"
            counts[status, default: 0] += 1
        }
        return counts
    }

    // MARK: - Order Items

    func fetchOrderItems(orderId: UUID) async throws -> [OrderItem] {
        let items: [OrderItem] = try await client.from("order_items")
            .select("""
                id, order_id, product_id, product_name, product_sku, product_image, product_type,
                unit_price, quantity, line_subtotal, line_total, tax_amount,
                tier_name, tier_qty, tier_price, quantity_display,
                fulfillment_status, fulfilled_quantity,
                cost_per_unit, profit_per_unit, margin_percentage, created_at
            """)
            .eq("order_id", value: orderId)
            .order("created_at", ascending: true)
            .execute()
            .value
        return items
    }

    // MARK: - Order Status History

    func fetchOrderStatusHistory(orderId: UUID) async throws -> [OrderStatusHistory] {
        return try await client.from("order_status_history")
            .select("id, order_id, from_status, to_status, note, changed_by, customer_notified, created_at")
            .eq("order_id", value: orderId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func addStatusHistory(orderId: UUID, fromStatus: String?, toStatus: String, note: String?) async throws {
        struct InsertData: Encodable {
            let order_id: String
            let from_status: String?
            let to_status: String
            let note: String?
            let created_at: String
        }

        let insertData = InsertData(
            order_id: orderId.uuidString,
            from_status: fromStatus,
            to_status: toStatus,
            note: note,
            created_at: ISO8601DateFormatter().string(from: Date())
        )

        try await client.from("order_status_history")
            .insert(insertData)
            .execute()
    }

    // MARK: - Customer Info

    func fetchOrderCustomer(customerId: UUID) async throws -> OrderCustomer? {
        // customer_id in orders refers to user_creation_relationships.id
        // We need to join through to platform_users
        struct CustomerRelationship: Codable {
            let userId: UUID

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
            }
        }

        // First get the user_id from user_creation_relationships
        let relationships: [CustomerRelationship] = try await client.from("user_creation_relationships")
            .select("user_id")
            .eq("id", value: customerId)
            .limit(1)
            .execute()
            .value

        guard let relationship = relationships.first else {
            return nil
        }

        // Then fetch the platform_user
        let customers: [OrderCustomer] = try await client.from("platform_users")
            .select("id, email, phone, display_name, first_name, last_name")
            .eq("id", value: relationship.userId)
            .limit(1)
            .execute()
            .value

        return customers.first
    }

    // MARK: - Headless Customer Info

    func fetchHeadlessCustomer(customerId: UUID) async throws -> HeadlessCustomer? {
        let customers: [HeadlessCustomer] = try await client.from("headless_customers")
            .select("""
                id, store_id, email, phone, first_name, last_name, full_name,
                date_of_birth, id_number, id_type, id_expiration_date,
                address, city, state, zip_code, loyalty_points, total_spent,
                order_count, last_order_date, notes, tags, created_at, updated_at
            """)
            .eq("id", value: customerId)
            .limit(1)
            .execute()
            .value

        return customers.first
    }

    // MARK: - Staff Member Info

    func fetchStaffMember(userId: UUID) async throws -> StaffMember? {
        // Staff members are in the users table
        let staff: [StaffMember] = try await client.from("users")
            .select("id, email, phone, first_name, last_name, display_name, role, employee_id, avatar_url")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value

        return staff.first
    }

    func fetchStaffMembers(userIds: [UUID]) async throws -> [UUID: StaffMember] {
        guard !userIds.isEmpty else { return [:] }

        // Fetch all staff in one query
        let staff: [StaffMember] = try await client.from("users")
            .select("id, email, phone, first_name, last_name, display_name, role, employee_id, avatar_url")
            .in("id", values: userIds.map { $0.uuidString })
            .execute()
            .value

        var result: [UUID: StaffMember] = [:]
        for member in staff {
            result[member.id] = member
        }
        return result
    }

    // MARK: - Order With Full Details

    func fetchOrderWithDetails(orderId: UUID, locationId: UUID?) async throws -> OrderWithDetails {
        // Fetch order
        let order = try await fetchOrder(id: orderId)

        // Fetch items
        let items = try await fetchOrderItems(orderId: orderId)

        // Fetch status history
        let history = try await fetchOrderStatusHistory(orderId: orderId)

        // Fetch customer if exists (regular or headless)
        var customer: OrderCustomer? = nil
        var headlessCustomer: HeadlessCustomer? = nil

        if let customerId = order.customerId {
            customer = try? await fetchOrderCustomer(customerId: customerId)
        }

        if let headlessId = order.headlessCustomerId {
            headlessCustomer = try? await fetchHeadlessCustomer(customerId: headlessId)
        }

        // Fetch location if exists
        var location: Location? = nil
        if let locId = locationId ?? order.locationId {
            let locations: [Location] = try await client.from("locations")
                .select("*")
                .eq("id", value: locId)
                .limit(1)
                .execute()
                .value
            location = locations.first
        }

        // Collect all staff user IDs
        var staffIds: [UUID] = []
        if let id = order.createdByUserId { staffIds.append(id) }
        if let id = order.preparedByUserId { staffIds.append(id) }
        if let id = order.shippedByUserId { staffIds.append(id) }
        if let id = order.deliveredByUserId { staffIds.append(id) }
        if let id = order.employeeId { staffIds.append(id) }
        if let id = order.updatedByUserId { staffIds.append(id) }

        // Fetch all staff members in one query
        let staffMap = try await fetchStaffMembers(userIds: Array(Set(staffIds)))

        // Build staff info
        let staffInfo = OrderStaffInfo(
            createdBy: order.createdByUserId.flatMap { staffMap[$0] },
            preparedBy: order.preparedByUserId.flatMap { staffMap[$0] },
            shippedBy: order.shippedByUserId.flatMap { staffMap[$0] },
            deliveredBy: order.deliveredByUserId.flatMap { staffMap[$0] },
            employee: order.employeeId.flatMap { staffMap[$0] },
            updatedBy: order.updatedByUserId.flatMap { staffMap[$0] }
        )

        return OrderWithDetails(
            order: order,
            items: items,
            statusHistory: history,
            customer: customer,
            headlessCustomer: headlessCustomer,
            location: location,
            staff: staffInfo
        )
    }

    // MARK: - Update Order with History

    func updateOrderStatusWithHistory(id: UUID, fromStatus: String?, toStatus: String, note: String?) async throws {
        // Update order status
        try await updateOrderStatus(id: id, status: toStatus)

        // Add history entry
        try await addStatusHistory(orderId: id, fromStatus: fromStatus, toStatus: toStatus, note: note)
    }

    // MARK: - Update Item Fulfillment

    func updateItemFulfillment(itemId: UUID, status: String, fulfilledQty: Decimal?) async throws {
        struct UpdateData: Encodable {
            let fulfillment_status: String
            let fulfilled_quantity: Decimal?
        }

        let updateData = UpdateData(
            fulfillment_status: status,
            fulfilled_quantity: fulfilledQty
        )

        try await client.from("order_items")
            .update(updateData)
            .eq("id", value: itemId)
            .execute()
    }
}
