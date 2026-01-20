import SwiftUI

// MARK: - Customer Detail Panel
// Comprehensive CRM-style customer view following existing panel patterns

struct CustomerDetailPanel: View {
    let customer: Customer
    @ObservedObject var store: EditorStore

    @State private var customerOrders: [Order] = []
    @State private var customerNotes: [CustomerNote] = []
    @State private var customerLoyalty: CustomerLoyalty? = nil
    @State private var isLoading = true
    @State private var showAddNoteSheet = false
    @State private var newNoteText = ""
    @State private var newNoteType = "general"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with customer info
                CustomerHeader(customer: customer)

                Divider()
                    .padding(.vertical, 8)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(40)
                } else {
                    // Stats Cards
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Total Spent",
                            value: customer.formattedTotalSpent,
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )
                        StatCard(
                            title: "Orders",
                            value: "\(customer.totalOrders ?? 0)",
                            icon: "cart.fill",
                            color: .blue
                        )
                    }
                    .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        StatCard(
                            title: "Loyalty Points",
                            value: "\(customer.loyaltyPoints ?? 0)",
                            icon: "star.fill",
                            color: Color(customer.loyaltyTierColor)
                        )
                        StatCard(
                            title: "Lifetime Value",
                            value: customer.formattedLifetimeValue,
                            icon: "chart.line.uptrend.xyaxis",
                            color: .purple
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Divider()
                        .padding(.vertical, 8)

                    // Contact Information
                    CustomerSectionHeader(title: "Contact Information")
                    VStack(spacing: 6) {
                        if let email = customer.email {
                            CustomerContactRow(icon: "envelope.fill", label: "Email", value: email)
                        }
                        if let phone = customer.phone {
                            CustomerContactRow(icon: "phone.fill", label: "Phone", value: phone)
                        }
                        if customer.email == nil && customer.phone == nil {
                            Text("No contact information")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Address Information
                    if customer.streetAddress != nil || customer.city != nil {
                        Divider()
                            .padding(.vertical, 8)

                        CustomerSectionHeader(title: "Address")
                        VStack(alignment: .leading, spacing: 4) {
                            if let street = customer.streetAddress {
                                Text(street)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary)
                            }
                            HStack {
                                if let city = customer.city {
                                    Text(city)
                                }
                                if let state = customer.state {
                                    Text(state)
                                }
                                if let zip = customer.postalCode {
                                    Text(zip)
                                }
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }

                    // Loyalty Details
                    if let loyalty = customerLoyalty {
                        Divider()
                            .padding(.vertical, 8)

                        CustomerSectionHeader(title: "Loyalty Program")
                        LoyaltyDetailsView(loyalty: loyalty)
                            .padding(.horizontal, 20)
                    }

                    // Verification & Status
                    Divider()
                        .padding(.vertical, 8)

                    CustomerSectionHeader(title: "Account Status")
                    VStack(spacing: 6) {
                        CustomerStatusRow(
                            icon: customer.idVerified == true ? "checkmark.shield.fill" : "shield",
                            label: "ID Verified",
                            value: customer.idVerified == true ? "Yes" : "No",
                            color: customer.idVerified == true ? .green : .gray
                        )
                        CustomerStatusRow(
                            icon: customer.isActive == true ? "checkmark.circle.fill" : "xmark.circle.fill",
                            label: "Account Status",
                            value: customer.isActive == true ? "Active" : "Inactive",
                            color: customer.isActive == true ? .green : .red
                        )
                        if customer.emailConsent == true || customer.smsConsent == true {
                            CustomerStatusRow(
                                icon: "bell.fill",
                                label: "Marketing Consent",
                                value: [
                                    customer.emailConsent == true ? "Email" : nil,
                                    customer.smsConsent == true ? "SMS" : nil
                                ].compactMap { $0 }.joined(separator: ", "),
                                color: .blue
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    // Recent Orders
                    Divider()
                        .padding(.vertical, 8)

                    CustomerSectionHeader(title: "Recent Orders")
                    if customerOrders.isEmpty {
                        Text("No orders yet")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(customerOrders.prefix(10)) { order in
                                CustomerOrderRow(order: order) {
                                    store.openTab(.order(order))
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        if customerOrders.count > 10 {
                            Button("View all \(customerOrders.count) orders") {
                                // TODO: Filter orders view by customer
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                        }
                    }

                    // Customer Notes
                    Divider()
                        .padding(.vertical, 8)

                    HStack {
                        CustomerSectionHeader(title: "Notes")
                        Spacer()
                        Button(action: { showAddNoteSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Note")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                    }

                    if customerNotes.isEmpty {
                        Text("No notes")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(customerNotes) { note in
                                CustomerNoteCard(note: note)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Metadata
                    if let createdAt = customer.createdAt {
                        Divider()
                            .padding(.vertical, 8)

                        CustomerSectionHeader(title: "Account Information")
                        VStack(spacing: 6) {
                            CustomerInfoRow(label: "Customer Since", value: formatDate(createdAt))
                            if let updatedAt = customer.updatedAt {
                                CustomerInfoRow(label: "Last Updated", value: formatDate(updatedAt))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .background(VisualEffectBackground(material: .underWindowBackground))
        .task {
            await loadCustomerDetails()
        }
        .sheet(isPresented: $showAddNoteSheet) {
            AddNoteSheet(
                customerName: customer.displayName,
                noteText: $newNoteText,
                noteType: $newNoteType,
                onSave: { await addNote() }
            )
        }
    }

    private func loadCustomerDetails() async {
        isLoading = true

        // Load orders for this customer
        let storeId = store.selectedStore?.id ?? store.defaultStoreId
        if true {
            do {
                // Fetch all orders and filter by customer
                let allOrders = try await store.supabase.fetchOrders(storeId: storeId, limit: 500)
                customerOrders = allOrders.filter { order in
                    order.customerId == customer.platformUserId || order.headlessCustomerId == customer.id
                }

                // Fetch notes
                if let platformUserId = customer.platformUserId {
                    customerNotes = try await store.supabase.fetchCustomerNotes(customerId: platformUserId, limit: 50)
                }

                // Fetch loyalty details
                if let platformUserId = customer.platformUserId {
                    customerLoyalty = try await store.supabase.fetchCustomerLoyalty(customerId: platformUserId, storeId: storeId)
                }
            } catch {
                print("❌ Error loading customer details: \(error)")
            }
        }

        isLoading = false
    }

    private func addNote() async {
        guard let platformUserId = customer.platformUserId else { return }

        do {
            let note = try await store.supabase.createCustomerNote(
                customerId: platformUserId,
                note: newNoteText,
                noteType: newNoteType,
                isCustomerVisible: false
            )
            customerNotes.insert(note, at: 0)
            newNoteText = ""
            newNoteType = "general"
            showAddNoteSheet = false
        } catch {
            print("❌ Error adding note: \(error)")
            store.error = "Failed to add note: \(error.localizedDescription)"
        }
    }

    private func formatCurrency(_ amount: Decimal?) -> String {
        guard let amount = amount else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Customer Header

struct CustomerHeader: View {
    let customer: Customer

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            if let avatarUrl = customer.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(customer.statusColor).opacity(0.2))
                        .overlay(
                            Text(customer.initials)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(customer.statusColor))
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(customer.statusColor).opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(customer.initials)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(customer.statusColor))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(customer.displayName)
                        .font(.system(size: 18, weight: .semibold))
                    if customer.idVerified == true {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                }

                if let tier = customer.loyaltyTier {
                    HStack(spacing: 4) {
                        Image(systemName: customer.loyaltyTierIcon)
                            .font(.system(size: 11))
                        Text("\(tier.capitalized) Member")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(customer.loyaltyTierColor))
                }

                Text("ID: \(customer.id.uuidString.prefix(8))...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

struct CustomerContactRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CustomerStatusRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CustomerInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CustomerSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }
}

struct CustomerOrderRow: View {
    let order: Order
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.displayTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    if let date = order.createdAt {
                        Text(formatDate(date))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(order.displayTotal)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(order.status?.capitalized ?? "Unknown")
                        .font(.system(size: 10))
                        .foregroundStyle(order.statusColor)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct CustomerNoteCard: View {
    let note: CustomerNote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: note.noteTypeIcon)
                    .font(.system(size: 11))
                    .foregroundColor(Color(note.noteTypeColor))
                Text(note.noteType?.capitalized ?? "Note")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(note.noteTypeColor))
                Spacer()
                if let date = note.createdAt {
                    Text(formatDate(date))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Text(note.note)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(note.noteTypeColor).opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(note.noteTypeColor).opacity(0.2), lineWidth: 1)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct LoyaltyDetailsView: View {
    let loyalty: CustomerLoyalty

    var body: some View {
        VStack(spacing: 6) {
            CustomerInfoRow(label: "Current Tier", value: loyalty.currentTier ?? "None")
            CustomerInfoRow(label: "Points Balance", value: "\(loyalty.pointsBalance ?? 0)")
            CustomerInfoRow(label: "Lifetime Earned", value: "\(loyalty.pointsLifetimeEarned ?? 0)")
            CustomerInfoRow(label: "Lifetime Redeemed", value: "\(loyalty.pointsLifetimeRedeemed ?? 0)")
            if let provider = loyalty.provider {
                CustomerInfoRow(label: "Provider", value: provider.capitalized)
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddNoteSheet: View {
    let customerName: String
    @Binding var noteText: String
    @Binding var noteType: String
    let onSave: () async -> Void

    @Environment(\.dismiss) var dismiss

    let noteTypes = ["general", "support", "billing", "fraud", "vip"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Note for \(customerName)")
                .font(.system(size: 16, weight: .semibold))

            Picker("Type", selection: $noteType) {
                ForEach(noteTypes, id: \.self) { type in
                    Text(type.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)

            TextEditor(text: $noteText)
                .font(.system(size: 13))
                .frame(height: 120)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save") {
                    Task {
                        await onSave()
                        dismiss()
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(noteText.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
