import Foundation
import SwiftUI

// MARK: - Order Model
// Following Apple engineering standards
// Maps to the orders table in Supabase

struct Order: Codable, Identifiable, Hashable {
    let id: UUID
    var orderNumber: String
    var customerId: UUID?
    var headlessCustomerId: UUID?  // For customers without platform accounts
    var storeId: UUID?
    var locationId: UUID?
    var status: String?
    var paymentStatus: String?
    var fulfillmentStatus: String?
    var orderType: String?
    var subtotal: Decimal
    var taxAmount: Decimal?
    var shippingAmount: Decimal?
    var discountAmount: Decimal?
    var totalAmount: Decimal
    var currency: String?
    var customerNote: String?
    var staffNotes: String?
    var paymentMethod: String?
    var paymentMethodTitle: String?
    var deliveryType: String?
    var pickupLocationId: UUID?
    var shippingName: String?
    var shippingCity: String?
    var shippingState: String?
    var trackingNumber: String?
    var orderDate: Date?
    var paidDate: Date?
    var completedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    // Staff/User tracking fields
    var createdByUserId: UUID?
    var preparedByUserId: UUID?
    var shippedByUserId: UUID?
    var deliveredByUserId: UUID?
    var employeeId: UUID?
    var updatedByUserId: UUID?
    var preparedAt: Date?
    var shippedAt: Date?
    var deliveredAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case orderNumber = "order_number"
        case customerId = "customer_id"
        case headlessCustomerId = "headless_customer_id"
        case storeId = "store_id"
        case locationId = "location_id"
        case status
        case paymentStatus = "payment_status"
        case fulfillmentStatus = "fulfillment_status"
        case orderType = "order_type"
        case subtotal
        case taxAmount = "tax_amount"
        case shippingAmount = "shipping_amount"
        case discountAmount = "discount_amount"
        case totalAmount = "total_amount"
        case currency
        case customerNote = "customer_note"
        case staffNotes = "staff_notes"
        case paymentMethod = "payment_method"
        case paymentMethodTitle = "payment_method_title"
        case deliveryType = "delivery_type"
        case pickupLocationId = "pickup_location_id"
        case shippingName = "shipping_name"
        case shippingCity = "shipping_city"
        case shippingState = "shipping_state"
        case trackingNumber = "tracking_number"
        case orderDate = "order_date"
        case paidDate = "paid_date"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdByUserId = "created_by_user_id"
        case preparedByUserId = "prepared_by_user_id"
        case shippedByUserId = "shipped_by_user_id"
        case deliveredByUserId = "delivered_by_user_id"
        case employeeId = "employee_id"
        case updatedByUserId = "updated_by_user_id"
        case preparedAt = "prepared_at"
        case shippedAt = "shipped_at"
        case deliveredAt = "delivered_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Order, rhs: Order) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Computed Properties

    var displayTitle: String {
        "#\(orderNumber)"
    }

    var displayTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: totalAmount as NSDecimalNumber) ?? "$0.00"
    }

    var statusColor: Color {
        switch status?.lowercased() {
        case "pending": return .orange
        case "confirmed": return .blue
        case "preparing", "packing", "packed": return .purple
        case "ready", "ready_to_ship": return .cyan
        case "shipped", "in_transit", "out_for_delivery": return .indigo
        case "delivered", "completed": return .green
        case "cancelled": return .red
        default: return .gray
        }
    }

    var statusLabel: String {
        switch status?.lowercased() {
        case "pending": return "Pending"
        case "confirmed": return "Confirmed"
        case "preparing": return "Preparing"
        case "packing": return "Packing"
        case "packed": return "Packed"
        case "ready": return "Ready"
        case "ready_to_ship": return "Ready to Ship"
        case "shipped": return "Shipped"
        case "in_transit": return "In Transit"
        case "out_for_delivery": return "Out for Delivery"
        case "delivered": return "Delivered"
        case "completed": return "Completed"
        case "cancelled": return "Cancelled"
        default: return status ?? "Unknown"
        }
    }

    var paymentStatusColor: Color {
        switch paymentStatus?.lowercased() {
        case "paid": return .green
        case "pending": return .orange
        case "partial": return .yellow
        case "failed": return .red
        case "refunded", "partially_refunded": return .purple
        default: return .gray
        }
    }

    var fulfillmentStatusColor: Color {
        switch fulfillmentStatus?.lowercased() {
        case "fulfilled": return .green
        case "partial": return .yellow
        case "unfulfilled": return .orange
        case "cancelled": return .red
        default: return .gray
        }
    }

    var orderTypeIcon: String {
        switch orderType?.lowercased() {
        case "walk_in": return "figure.walk"
        case "pickup": return "bag"
        case "delivery": return "car"
        case "shipping": return "shippingbox"
        case "direct": return "arrow.right.circle"
        default: return "cart"
        }
    }

    var orderTypeLabel: String {
        switch orderType?.lowercased() {
        case "walk_in": return "Walk-in"
        case "pickup": return "Pickup"
        case "delivery": return "Delivery"
        case "shipping": return "Shipping"
        case "direct": return "Direct"
        default: return orderType ?? "Order"
        }
    }
}

