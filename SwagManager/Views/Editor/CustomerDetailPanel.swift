import SwiftUI

// MARK: - Customer Detail Panel
// Minimal, monochromatic theme

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
        VStack(spacing: 0) {
            // Inline toolbar
            PanelToolbar(
                title: customer.displayName,
                icon: "person.circle",
                subtitle: customer.loyaltyTier?.capitalized
            ) {
                ToolbarButton(
                    icon: "arrow.clockwise",
                    action: { Task { await loadCustomerDetails() } }
                )
                ToolbarButton(
                    icon: "plus.bubble",
                    action: { showAddNoteSheet = true }
                )
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    customerHeader

                    Divider()
                        .padding(.vertical, 8)

                    if isLoading {
                        Text("···")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(40)
                    } else {
                        // Stats
                        statsSection

                        Divider()
                            .padding(.vertical, 8)

                        // Contact Information
                        SectionHeader(title: "Contact")
                        contactSection

                        // Address
                        if customer.streetAddress != nil || customer.city != nil {
                            Divider()
                                .padding(.vertical, 8)
                            SectionHeader(title: "Address")
                            addressSection
                        }

                        // Loyalty
                        if let loyalty = customerLoyalty {
                            Divider()
                                .padding(.vertical, 8)
                            SectionHeader(title: "Loyalty")
                            loyaltySection(loyalty)
                        }

                        // Account Status
                        Divider()
                            .padding(.vertical, 8)
                        SectionHeader(title: "Account")
                        accountStatusSection

                        // Orders
                        Divider()
                            .padding(.vertical, 8)
                        ordersSection

                        // Notes
                        Divider()
                            .padding(.vertical, 8)
                        notesSection

                        // Metadata
                        if let createdAt = customer.createdAt {
                            Divider()
                                .padding(.vertical, 8)
                            SectionHeader(title: "Info")
                            metadataSection(createdAt: createdAt)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .task {
            await loadCustomerDetails()
        }
        .sheet(isPresented: $showAddNoteSheet) {
            MinimalAddNoteSheet(
                customerName: customer.displayName,
                noteText: $newNoteText,
                noteType: $newNoteType,
                onSave: { await addNote() }
            )
        }
    }

    // MARK: - Header

    private var customerHeader: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 48, height: 48)
                Text(customer.initials)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(customer.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.9))
                    if customer.idVerified == true {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                }

                if let tier = customer.loyaltyTier {
                    HStack(spacing: 4) {
                        Image(systemName: "star")
                            .font(.system(size: 10))
                        Text("\(tier.capitalized) Member")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.primary.opacity(0.5))
                }

                Text("ID: \(customer.id.uuidString.prefix(8))...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.3))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 1) {
            MinimalStatCell(title: "Spent", value: customer.formattedTotalSpent)
            MinimalStatCell(title: "Orders", value: "\(customer.totalOrders ?? 0)")
            MinimalStatCell(title: "Points", value: "\(customer.loyaltyPoints ?? 0)")
            MinimalStatCell(title: "LTV", value: customer.formattedLifetimeValue)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Contact

    private var contactSection: some View {
        VStack(spacing: 6) {
            if let email = customer.email {
                MinimalInfoRow(label: "Email", value: email)
            }
            if let phone = customer.phone {
                MinimalInfoRow(label: "Phone", value: phone)
            }
            if customer.email == nil && customer.phone == nil {
                Text("No contact information")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Address

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let street = customer.streetAddress {
                Text(street)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.7))
            }
            HStack(spacing: 4) {
                if let city = customer.city { Text(city) }
                if let state = customer.state { Text(state) }
                if let zip = customer.postalCode { Text(zip) }
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.primary.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Loyalty

    private func loyaltySection(_ loyalty: CustomerLoyalty) -> some View {
        VStack(spacing: 6) {
            MinimalInfoRow(label: "Tier", value: loyalty.currentTier ?? "None")
            MinimalInfoRow(label: "Balance", value: "\(loyalty.pointsBalance ?? 0) pts")
            MinimalInfoRow(label: "Earned", value: "\(loyalty.pointsLifetimeEarned ?? 0) pts")
            MinimalInfoRow(label: "Redeemed", value: "\(loyalty.pointsLifetimeRedeemed ?? 0) pts")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Account Status

    private var accountStatusSection: some View {
        VStack(spacing: 6) {
            MinimalStatusRow(
                label: "ID Verified",
                value: customer.idVerified == true ? "Yes" : "No",
                isActive: customer.idVerified == true
            )
            MinimalStatusRow(
                label: "Status",
                value: customer.isActive == true ? "Active" : "Inactive",
                isActive: customer.isActive == true
            )
            if customer.emailConsent == true || customer.smsConsent == true {
                MinimalInfoRow(
                    label: "Marketing",
                    value: [
                        customer.emailConsent == true ? "Email" : nil,
                        customer.smsConsent == true ? "SMS" : nil
                    ].compactMap { $0 }.joined(separator: ", ")
                )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Orders

    private var ordersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionHeader(title: "Recent Orders")
                Spacer()
                Text("\(customerOrders.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .padding(.trailing, 20)
            }

            if customerOrders.isEmpty {
                Text("No orders yet")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 1) {
                    ForEach(customerOrders.prefix(10)) { order in
                        Button {
                            store.openTab(.order(order))
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(order.displayTitle)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.primary.opacity(0.8))
                                    if let date = order.createdAt {
                                        Text(date, style: .relative)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.primary.opacity(0.4))
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(order.displayTotal)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.primary.opacity(0.7))
                                    Text(order.status?.capitalized ?? "Unknown")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.primary.opacity(0.5))
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.primary.opacity(0.3))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.02))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionHeader(title: "Notes")
                Spacer()
                Button(action: { showAddNoteSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
            }

            if customerNotes.isEmpty {
                Text("No notes")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(customerNotes) { note in
                        MinimalNoteCard(note: note)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Metadata

    private func metadataSection(createdAt: Date) -> some View {
        VStack(spacing: 6) {
            MinimalInfoRow(label: "Customer Since", value: createdAt.formatted(date: .abbreviated, time: .omitted))
            if let updatedAt = customer.updatedAt {
                MinimalInfoRow(label: "Last Updated", value: updatedAt.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Data Loading

    private func loadCustomerDetails() async {
        isLoading = true
        let storeId = store.selectedStore?.id ?? store.defaultStoreId

        do {
            let allOrders = try await store.supabase.fetchOrders(storeId: storeId, limit: 500)
            customerOrders = allOrders.filter { order in
                order.customerId == customer.platformUserId || order.headlessCustomerId == customer.id
            }

            if let platformUserId = customer.platformUserId {
                customerNotes = try await store.supabase.fetchCustomerNotes(customerId: platformUserId, limit: 50)
                customerLoyalty = try await store.supabase.fetchCustomerLoyalty(customerId: platformUserId, storeId: storeId)
            }
        } catch {
            print("[CustomerDetail] Error: \(error)")
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
            print("[CustomerDetail] Error adding note: \(error)")
        }
    }
}

// MARK: - Minimal Supporting Views

private struct MinimalStatCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.8))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.03))
    }
}

private struct MinimalInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MinimalStatusRow: View {
    let label: String
    let value: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 100, alignment: .leading)
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.primary.opacity(isActive ? 0.6 : 0.2))
                    .frame(width: 6, height: 6)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(isActive ? 0.8 : 0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MinimalNoteCard: View {
    let note: CustomerNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.noteType?.capitalized ?? "Note")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.5))
                Spacer()
                if let date = note.createdAt {
                    Text(date, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.3))
                }
            }

            Text(note.note)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
    }
}

