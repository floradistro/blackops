import Foundation

// MARK: - EditorStore+Customers
// Customer management functionality for EditorStore

extension EditorStore {
    // MARK: - Load Customers

    func loadCustomers() async {
        let storeId = selectedStore?.id ?? defaultStoreId

        do {
            await MainActor.run { isLoadingCustomers = true }

            // Load first batch immediately for instant UI
            let firstBatch = try await supabase.fetchCustomers(storeId: storeId, limit: 100, offset: 0)
            await MainActor.run {
                customers = firstBatch
                isLoadingCustomers = false
            }
            print("✅ Loaded initial \(customers.count) customers")

            // Load stats in background
            Task {
                let stats = try await supabase.fetchCustomerStats(storeId: storeId)
                customerStats = stats
            }

            // Load remaining customers in background
            Task {
                var allCustomers = firstBatch
                var offset = 100
                let batchSize = 1000

                while true {
                    let batch = try await supabase.fetchCustomers(storeId: storeId, limit: batchSize, offset: offset)
                    if batch.isEmpty { break }
                    allCustomers.append(contentsOf: batch)
                    customers = allCustomers
                    offset += batchSize

                    if batch.count < batchSize { break }
                }
                print("✅ Loaded all \(customers.count) customers")
            }
        } catch {
            print("❌ Error loading customers: \(error)")
            await MainActor.run {
                self.error = "Failed to load customers: \(error.localizedDescription)"
                isLoadingCustomers = false
            }
        }
    }

    func searchCustomers(query: String) async {
        let storeId = selectedStore?.id ?? defaultStoreId

        guard !query.isEmpty else {
            await loadCustomers()
            return
        }

        do {
            isLoading = true
            customerSearchQuery = query
            let results = try await supabase.searchCustomers(storeId: storeId, query: query, limit: 100)
            customers = results
            print("✅ Found \(customers.count) customers matching '\(query)'")
        } catch {
            print("❌ Error searching customers: \(error)")
            self.error = "Failed to search customers: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func loadVIPCustomers() async {
        let storeId = selectedStore?.id ?? defaultStoreId

        do {
            isLoading = true
            let vipCustomers = try await supabase.fetchVIPCustomers(storeId: storeId, limit: 100)
            customers = vipCustomers
            print("✅ Loaded \(customers.count) VIP customers")
        } catch {
            print("❌ Error loading VIP customers: \(error)")
            self.error = "Failed to load VIP customers: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func loadCustomersByTier(tier: String) async {
        let storeId = selectedStore?.id ?? defaultStoreId

        do {
            isLoading = true
            let tierCustomers = try await supabase.fetchCustomersByTier(storeId: storeId, tier: tier, limit: 100)
            customers = tierCustomers
            print("✅ Loaded \(customers.count) \(tier) tier customers")
        } catch {
            print("❌ Error loading tier customers: \(error)")
            self.error = "Failed to load tier customers: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Select Customer

    func selectCustomer(_ customer: Customer) {
        selectedCustomer = customer
        openTab(.customer(customer))
    }

    func openCustomer(_ customer: Customer) {
        selectedCustomer = customer
        openTab(.customer(customer))
    }

    // MARK: - Refresh Customer

    func refreshCustomer(id: UUID) async {
        do {
            let customer = try await supabase.fetchCustomer(id: id)

            // Update in list
            if let index = customers.firstIndex(where: { $0.id == id }) {
                customers[index] = customer
            }

            // Update selection
            if selectedCustomer?.id == id {
                selectedCustomer = customer
            }

            // Update open tab
            if let tabIndex = openTabs.firstIndex(where: {
                if case .customer(let c) = $0, c.id == id {
                    return true
                }
                return false
            }) {
                openTabs[tabIndex] = .customer(customer)

                if case .customer(let c) = activeTab, c.id == id {
                    activeTab = .customer(customer)
                }
            }

            print("✅ Refreshed customer: \(customer.displayName)")
        } catch {
            print("❌ Error refreshing customer: \(error)")
            self.error = "Failed to refresh customer: \(error.localizedDescription)"
        }
    }

    // MARK: - Customer Filtering Helpers

    var activeCustomers: [Customer] {
        customers.filter { $0.isActive == true }
    }

    var verifiedCustomers: [Customer] {
        customers.filter { $0.idVerified == true }
    }

    func customersByTier(_ tier: String) -> [Customer] {
        customers.filter { $0.loyaltyTier?.lowercased() == tier.lowercased() }
    }

    var platinumCustomers: [Customer] {
        customersByTier("platinum")
    }

    var goldCustomers: [Customer] {
        customersByTier("gold")
    }

    var silverCustomers: [Customer] {
        customersByTier("silver")
    }

    var bronzeCustomers: [Customer] {
        customersByTier("bronze")
    }

    // MARK: - Alphabetical Grouping (Apple Contacts style)

    var customersGroupedByFirstLetter: [(letter: String, customers: [Customer])] {
        let grouped = Dictionary(grouping: customers) { customer -> String in
            let name = customer.displayName.uppercased()
            if let first = name.first, first.isLetter {
                return String(first)
            }
            return "#"
        }

        return grouped.sorted { $0.key < $1.key }.map { (letter: $0.key, customers: $0.value.sorted { $0.displayName < $1.displayName }) }
    }

    func customersForLetter(_ letter: String) -> [Customer] {
        customers.filter { customer in
            let name = customer.displayName.uppercased()
            if letter == "#" {
                return name.first?.isLetter == false
            }
            return name.hasPrefix(letter.uppercased())
        }.sorted { $0.displayName < $1.displayName }
    }
}
