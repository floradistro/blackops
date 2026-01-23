import SwiftUI

// MARK: - Order Detail Panel
// Minimal, monochromatic theme - modern macOS native

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
        VStack(spacing: 0) {
            // Inline toolbar
            PanelToolbar(
                title: order.displayTitle,
                icon: order.orderTypeIcon,
                subtitle: order.statusLabel
            ) {
                ToolbarButton(
                    icon: "arrow.clockwise",
                    action: { Task { await loadOrderDetails() } }
                )
                ToolbarButton(
                    icon: "ellipsis.circle",
                    action: { showStatusSheet = true }
                )
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    orderHeader

                    Divider()
                        .padding(.vertical, 8)

                    if isLoading {
                        Text("···")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(40)
                    } else {
                        // Customer Section
                        if let customer = customer {
                            customerSection(customer)
                        } else if let headless = headlessCustomer {
                            headlessCustomerSection(headless)
                        }

                        // Staff Section
                        if hasStaff {
                            Divider()
                                .padding(.vertical, 8)
                            staffSection
                        }

                        Divider()
                            .padding(.vertical, 8)

                        // Order Items
                        itemsSection

                        Divider()
                            .padding(.vertical, 8)

                        // Summary
                        summarySection

                        Divider()
                            .padding(.vertical, 8)

                        // Payment
                        paymentSection

                        // Shipping/Pickup
                        if order.fulfillmentType == .ship {
                            Divider()
                                .padding(.vertical, 8)
                            shippingSection
                        }

                        if order.fulfillmentType == .pickup, let location = orderLocation {
                            Divider()
                                .padding(.vertical, 8)
                            pickupSection(location)
                        }

                        // Notes
                        if let note = order.customerNote, !note.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                            noteSection(title: "Customer Note", note: note)
                        }

                        if let note = order.staffNotes, !note.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                            noteSection(title: "Staff Notes", note: note)
                        }

                        // Timeline
                        if !statusHistory.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                            timelineSection
                        }

                        Spacer(minLength: 40)
                    }
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

    // MARK: - Header

    private var orderHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(order.displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.9))

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: order.orderTypeIcon)
                            .font(.system(size: 10))
                        Text(order.orderTypeLabel)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.5))

                    if let date = order.createdAt {
                        Text("·")
                            .foregroundStyle(Color.primary.opacity(0.3))
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.primary.opacity(0.4))
                    }
                }
            }

            Spacer()

            // Status badge - sleek, minimal
            Button(action: { showStatusSheet = true }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.primary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(order.statusLabel)
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(Color.primary.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Customer

    private func customerSection(_ customer: OrderCustomer) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Customer")
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 32, height: 32)
                    Text(customer.fullName.prefix(2).uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(customer.fullName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.8))
                    if let email = customer.email {
                        Text(email)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                    if let phone = customer.phone {
                        Text(phone)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.primary.opacity(0.4))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    private func headlessCustomerSection(_ customer: HeadlessCustomer) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Customer")
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 32, height: 32)
                    Text(customer.initials)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(customer.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.8))
                        Text("Walk-in")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    if let email = customer.email {
                        Text(email)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                    if let phone = customer.formattedPhone {
                        Text(phone)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.primary.opacity(0.4))
                    }
                }

                Spacer()

                if let points = customer.loyaltyPoints, points > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                        Text("\(points)")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(Color.primary.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Staff

    private var staffSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Staff")
            VStack(spacing: 6) {
                if let member = staffInfo.createdBy {
                    staffRow(label: "Created by", member: member, date: order.createdAt)
                }
                if let member = staffInfo.employee, member.id != staffInfo.createdBy?.id {
                    staffRow(label: "Assigned to", member: member, date: nil)
                }
                if let member = staffInfo.preparedBy {
                    staffRow(label: "Prepared by", member: member, date: order.preparedAt)
                }
                if let member = staffInfo.shippedBy {
                    staffRow(label: "Shipped by", member: member, date: order.shippedAt)
                }
                if let member = staffInfo.deliveredBy {
                    staffRow(label: "Delivered by", member: member, date: order.deliveredAt)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func staffRow(label: String, member: StaffMember, date: Date?) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 100, alignment: .leading)

            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 18, height: 18)
                    Text(member.initials)
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.6))
                }

                Text(member.fullName)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.8))

                if member.role != nil {
                    Text("(\(member.roleLabel))")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
            }

            Spacer()

            if let date = date {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.3))
            }
        }
    }

    // MARK: - Items

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionHeader(title: "Items")
                Spacer()
                Text("\(orderItems.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .padding(.trailing, 20)
            }

            if orderItems.isEmpty {
                Text("No items")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(orderItems) { item in
                        itemRow(item)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func itemRow(_ item: OrderItem) -> some View {
        HStack(spacing: 12) {
            // Product image
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(0.05))
                .frame(width: 40, height: 40)
                .overlay(
                    Group {
                        if let imageUrl = item.productImage, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "photo")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.primary.opacity(0.2))
                            }
                        } else {
                            Image(systemName: "leaf")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.primary.opacity(0.3))
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(item.displayQuantity) × \(item.displayPrice)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.5))

                    if let tier = item.tierName {
                        Text(tier)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.displayTotal)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.8))

                Text(item.fulfillmentStatus?.capitalized ?? "Unfulfilled")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Summary")
            VStack(spacing: 4) {
                summaryRow(label: "Subtotal", value: formatCurrency(order.subtotal))
                if let tax = order.taxAmount, tax > 0 {
                    summaryRow(label: "Tax", value: formatCurrency(tax))
                }
                if let shipping = order.shippingAmount, shipping > 0 {
                    summaryRow(label: "Shipping", value: formatCurrency(shipping))
                }
                if let discount = order.discountAmount, discount > 0 {
                    summaryRow(label: "Discount", value: "-\(formatCurrency(discount))", isDiscount: true)
                }
                HStack(spacing: 12) {
                    Text("Total")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.8))
                        .frame(width: 100, alignment: .leading)
                    Text(order.displayTotal)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.9))
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
        }
    }

    private func summaryRow(label: String, value: String, isDiscount: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(isDiscount ? 0.6 : 0.7))
            Spacer()
        }
    }

    // MARK: - Payment

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Payment")
            VStack(spacing: 4) {
                HStack(spacing: 12) {
                    Text("Status")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .frame(width: 100, alignment: .leading)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.primary.opacity(0.5))
                            .frame(width: 5, height: 5)
                        Text(order.paymentStatus?.capitalized ?? "Unknown")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.7))
                    }
                    Spacer()
                }
                InfoRow(label: "Method", value: order.paymentMethodTitle ?? order.paymentMethod ?? "-")
                HStack(spacing: 12) {
                    Text("Fulfillment")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .frame(width: 100, alignment: .leading)
                    Text(order.fulfillmentStatus?.capitalized ?? "Unfulfilled")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.primary.opacity(0.6))
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Shipping

    private var shippingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Shipping")
            VStack(spacing: 4) {
                if let name = order.shippingName {
                    InfoRow(label: "Name", value: name)
                }
                if let city = order.shippingCity, let state = order.shippingState {
                    InfoRow(label: "Location", value: "\(city), \(state)")
                }
                if let tracking = order.fulfillmentTrackingNumber {
                    InfoRow(label: "Tracking", value: tracking)
                }
                if let carrier = order.fulfillmentCarrier {
                    InfoRow(label: "Carrier", value: carrier)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func pickupSection(_ location: Location) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Pickup Location")
            VStack(spacing: 4) {
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
    }

    // MARK: - Notes

    private func noteSection(title: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: title)
            Text(note)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Timeline")
            VStack(spacing: 8) {
                ForEach(statusHistory) { entry in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.primary.opacity(0.4))
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.statusLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.primary.opacity(0.7))
                            if let note = entry.note, !note.isEmpty {
                                Text(note)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.primary.opacity(0.5))
                            }
                        }
                        Spacer()
                        if let date = entry.createdAt {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 10))
                                .foregroundStyle(Color.primary.opacity(0.3))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helpers

    private var hasStaff: Bool {
        staffInfo.createdBy != nil || staffInfo.preparedBy != nil ||
        staffInfo.shippedBy != nil || staffInfo.deliveredBy != nil ||
        staffInfo.employee != nil
    }

    private func loadOrderDetails() async {
        isLoading = true
        do {
            let details = try await store.supabase.fetchOrderWithDetails(orderId: order.id, locationId: order.locationId)
            orderItems = details.items
            statusHistory = details.statusHistory
            customer = details.customer
            headlessCustomer = details.headlessCustomer
            orderLocation = details.location
            staffInfo = details.staff
        } catch {
            print("[OrderDetail] Error: \(error)")
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
            // Header
            HStack {
                Text("Update Status")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.8))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Current status
                    HStack(spacing: 8) {
                        Text("Current:")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.primary.opacity(0.5))
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.primary.opacity(0.5))
                                .frame(width: 5, height: 5)
                            Text(order.statusLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.primary.opacity(0.7))
                        }
                    }

                    // Status grid - sleek minimal buttons
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 6) {
                        ForEach(statuses, id: \.rawValue) { status in
                            Button {
                                selectedStatus = status.rawValue
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.primary.opacity(selectedStatus == status.rawValue ? 0.6 : 0.3))
                                        .frame(width: 5, height: 5)
                                    Text(status.label)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.primary.opacity(selectedStatus == status.rawValue ? 0.8 : 0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(selectedStatus == status.rawValue ? 0.08 : 0.03))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.primary.opacity(selectedStatus == status.rawValue ? 0.15 : 0), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(status.rawValue == order.status)
                            .opacity(status.rawValue == order.status ? 0.4 : 1)
                        }
                    }

                    // Note field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note (optional)")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.primary.opacity(0.4))

                        TextEditor(text: $note)
                            .font(.system(size: 11))
                            .frame(height: 60)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                    }
                }
                .padding(16)
            }

            Divider()

            // Footer - sleek minimal button
            HStack {
                Spacer()
                Button {
                    Task {
                        isUpdating = true
                        await store.updateOrderStatus(order, toStatus: selectedStatus, note: note.isEmpty ? nil : note)
                        isUpdating = false
                        onDismiss()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isUpdating {
                            Text("···")
                                .font(.system(size: 11, design: .monospaced))
                        } else {
                            Text("Update")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .foregroundStyle(Color.primary.opacity(canUpdate ? 0.8 : 0.3))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(canUpdate ? 0.08 : 0.03))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .disabled(!canUpdate || isUpdating)
            }
            .padding(16)
        }
        .frame(width: 360, height: 380)
        .onAppear {
            selectedStatus = order.status ?? ""
        }
    }

    private var canUpdate: Bool {
        !selectedStatus.isEmpty && selectedStatus != order.status
    }
}