private struct MinimalAddNoteSheet: View {
    let customerName: String
    @Binding var noteText: String
    @Binding var noteType: String
    let onSave: () async -> Void

    @Environment(\.dismiss) var dismiss

    let noteTypes = ["general", "support", "billing", "fraud", "vip"]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Add Note")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.8))
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .buttonStyle(.plain)
            }

            // Type picker
            Picker("", selection: $noteType) {
                ForEach(noteTypes, id: \.self) { type in
                    Text(type.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Note text
            TextEditor(text: $noteText)
                .font(.system(size: 12))
                .frame(height: 100)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            // Save button
            Button {
                Task {
                    await onSave()
                    dismiss()
                }
            } label: {
                Text("Save Note")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(noteText.isEmpty ? 0.3 : 0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(noteText.isEmpty ? 0.03 : 0.08))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(noteText.isEmpty)
        }
        .padding(16)
        .frame(width: 360)
    }
}

// MARK: - Legacy Support (keep for backward compatibility)

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary.opacity(0.5))
                Spacer()
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.8))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }
}

struct CustomerContactRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.4))
                .frame(width: 16)
            Text(label)
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 80, alignment: .leading)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.7))
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
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.4))
                .frame(width: 16)
            Text(label)
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 100, alignment: .leading)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.7))
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
                .foregroundStyle(Color.primary.opacity(0.5))
                .frame(width: 100, alignment: .leading)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CustomerSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.primary.opacity(0.4))
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.displayTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.8))
                    if let date = order.createdAt {
                        Text(date, style: .relative)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.primary.opacity(0.4))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(order.displayTotal)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.7))
                    Text(order.status?.capitalized ?? "Unknown")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.5))
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.02))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct CustomerNoteCard: View {
    let note: CustomerNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.noteType?.capitalized ?? "Note")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.5))
                Spacer()
                if let date = note.createdAt {
                    Text(date, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.3))
                }
            }

            Text(note.note)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
    }
}

struct LoyaltyDetailsView: View {
    let loyalty: CustomerLoyalty

    var body: some View {
        VStack(spacing: 6) {
            CustomerInfoRow(label: "Tier", value: loyalty.currentTier ?? "None")
            CustomerInfoRow(label: "Balance", value: "\(loyalty.pointsBalance ?? 0) pts")
            CustomerInfoRow(label: "Earned", value: "\(loyalty.pointsLifetimeEarned ?? 0) pts")
            CustomerInfoRow(label: "Redeemed", value: "\(loyalty.pointsLifetimeRedeemed ?? 0) pts")
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
        VStack(spacing: 16) {
            HStack {
                Text("Add Note for \(customerName)")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.system(size: 12))
                    .buttonStyle(.plain)
            }

            Picker("Type", selection: $noteType) {
                ForEach(noteTypes, id: \.self) { type in
                    Text(type.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)

            TextEditor(text: $noteText)
                .font(.system(size: 12))
                .frame(height: 100)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(6)

            Button {
                Task {
                    await onSave()
                    dismiss()
                }
            } label: {
                Text("Save")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(noteText.isEmpty)
        }
        .padding(16)
        .frame(width: 360)
    }
}

struct CustomerHeader: View {
    let customer: Customer

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 48, height: 48)
                Text(customer.initials)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(customer.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.9))
                    if customer.idVerified == true {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                }

                if let tier = customer.loyaltyTier {
                    Text("\(tier.capitalized) Member")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))
                }

                Text("ID: \(customer.id.uuidString.prefix(8))...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.3))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
