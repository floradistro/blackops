import SwiftUI

// MARK: - Sidebar Customers Section
// Following Apple engineering standards and existing patterns

struct SidebarCustomersSection: View {
    @ObservedObject var store: EditorStore
    @State private var expandedTiers: Set<String> = []
    @State private var searchQuery: String = ""
    @State private var selectedSegment: CustomerSegment = .all

    enum CustomerSegment: String, CaseIterable {
        case all = "All"
        case vip = "VIP"
        case platinum = "Platinum"
        case gold = "Gold"
        case silver = "Silver"
        case bronze = "Bronze"
        case verified = "Verified"
        case active = "Active"

        var icon: String {
            switch self {
            case .all: return "person.2"
            case .vip: return "star.fill"
            case .platinum: return "star.circle.fill"
            case .gold: return "star.fill"
            case .silver: return "star"
            case .bronze: return "star.leadinghalf.filled"
            case .verified: return "checkmark.shield"
            case .active: return "checkmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .all: return .blue
            case .vip: return .purple
            case .platinum: return .purple
            case .gold: return .yellow
            case .silver: return .gray
            case .bronze: return .orange
            case .verified: return .green
            case .active: return .green
            }
        }
    }

    var filteredCustomers: [Customer] {
        switch selectedSegment {
        case .all: return store.customers
        case .vip: return store.customers.filter { ($0.lifetimeValue ?? 0) >= 1000 || $0.idVerified == true }
        case .platinum: return store.platinumCustomers
        case .gold: return store.goldCustomers
        case .silver: return store.silverCustomers
        case .bronze: return store.bronzeCustomers
        case .verified: return store.verifiedCustomers
        case .active: return store.activeCustomers
        }
    }

    var filteredGroupedCustomers: [(letter: String, customers: [Customer])] {
        let grouped = Dictionary(grouping: filteredCustomers) { customer -> String in
            let name = customer.displayName.uppercased()
            if let first = name.first, first.isLetter {
                return String(first)
            }
            return "#"
        }
        return grouped.sorted { $0.key < $1.key }.map { (letter: $0.key, customers: $0.value.sorted { $0.displayName < $1.displayName }) }
    }

    var body: some View {
        TreeSectionHeader(
            title: "CUSTOMERS",
            isExpanded: $store.sidebarCustomersExpanded,
            count: filteredCustomers.count
        )
        .padding(.top, DesignSystem.Spacing.xxs)

        if store.sidebarCustomersExpanded {
            // Segment selector dropdown
            Menu {
                ForEach(CustomerSegment.allCases, id: \.self) { segment in
                    Button {
                        withAnimation(DesignSystem.Animation.fast) {
                            selectedSegment = segment
                        }
                    } label: {
                        Label(segment.rawValue, systemImage: segment.icon)
                    }
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: selectedSegment.icon)
                        .font(.system(size: 11))
                        .foregroundColor(selectedSegment.color)

                    Text(selectedSegment.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedSegment.color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(selectedSegment.color.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.xs)

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

            // Customer groups alphabetically (Apple Contacts style)
            if searchQuery.isEmpty {
                // Group by first letter - using filtered customers
                ForEach(filteredGroupedCustomers, id: \.letter) { group in
                    CustomerAlphabetGroup(
                        letter: group.letter,
                        customers: group.customers,
                        isExpanded: expandedTiers.contains(group.letter),
                        onToggle: { toggleTier(group.letter) },
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

// MARK: - Customer Alphabet Group (Apple Contacts style)

struct CustomerAlphabetGroup: View {
    let letter: String
    let customers: [Customer]
    let isExpanded: Bool
    let onToggle: () -> Void
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    // Letter badge
                    Text(letter)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(Color.blue.gradient)
                        )

                    Text("\(customers.count) contacts")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

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
                // Apple-style: LazyVStack for virtualization
                LazyVStack(spacing: 0) {
                    ForEach(customers) { customer in
                        CustomerTreeItem(
                            customer: customer,
                            isSelected: store.selectedCustomer?.id == customer.id,
                            indentLevel: 1,
                            onSelect: { store.selectCustomer(customer) }
                        )
                        .id(customer.id)
                    }
                }
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
                // Apple-style: LazyVStack for virtualization - only renders visible items
                LazyVStack(spacing: 0) {
                    ForEach(customers) { customer in
                        CustomerTreeItem(
                            customer: customer,
                            isSelected: store.selectedCustomer?.id == customer.id,
                            indentLevel: 1,
                            onSelect: { store.selectCustomer(customer) }
                        )
                        .id(customer.id)
                    }
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
