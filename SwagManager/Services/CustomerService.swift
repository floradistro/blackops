import Foundation
import Supabase

@MainActor
class CustomerService {
    let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Fetch Customers

    /// Fetch all customers for a store from the unified view with pagination
    /// Apple-style: Uses limit/offset for simple pagination, performant for large datasets
    func fetchCustomers(storeId: UUID, limit: Int = 50, offset: Int = 0) async throws -> [Customer] {
        let response = try await client
            .from("v_store_customers")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .range(from: offset, to: offset + limit - 1)
            .execute()

        let customers = try JSONDecoder.supabaseDecoder.decode([Customer].self, from: response.data)
        return customers
    }

    /// Fetch a single customer by ID
    func fetchCustomer(id: UUID) async throws -> Customer {
        let response = try await client
            .from("v_store_customers")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()

        let customer = try JSONDecoder.supabaseDecoder.decode(Customer.self, from: response.data)
        return customer
    }

    /// Search customers by name, email, or phone
    func searchCustomers(storeId: UUID, query: String, limit: Int = 50) async throws -> [Customer] {
        // Use ilike for case-insensitive search
        let response = try await client
            .from("v_store_customers")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .or("first_name.ilike.%\(query)%,last_name.ilike.%\(query)%,email.ilike.%\(query)%,phone.ilike.%\(query)%")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()

        let customers = try JSONDecoder.supabaseDecoder.decode([Customer].self, from: response.data)
        return customers
    }

    /// Fetch customers by loyalty tier
    func fetchCustomersByTier(storeId: UUID, tier: String, limit: Int = 100) async throws -> [Customer] {
        let response = try await client
            .from("v_store_customers")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .eq("loyalty_tier", value: tier)
            .order("total_spent", ascending: false)
            .limit(limit)
            .execute()

        let customers = try JSONDecoder.supabaseDecoder.decode([Customer].self, from: response.data)
        return customers
    }

    /// Fetch VIP customers (high lifetime value or verified)
    func fetchVIPCustomers(storeId: UUID, minLTV: Decimal = 1000, limit: Int = 50) async throws -> [Customer] {
        let response = try await client
            .from("v_store_customers")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .or("lifetime_value.gte.\(minLTV),id_verified.eq.true")
            .order("lifetime_value", ascending: false)
            .limit(limit)
            .execute()

        let customers = try JSONDecoder.supabaseDecoder.decode([Customer].self, from: response.data)
        return customers
    }

    /// Fetch recently active customers
    func fetchRecentCustomers(storeId: UUID, days: Int = 30, limit: Int = 50) async throws -> [Customer] {
        let response = try await client
            .from("v_store_customers")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .order("updated_at", ascending: false)
            .limit(limit)
            .execute()

        let customers = try JSONDecoder.supabaseDecoder.decode([Customer].self, from: response.data)
        return customers
    }

    // MARK: - Customer Notes

    /// Fetch notes for a customer
    func fetchCustomerNotes(customerId: UUID, limit: Int = 50) async throws -> [CustomerNote] {
        let response = try await client
            .from("customer_notes")
            .select()
            .eq("customer_id", value: customerId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()

        let notes = try JSONDecoder.supabaseDecoder.decode([CustomerNote].self, from: response.data)
        return notes
    }

    /// Create a new customer note
    func createCustomerNote(customerId: UUID, note: String, noteType: String = "general", isCustomerVisible: Bool = false) async throws -> CustomerNote {
        struct NoteInsert: Encodable {
            let customer_id: String
            let note: String
            let note_type: String
            let is_customer_visible: Bool
        }

        let newNote = NoteInsert(
            customer_id: customerId.uuidString,
            note: note,
            note_type: noteType,
            is_customer_visible: isCustomerVisible
        )

        let response = try await client
            .from("customer_notes")
            .insert(newNote)
            .select()
            .single()
            .execute()

        let createdNote = try JSONDecoder.supabaseDecoder.decode(CustomerNote.self, from: response.data)
        return createdNote
    }

    // MARK: - Customer Loyalty

    /// Fetch loyalty details for a customer
    func fetchCustomerLoyalty(customerId: UUID, storeId: UUID) async throws -> CustomerLoyalty? {
        let response = try await client
            .from("customer_loyalty")
            .select()
            .eq("customer_id", value: customerId.uuidString)
            .eq("store_id", value: storeId.uuidString)
            .limit(1)
            .execute()

        let loyalties = try? JSONDecoder.supabaseDecoder.decode([CustomerLoyalty].self, from: response.data)
        return loyalties?.first
    }

    // MARK: - Customer Stats

    /// Get customer statistics for a store
    func fetchCustomerStats(storeId: UUID) async throws -> CustomerStats {
        let response = try await client
            .from("v_store_customers")
            .select("id, total_spent, total_orders, loyalty_tier, is_active")
            .eq("store_id", value: storeId.uuidString)
            .execute()

        struct CustomerStat: Codable {
            var totalSpent: Decimal?
            var totalOrders: Int?
            var loyaltyTier: String?
            var isActive: Bool?

            enum CodingKeys: String, CodingKey {
                case totalSpent = "total_spent"
                case totalOrders = "total_orders"
                case loyaltyTier = "loyalty_tier"
                case isActive = "is_active"
            }
        }

        let stats = try JSONDecoder.supabaseDecoder.decode([CustomerStat].self, from: response.data)

        var totalCustomers = stats.count
        var activeCustomers = stats.filter { $0.isActive == true }.count
        var totalRevenue: Decimal = 0
        var totalOrders = 0
        var tierCounts: [String: Int] = [:]

        for stat in stats {
            totalRevenue += stat.totalSpent ?? 0
            totalOrders += stat.totalOrders ?? 0
            if let tier = stat.loyaltyTier {
                tierCounts[tier, default: 0] += 1
            }
        }

        let avgOrderValue = totalOrders > 0 ? totalRevenue / Decimal(totalOrders) : 0

        return CustomerStats(
            totalCustomers: totalCustomers,
            activeCustomers: activeCustomers,
            totalRevenue: totalRevenue,
            totalOrders: totalOrders,
            averageOrderValue: avgOrderValue,
            tierCounts: tierCounts
        )
    }
}

// MARK: - Customer Stats Model

struct CustomerStats {
    let totalCustomers: Int
    let activeCustomers: Int
    let totalRevenue: Decimal
    let totalOrders: Int
    let averageOrderValue: Decimal
    let tierCounts: [String: Int]

    var formattedTotalRevenue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: totalRevenue as NSDecimalNumber) ?? "$0.00"
    }

    var formattedAverageOrderValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: averageOrderValue as NSDecimalNumber) ?? "$0.00"
    }
}
