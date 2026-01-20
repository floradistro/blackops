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

    }

    var filteredCustomers: [Customer] {
        let segmentFiltered: [Customer]
        switch selectedSegment {
        case .all: segmentFiltered = store.customers
        case .vip: segmentFiltered = store.customers.filter { ($0.lifetimeValue ?? 0) >= 1000 || $0.idVerified == true }
        case .platinum: segmentFiltered = store.platinumCustomers
        case .gold: segmentFiltered = store.goldCustomers
        case .silver: segmentFiltered = store.silverCustomers
        case .bronze: segmentFiltered = store.bronzeCustomers
        case .verified: segmentFiltered = store.verifiedCustomers
        case .active: segmentFiltered = store.activeCustomers
        }

        // Apply search filter
        if searchQuery.isEmpty {
            return segmentFiltered
        }

        let query = searchQuery.lowercased()
        return segmentFiltered.filter { customer in
            customer.displayName.lowercased().contains(query) ||
            customer.email?.lowercased().contains(query) == true ||
            customer.phone?.contains(query) == true
        }
    }

    var filteredGroupedCustomers: [(letter: String, customers: [Customer])] {
        // Only show letters that have customers - don't pre-sort all customers
        let allLetters = Set(filteredCustomers.compactMap { customer -> String? in
            let name = customer.displayName.uppercased()
            if let first = name.first, first.isLetter {
                return String(first)
            }
            return "#"
        })

        return allLetters.sorted().map { letter in
            (letter: letter, customers: []) // Empty array - load on demand
        }
    }

    var body: some View {
        TreeSectionHeader(
            title: "CUSTOMERS",
            isExpanded: $store.sidebarCustomersExpanded,
            count: filteredCustomers.count
        )
        .padding(.top, DesignSystem.Spacing.xxs)
        .onAppear {
            if store.customers.isEmpty {
                Task {
                    await store.loadCustomers()
                }
            }
        }

        if store.sidebarCustomersExpanded {
            // Simple segment picker
            Picker("", selection: $selectedSegment) {
                ForEach(CustomerSegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
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
                ForEach(filteredCustomers) { customer in
                    CustomerTreeItem(
                        customer: customer,
                        isSelected: store.selectedCustomer?.id == customer.id,
                        indentLevel: 0,
                        onSelect: { store.selectCustomer(customer) }
                    )
                }
            }

            // Empty state
            if filteredCustomers.isEmpty {
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

    private var customersForLetter: [Customer] {
        store.customersForLetter(letter).sorted { $0.displayName < $1.displayName }
    }

    private var count: Int {
        store.customers.filter { customer in
            let name = customer.displayName.uppercased()
            if letter == "#" {
                return name.first?.isLetter == false
            }
            return name.hasPrefix(letter)
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 16)

                    Text(letter)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("(\(count))")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(customersForLetter.prefix(100)) { customer in
                    CustomerTreeItem(
                        customer: customer,
                        isSelected: store.selectedCustomer?.id == customer.id,
                        indentLevel: 1,
                        onSelect: { store.selectCustomer(customer) }
                    )
                }

                if customersForLetter.count > 100 {
                    Text("+ \(customersForLetter.count - 100) more")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .padding(.leading, 32)
                        .padding(.vertical, 4)
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
