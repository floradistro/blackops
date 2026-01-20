import SwiftUI

// MARK: - Order Detail Panel
// Matches ProductEditorPanel UI pattern

struct OrderDetailPanel: View {
    let order: Order
    @ObservedObject var store: EditorStore

    @State private var orderItems: [OrderItem] = []
    @State private var statusHistory: [OrderStatusHistory] = []
    @State private var customer: OrderCustomer? = nil
    @State private var headlessCustomer: HeadlessCustomer? = nil
    @State private var orderLocation: Location? = nil
    @State private var staffInfo: OrderStaffInfo = OrderStaffInfo()
    @State private var isLoading = true
    @State private var showStatusSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                OrderHeader(order: order, onStatusTap: { showStatusSheet = true })

                Divider()
                    .padding(.vertical, 8)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(40)
                } else {
                    // Customer Section
                    if let customer = customer {
                        OrderCustomerRow(customer: customer)
                    } else if let headless = headlessCustomer {
                        OrderHeadlessCustomerRow(customer: headless)
                    }

                    // Staff Section
                    if hasStaff {
                        Divider()
                            .padding(.vertical, 8)
                        OrderStaffRows(order: order, staff: staffInfo)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Order Items
                    SectionHeader(title: "Items")
                    if orderItems.isEmpty {
                        Text("No items")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(orderItems) { item in
                                OrderItemRow(item: item)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Summary
                    SectionHeader(title: "Summary")
                    VStack(spacing: 6) {
                        InfoRow(label: "Subtotal", value: formatCurrency(order.subtotal))
                        if let tax = order.taxAmount, tax > 0 {
                            InfoRow(label: "Tax", value: formatCurrency(tax))
                        }
                        if let shipping = order.shippingAmount, shipping > 0 {
                            InfoRow(label: "Shipping", value: formatCurrency(shipping))
                        }
                        if let discount = order.discountAmount, discount > 0 {
                            HStack(spacing: 12) {
                                Text("Discount")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 120, alignment: .leading)
                                    .font(.system(size: 12))
                                Text("-\(formatCurrency(discount))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.green)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        HStack(spacing: 12) {
                            Text("Total")
                                .foregroundStyle(.primary)
                                .frame(width: 120, alignment: .leading)
                                .font(.system(size: 13, weight: .semibold))
                            Text(order.displayTotal)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)

                    Divider()
                        .padding(.vertical, 8)

                    // Payment
                    SectionHeader(title: "Payment")
                    VStack(spacing: 6) {
                        HStack(spacing: 12) {
                            Text("Status")
                                .foregroundStyle(.secondary)
                                .frame(width: 120, alignment: .leading)
                                .font(.system(size: 12))
                            Text(order.paymentStatus?.capitalized ?? "Unknown")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(order.paymentStatusColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        InfoRow(label: "Method", value: order.paymentMethodTitle ?? order.paymentMethod ?? "-")
                        HStack(spacing: 12) {
                            Text("Fulfillment")
                                .foregroundStyle(.secondary)
                                .frame(width: 120, alignment: .leading)
                                .font(.system(size: 12))
                            Text(order.fulfillmentStatus?.capitalized ?? "Unfulfilled")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(order.fulfillmentStatusColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Shipping/Pickup
                    if order.orderType == "shipping" || order.orderType == "delivery" {
                        Divider()
                            .padding(.vertical, 8)
                        SectionHeader(title: "Shipping")
                        VStack(spacing: 6) {
                            if let name = order.shippingName {
                                InfoRow(label: "Name", value: name)
                            }
                            if let city = order.shippingCity, let state = order.shippingState {
                                InfoRow(label: "Location", value: "\(city), \(state)")
                            }
                            if let tracking = order.trackingNumber {
                                InfoRow(label: "Tracking", value: tracking)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    if order.orderType == "pickup", let location = orderLocation {
                        Divider()
                            .padding(.vertical, 8)
                        SectionHeader(title: "Pickup Location")
                        VStack(spacing: 6) {
                            InfoRow(label: "Name", value: location.name)
                            if let address = location.address {
                                InfoRow(label: "Address", value: address)
                            }
                            if let city = location.city, let state = location.state {
                                InfoRow(label: "Location", value: "\(city), \(state)")
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Notes
                    if let note = order.customerNote, !note.isEmpty {
                        Divider()
                            .padding(.vertical, 8)
                        SectionHeader(title: "Customer Note")
                        Text(note)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }

                    if let note = order.staffNotes, !note.isEmpty {
                        Divider()
                            .padding(.vertical, 8)
                        SectionHeader(title: "Staff Notes")
                        Text(note)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }

                    // Timeline
                    if !statusHistory.isEmpty {
                        Divider()
                            .padding(.vertical, 8)
                        SectionHeader(title: "Timeline")
                        VStack(spacing: 8) {
                            ForEach(statusHistory) { entry in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(entry.statusColor)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.statusLabel)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(entry.statusColor)
                                        if let note = entry.note, !note.isEmpty {
                                            Text(note)
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if let date = entry.createdAt {
                                        Text(date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .task {
            await loadOrderDetails()
        }
        .sheet(isPresented: $showStatusSheet) {
            OrderStatusSheet(
                order: order,
                store: store,
                onDismiss: {
                    showStatusSheet = false
                    Task { await loadOrderDetails() }
                }
            )
        }
    }

    private var hasStaff: Bool {
        staffInfo.createdBy != nil || staffInfo.preparedBy != nil ||
        staffInfo.shippedBy != nil || staffInfo.deliveredBy != nil ||
        staffInfo.employee != nil
    }

    private func loadOrderDetails() async {
        isLoading = true
        NSLog("[OrderDetailPanel] Loading details for order: \(order.id) - \(order.orderNumber)")
        do {
            let details = try await store.supabase.fetchOrderWithDetails(orderId: order.id, locationId: order.locationId)
            NSLog("[OrderDetailPanel] Loaded: \(details.items.count) items, \(details.statusHistory.count) history, customer: \(details.customer != nil), headless: \(details.headlessCustomer != nil)")
            orderItems = details.items
            statusHistory = details.statusHistory
            customer = details.customer
            headlessCustomer = details.headlessCustomer
            orderLocation = details.location
            staffInfo = details.staff
        } catch {
            NSLog("[OrderDetailPanel] Failed to load details: \(error)")
        }
        isLoading = false
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = order.currency ?? "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Order Header

private struct OrderHeader: View {
    let order: Order
    let onStatusTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(order.displayTitle)
                    .font(.system(size: 18, weight: .semibold))

                HStack(spacing: 8) {
                    Label(order.orderTypeLabel, systemImage: order.orderTypeIcon)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if let date = order.createdAt {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Button(action: onStatusTap) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(order.statusColor)
                        .frame(width: 8, height: 8)
                    Text(order.statusLabel)
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(order.statusColor.opacity(0.15))
                .foregroundStyle(order.statusColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Customer Row

private struct OrderCustomerRow: View {
    let customer: OrderCustomer

    var body: some View {
        SectionHeader(title: "Customer")
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(customer.fullName.prefix(2).uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(customer.fullName)
                    .font(.system(size: 13, weight: .medium))
                if let email = customer.email {
                    Text(email)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if let phone = customer.phone {
                    Text(phone)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Headless Customer Row

private struct OrderHeadlessCustomerRow: View {
    let customer: HeadlessCustomer

    var body: some View {
        SectionHeader(title: "Customer")
        HStack(spacing: 12) {
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(customer.initials)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.purple)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(customer.displayName)
                        .font(.system(size: 13, weight: .medium))
                    Text("Walk-in")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
                if let email = customer.email {
                    Text(email)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if let phone = customer.formattedPhone {
                    Text(phone)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let points = customer.loyaltyPoints, points > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                    Text("\(points)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Staff Rows

private struct OrderStaffRows: View {
    let order: Order
    let staff: OrderStaffInfo

    var body: some View {
        SectionHeader(title: "Staff")
        VStack(spacing: 6) {
            if let member = staff.createdBy {
                StaffInfoRow(label: "Created by", member: member, date: order.createdAt)
            }
            if let member = staff.employee, member.id != staff.createdBy?.id {
                StaffInfoRow(label: "Assigned to", member: member, date: nil)
            }
            if let member = staff.preparedBy {
                StaffInfoRow(label: "Prepared by", member: member, date: order.preparedAt)
            }
            if let member = staff.shippedBy {
                StaffInfoRow(label: "Shipped by", member: member, date: order.shippedAt)
            }
            if let member = staff.deliveredBy {
                StaffInfoRow(label: "Delivered by", member: member, date: order.deliveredAt)
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct StaffInfoRow: View {
    let label: String
    let member: StaffMember
    let date: Date?

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 12))

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text(member.initials)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    )

                Text(member.fullName)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)

                if member.role != nil {
                    Text("(\(member.roleLabel))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let date = date {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Order Item Row

private struct OrderItemRow: View {
    let item: OrderItem

    var body: some View {
        HStack(spacing: 12) {
            // Product image
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(white: 0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Group {
                        if let imageUrl = item.productImage, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "photo")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                            }
                        } else {
                            Image(systemName: "leaf")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(item.displayQuantity) × \(item.displayPrice)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if let tier = item.tierName {
                        Text(tier)
                            .font(.system(size: 9))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.displayTotal)
                    .font(.system(size: 12, weight: .medium))

                Text(item.fulfillmentStatus?.capitalized ?? "Unfulfilled")
                    .font(.system(size: 10))
                    .foregroundStyle(item.fulfillmentStatusColor)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Status Update Sheet

private struct OrderStatusSheet: View {
    let order: Order
    @ObservedObject var store: EditorStore
    let onDismiss: () -> Void

    @State private var selectedStatus: String = ""
    @State private var note: String = ""
    @State private var isUpdating = false

    let statuses = OrderStatus.allCases

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Update Status")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Current:")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(order.statusLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(order.statusColor)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(statuses, id: \.rawValue) { status in
                            Button {
                                selectedStatus = status.rawValue
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(status.color)
                                        .frame(width: 6, height: 6)
                                    Text(status.label)
                                        .font(.system(size: 11))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedStatus == status.rawValue ? status.color.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(selectedStatus == status.rawValue ? status.color : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(status.rawValue == order.status)
                            .opacity(status.rawValue == order.status ? 0.5 : 1)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note (optional)")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        TextEditor(text: $note)
                            .font(.system(size: 12))
                            .frame(height: 60)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(16)
            }

            Divider()

            HStack {
                Spacer()
                Button("Update") {
                    Task {
                        isUpdating = true
                        await store.updateOrderStatus(order, toStatus: selectedStatus, note: note.isEmpty ? nil : note)
                        isUpdating = false
                        onDismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedStatus.isEmpty || selectedStatus == order.status || isUpdating)
            }
            .padding(16)
        }
        .frame(width: 400, height: 400)
        .onAppear {
            selectedStatus = order.status ?? ""
        }
    }
}
