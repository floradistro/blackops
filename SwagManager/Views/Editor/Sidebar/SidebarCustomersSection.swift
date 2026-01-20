import SwiftUI

// MARK: - Sidebar Customers Section
// Following Apple engineering standards and existing patterns

struct SidebarCustomersSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedTiers: Set<String> = ["platinum", "gold"]
    @State private var searchQuery: String = ""

    var body: some View {
        TreeSectionHeader(
            title: "CUSTOMERS",
            isExpanded: $store.sidebarCustomersExpanded,
            count: store.customers.count
        )
        .padding(.top, DesignSystem.Spacing.xxs)

        if store.sidebarCustomersExpanded {
            // Search bar
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                TextField("Search customers...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onChange(of: searchQuery) { _, newValue in
                        if newValue.isEmpty {
                            Task { await store.loadCustomers() }
                        } else {
                            Task { await store.searchCustomers(query: newValue) }
                        }
                    }

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.Colors.surfaceSecondary.opacity(0.3))
            )
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.xs)

            // Quick filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    QuickFilterButton(title: "All", icon: "person.2", isActive: searchQuery.isEmpty && store.customers.count > 0) {
                        searchQuery = ""
                        Task { await store.loadCustomers() }
                    }

                    QuickFilterButton(title: "VIP", icon: "star.fill", isActive: false) {
                        searchQuery = ""
                        Task { await store.loadVIPCustomers() }
                    }

                    QuickFilterButton(title: "Verified", icon: "checkmark.shield", isActive: false) {
                        searchQuery = ""
                        let verified = store.verifiedCustomers
                        store.customers = verified
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
            }
            .padding(.bottom, DesignSystem.Spacing.xs)

            // Stats overview (if available)
            if let stats = store.customerStats, searchQuery.isEmpty {
                VStack(spacing: DesignSystem.Spacing.xxs) {
                    HStack {
                        StatsChip(label: "Total", value: "\(stats.totalCustomers)", icon: "person.2.fill", color: .blue)
                        StatsChip(label: "Active", value: "\(stats.activeCustomers)", icon: "checkmark.circle", color: .green)
                    }
                    HStack {
                        StatsChip(label: "Revenue", value: stats.formattedTotalRevenue, icon: "dollarsign.circle", color: .purple)
                        StatsChip(label: "Orders", value: "\(stats.totalOrders)", icon: "cart.fill", color: .orange)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.sm)
            }

            // Customer groups by tier
            if searchQuery.isEmpty {
                // Platinum Customers
                if !store.platinumCustomers.isEmpty {
                    CustomerTierGroup(
                        title: "Platinum",
                        customers: store.platinumCustomers,
                        color: .purple,
                        icon: "star.circle.fill",
                        isExpanded: expandedTiers.contains("platinum"),
                        onToggle: { toggleTier("platinum") },
                        store: store
                    )
                }

                // Gold Customers
                if !store.goldCustomers.isEmpty {
                    CustomerTierGroup(
                        title: "Gold",
                        customers: store.goldCustomers,
                        color: .yellow,
                        icon: "star.fill",
                        isExpanded: expandedTiers.contains("gold"),
                        onToggle: { toggleTier("gold") },
                        store: store
                    )
                }

                // Silver Customers
                if !store.silverCustomers.isEmpty {
                    CustomerTierGroup(
                        title: "Silver",
                        customers: store.silverCustomers,
                        color: .gray,
                        icon: "star",
                        isExpanded: expandedTiers.contains("silver"),
                        onToggle: { toggleTier("silver") },
                        store: store
                    )
                }

                // Bronze Customers
                if !store.bronzeCustomers.isEmpty {
                    CustomerTierGroup(
                        title: "Bronze",
                        customers: store.bronzeCustomers,
                        color: .orange,
                        icon: "star.leadinghalf.filled",
                        isExpanded: expandedTiers.contains("bronze"),
                        onToggle: { toggleTier("bronze") },
                        store: store
                    )
                }

                // Other/No Tier Customers
                let otherCustomers = store.customers.filter { $0.loyaltyTier == nil || $0.loyaltyTier?.isEmpty == true }
                if !otherCustomers.isEmpty {
                    CustomerTierGroup(
                        title: "Other",
                        customers: otherCustomers,
                        color: .gray,
                        icon: "person",
                        isExpanded: expandedTiers.contains("other"),
                        onToggle: { toggleTier("other") },
                        store: store
                    )
                }
            } else {
                // Search results - flat list
                ForEach(store.customers) { customer in
                    CustomerTreeItem(
                        customer: customer,
                        isSelected: store.selectedCustomer?.id == customer.id,
                        indentLevel: 1,
                        onSelect: { store.selectCustomer(customer) }
                    )
                }
            }

            // Empty state
            if store.customers.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)
                        Text(searchQuery.isEmpty ? "No customers yet" : "No results")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
        }
    }

    private func toggleTier(_ tier: String) {
        withAnimation(DesignSystem.Animation.fast) {
            if expandedTiers.contains(tier) {
                expandedTiers.remove(tier)
            } else {
                expandedTiers.insert(tier)
            }
        }
    }
}

// MARK: - Customer Tier Group

struct CustomerTierGroup: View {
    let title: String
    let customers: [Customer]
    let color: Color
    let icon: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(color)
                        .frame(width: 16)

                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("(\(customers.count))")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(customers.prefix(20)) { customer in
                    CustomerTreeItem(
                        customer: customer,
                        isSelected: store.selectedCustomer?.id == customer.id,
                        indentLevel: 1,
                        onSelect: { store.selectCustomer(customer) }
                    )
                }

                if customers.count > 20 {
                    Button(action: {
                        Task {
                            await store.loadCustomersByTier(tier: title.lowercased())
                        }
                    }) {
                        HStack {
                            Text("Load \(customers.count - 20) more...")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                            Spacer()
                        }
                        .padding(.leading, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Quick Filter Button

struct QuickFilterButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? DesignSystem.Colors.surfaceSecondary : DesignSystem.Colors.surfaceSecondary.opacity(0.3))
            )
            .foregroundColor(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats Chip

struct StatsChip: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color.opacity(0.7))

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 8))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                Text(value)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.1))
        )
    }
}