// MARK: - Order Status Enum

enum OrderStatus: String, CaseIterable {
    case pending
    case confirmed
    case preparing
    case packing
    case packed
    case ready
    case readyToShip = "ready_to_ship"
    case shipped
    case inTransit = "in_transit"
    case outForDelivery = "out_for_delivery"
    case delivered
    case completed
    case cancelled

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .preparing: return "Preparing"
        case .packing: return "Packing"
        case .packed: return "Packed"
        case .ready: return "Ready"
        case .readyToShip: return "Ready to Ship"
        case .shipped: return "Shipped"
        case .inTransit: return "In Transit"
        case .outForDelivery: return "Out for Delivery"
        case .delivered: return "Delivered"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .confirmed: return .blue
        case .preparing, .packing, .packed: return .purple
        case .ready, .readyToShip: return .cyan
        case .shipped, .inTransit, .outForDelivery: return .indigo
        case .delivered, .completed: return .green
        case .cancelled: return .red
        }
    }
}

// MARK: - Order Type Enum

enum OrderType: String, CaseIterable {
    case walkIn = "walk_in"
    case pickup
    case delivery
    case shipping
    case direct

    var label: String {
        switch self {
        case .walkIn: return "Walk-in"
        case .pickup: return "Pickup"
        case .delivery: return "Delivery"
        case .shipping: return "Shipping"
        case .direct: return "Direct"
        }
    }

    var icon: String {
        switch self {
        case .walkIn: return "figure.walk"
        case .pickup: return "bag"
        case .delivery: return "car"
        case .shipping: return "shippingbox"
        case .direct: return "arrow.right.circle"
        }
    }
}

// MARK: - Order Item

struct OrderItem: Codable, Identifiable, Hashable {
    let id: UUID
    var orderId: UUID
    var productId: UUID?
    var productName: String
    var productSku: String?
    var productImage: String?
    var productType: String?
    var unitPrice: Decimal
    var quantity: Decimal
    var lineSubtotal: Decimal
    var lineTotal: Decimal
    var taxAmount: Decimal?
    var tierName: String?
    var tierQty: Decimal?
    var tierPrice: Decimal?
    var quantityDisplay: String?
    var fulfillmentStatus: String?
    var fulfilledQuantity: Decimal?
    var costPerUnit: Decimal?
    var profitPerUnit: Decimal?
    var marginPercentage: Decimal?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case productId = "product_id"
        case productName = "product_name"
        case productSku = "product_sku"
        case productImage = "product_image"
        case productType = "product_type"
        case unitPrice = "unit_price"
        case quantity
        case lineSubtotal = "line_subtotal"
        case lineTotal = "line_total"
        case taxAmount = "tax_amount"
        case tierName = "tier_name"
        case tierQty = "tier_qty"
        case tierPrice = "tier_price"
        case quantityDisplay = "quantity_display"
        case fulfillmentStatus = "fulfillment_status"
        case fulfilledQuantity = "fulfilled_quantity"
        case costPerUnit = "cost_per_unit"
        case profitPerUnit = "profit_per_unit"
        case marginPercentage = "margin_percentage"
        case createdAt = "created_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: OrderItem, rhs: OrderItem) -> Bool {
        lhs.id == rhs.id
    }

    var displayQuantity: String {
        if let display = quantityDisplay, !display.isEmpty {
            return display
        }
        let qty = NSDecimalNumber(decimal: quantity).doubleValue
        if qty == floor(qty) {
            return String(format: "%.0f", qty)
        }
        return String(format: "%.2f", qty)
    }

    var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: unitPrice as NSDecimalNumber) ?? "$0.00"
    }

    var displayTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: lineTotal as NSDecimalNumber) ?? "$0.00"
    }

    var fulfillmentStatusColor: Color {
        switch fulfillmentStatus?.lowercased() {
        case "fulfilled": return .green
        case "partial": return .yellow
        case "unfulfilled": return .orange
        default: return .gray
        }
    }
}

// MARK: - Order Status History

struct OrderStatusHistory: Codable, Identifiable, Hashable {
    let id: UUID
    var orderId: UUID
    var fromStatus: String?
    var toStatus: String
    var note: String?
    var changedBy: UUID?
    var customerNotified: Bool?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case fromStatus = "from_status"
        case toStatus = "to_status"
        case note
        case changedBy = "changed_by"
        case customerNotified = "customer_notified"
        case createdAt = "created_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: OrderStatusHistory, rhs: OrderStatusHistory) -> Bool {
        lhs.id == rhs.id
    }

    var statusLabel: String {
        OrderStatus(rawValue: toStatus)?.label ?? toStatus.capitalized
    }

    var statusColor: Color {
        OrderStatus(rawValue: toStatus)?.color ?? .gray
    }
}

// MARK: - Order Customer (simplified for order context)

struct OrderCustomer: Codable, Identifiable, Hashable {
    let id: UUID
    var email: String?
    var phone: String?
    var displayName: String?
    var firstName: String?
    var lastName: String?

    enum CodingKeys: String, CodingKey {
        case id, email, phone
        case displayName = "display_name"
        case firstName = "first_name"
        case lastName = "last_name"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: OrderCustomer, rhs: OrderCustomer) -> Bool {
        lhs.id == rhs.id
    }

    var fullName: String {
        if let display = displayName, !display.isEmpty {
            return display
        }
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "Customer" : parts.joined(separator: " ")
    }
}

// MARK: - Staff Member (for order fulfillment tracking)

struct StaffMember: Codable, Identifiable, Hashable {
    let id: UUID
    var email: String?
    var phone: String?
    var firstName: String?
    var lastName: String?
    var displayName: String?
    var role: String?
    var employeeId: String?
    var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, email, phone, role
        case firstName = "first_name"
        case lastName = "last_name"
        case displayName = "display_name"
        case employeeId = "employee_id"
        case avatarUrl = "avatar_url"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: StaffMember, rhs: StaffMember) -> Bool {
        lhs.id == rhs.id
    }

    var fullName: String {
        if let display = displayName, !display.isEmpty {
            return display
        }
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (email ?? "Staff Member") : parts.joined(separator: " ")
    }

    var initials: String {
        let first = firstName?.prefix(1) ?? ""
        let last = lastName?.prefix(1) ?? ""
        if first.isEmpty && last.isEmpty {
            return String(email?.prefix(2).uppercased() ?? "SM")
        }
        return "\(first)\(last)".uppercased()
    }

    var roleLabel: String {
        switch role?.lowercased() {
        case "admin": return "Admin"
        case "manager": return "Manager"
        case "staff", "employee": return "Staff"
        case "budtender": return "Budtender"
        case "driver": return "Driver"
        case "cashier": return "Cashier"
        default: return role?.capitalized ?? "Staff"
        }
    }
}

// MARK: - Headless Customer (customers without platform accounts)

struct HeadlessCustomer: Codable, Identifiable, Hashable {
    let id: UUID
    var storeId: UUID?
    var email: String?
    var phone: String?
    var firstName: String?
    var lastName: String?
    var fullName: String?
    var dateOfBirth: Date?
    var idNumber: String?
    var idType: String?
    var idExpirationDate: Date?
    var address: String?
    var city: String?
    var state: String?
    var zipCode: String?
    var loyaltyPoints: Int?
    var totalSpent: Decimal?
    var orderCount: Int?
    var lastOrderDate: Date?
    var notes: String?
    var tags: [String]?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case storeId = "store_id"
        case email, phone, address, city, state, notes, tags
        case firstName = "first_name"
        case lastName = "last_name"
        case fullName = "full_name"
        case dateOfBirth = "date_of_birth"
        case idNumber = "id_number"
        case idType = "id_type"
        case idExpirationDate = "id_expiration_date"
        case zipCode = "zip_code"
        case loyaltyPoints = "loyalty_points"
        case totalSpent = "total_spent"
        case orderCount = "order_count"
        case lastOrderDate = "last_order_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: HeadlessCustomer, rhs: HeadlessCustomer) -> Bool {
        lhs.id == rhs.id
    }

    var displayName: String {
        if let full = fullName, !full.isEmpty {
            return full
        }
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (phone ?? email ?? "Customer") : parts.joined(separator: " ")
    }

    var initials: String {
        let first = firstName?.prefix(1) ?? ""
        let last = lastName?.prefix(1) ?? ""
        if first.isEmpty && last.isEmpty {
            return "C"
        }
        return "\(first)\(last)".uppercased()
    }

    var formattedPhone: String? {
        guard let phone = phone, phone.count >= 10 else { return phone }
        let digits = phone.filter { $0.isNumber }
        if digits.count == 10 {
            let area = digits.prefix(3)
            let mid = digits.dropFirst(3).prefix(3)
            let last = digits.suffix(4)
            return "(\(area)) \(mid)-\(last)"
        }
        return phone
    }
}

// MARK: - Order Staff Info (aggregated staff for an order)

struct OrderStaffInfo {
    var createdBy: StaffMember?
    var preparedBy: StaffMember?
    var shippedBy: StaffMember?
    var deliveredBy: StaffMember?
    var employee: StaffMember?
    var updatedBy: StaffMember?
}

// MARK: - Order With Details (for full order view)

struct OrderWithDetails {
    let order: Order
    let items: [OrderItem]
    let statusHistory: [OrderStatusHistory]
    let customer: OrderCustomer?
    let headlessCustomer: HeadlessCustomer?
    let location: Location?
    let staff: OrderStaffInfo
}
