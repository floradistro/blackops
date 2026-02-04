import Foundation
import Combine

// MARK: - Order Tree Store
// Manages lazy-loading tree structure for orders: Year > Month > Day > Orders
// Only fetches actual order data when a specific day is expanded

@MainActor
class OrderTreeStore: ObservableObject {
    private let supabase = SupabaseService.shared

    // MARK: - State

    @Published var totalCount: Int = 0
    @Published var isLoadingTotal: Bool = false

    // Year level
    @Published var yearCounts: [Int: Int] = [:]  // year -> count
    @Published var expandedYears: Set<Int> = []
    @Published var isLoadingYears: Bool = false

    // Month level (keyed by year)
    @Published var monthCounts: [Int: [Int: Int]] = [:]  // year -> (month -> count)
    @Published var expandedMonths: Set<String> = []  // "2026-01"
    @Published var loadingMonths: Set<Int> = []  // years being loaded

    // Day level (keyed by year-month)
    @Published var dayCounts: [String: [Int: Int]] = [:]  // "2026-01" -> (day -> count)
    @Published var expandedDays: Set<String> = []  // "2026-01-24"
    @Published var loadingDays: Set<String> = []  // year-months being loaded

    // Order level (keyed by date)
    @Published var dayOrders: [String: [Order]] = [:]  // "2026-01-24" -> orders
    @Published var loadingOrders: Set<String> = []  // dates being loaded

    // Active orders (always loaded for quick access)
    @Published var activeOrders: [Order] = []
    @Published var isLoadingActive: Bool = false

    // Current store
    private var storeId: UUID?

    // MARK: - Computed Properties

    var sortedYears: [Int] {
        yearCounts.keys.sorted(by: >)  // Most recent first
    }

    func sortedMonths(for year: Int) -> [Int] {
        (monthCounts[year] ?? [:]).keys.sorted(by: >)  // Most recent first
    }

    func sortedDays(for year: Int, month: Int) -> [Int] {
        let key = String(format: "%04d-%02d", year, month)
        return (dayCounts[key] ?? [:]).keys.sorted(by: >)  // Most recent first
    }

    func orders(for year: Int, month: Int, day: Int) -> [Order] {
        let key = String(format: "%04d-%02d-%02d", year, month, day)
        return dayOrders[key] ?? []
    }

    // MARK: - Month/Day Keys

    func monthKey(_ year: Int, _ month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }

    func dayKey(_ year: Int, _ month: Int, _ day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    // MARK: - Load Methods

    func loadForStore(_ storeId: UUID) async {
        self.storeId = storeId

        // Load total count and active orders in parallel
        isLoadingTotal = true
        isLoadingActive = true
        isLoadingYears = true

        async let totalTask: () = loadTotalCount()
        async let activeTask: () = loadActiveOrders()
        async let yearsTask: () = loadYearCounts()

        await totalTask
        await activeTask
        await yearsTask

        isLoadingTotal = false
        isLoadingActive = false
        isLoadingYears = false

        // Auto-expand current year
        let currentYear = Calendar.current.component(.year, from: Date())
        if yearCounts[currentYear] != nil {
            await toggleYear(currentYear)
        }
    }

    private func loadTotalCount() async {
        guard let storeId = storeId else { return }
        do {
            totalCount = try await supabase.fetchTotalOrderCount(storeId: storeId)
        } catch {
        }
    }

    private func loadActiveOrders() async {
        guard let storeId = storeId else { return }
        do {
            activeOrders = try await supabase.fetchActiveOrders(storeId: storeId)
        } catch {
        }
    }

    private func loadYearCounts() async {
        guard let storeId = storeId else { return }
        do {
            yearCounts = try await supabase.fetchOrderCountsByYear(storeId: storeId)
        } catch {
        }
    }

    // MARK: - Toggle Expand/Collapse

    func toggleYear(_ year: Int) async {
        if expandedYears.contains(year) {
            expandedYears.remove(year)
        } else {
            expandedYears.insert(year)

            // Load months if not already loaded
            if monthCounts[year] == nil {
                await loadMonthCounts(year: year)
            }
        }
    }

    func toggleMonth(_ year: Int, _ month: Int) async {
        let key = monthKey(year, month)

        if expandedMonths.contains(key) {
            expandedMonths.remove(key)
        } else {
            expandedMonths.insert(key)

            // Load days if not already loaded
            if dayCounts[key] == nil {
                await loadDayCounts(year: year, month: month)
            }
        }
    }

    func toggleDay(_ year: Int, _ month: Int, _ day: Int) async {
        let key = dayKey(year, month, day)

        if expandedDays.contains(key) {
            expandedDays.remove(key)
        } else {
            expandedDays.insert(key)

            // Load orders if not already loaded
            if dayOrders[key] == nil {
                await loadDayOrders(year: year, month: month, day: day)
            }
        }
    }

    // MARK: - Load Specific Levels

    private func loadMonthCounts(year: Int) async {
        guard let storeId = storeId else { return }
        loadingMonths.insert(year)
        defer { loadingMonths.remove(year) }

        do {
            let counts = try await supabase.fetchOrderCountsByMonth(storeId: storeId, year: year)
            monthCounts[year] = counts
        } catch {
        }
    }

    private func loadDayCounts(year: Int, month: Int) async {
        guard let storeId = storeId else { return }
        let key = monthKey(year, month)
        loadingDays.insert(key)
        defer { loadingDays.remove(key) }

        do {
            let counts = try await supabase.fetchOrderCountsByDay(storeId: storeId, year: year, month: month)
            dayCounts[key] = counts
        } catch {
        }
    }

    private func loadDayOrders(year: Int, month: Int, day: Int) async {
        guard let storeId = storeId else { return }
        let key = dayKey(year, month, day)
        loadingOrders.insert(key)
        defer { loadingOrders.remove(key) }

        do {
            let orders = try await supabase.fetchOrdersForDate(storeId: storeId, year: year, month: month, day: day)
            dayOrders[key] = orders
        } catch {
        }
    }

    // MARK: - Refresh

    func refresh() async {
        guard let storeId = storeId else { return }

        // Clear cached data
        monthCounts.removeAll()
        dayCounts.removeAll()
        dayOrders.removeAll()

        // Keep expanded states but reload data
        await loadForStore(storeId)

        // Reload any expanded months
        for year in expandedYears {
            await loadMonthCounts(year: year)
        }

        // Reload any expanded days
        for monthKey in expandedMonths {
            let parts = monthKey.split(separator: "-")
            if parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) {
                await loadDayCounts(year: year, month: month)
            }
        }

        // Reload any expanded order days
        for dayKey in expandedDays {
            let parts = dayKey.split(separator: "-")
            if parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) {
                await loadDayOrders(year: year, month: month, day: day)
            }
        }
    }

    // MARK: - Active Orders Filtering

    var pendingOrders: [Order] {
        activeOrders.filter { $0.status == "pending" }
    }

    var processingOrders: [Order] {
        activeOrders.filter { ["confirmed", "preparing", "packing", "packed"].contains($0.status ?? "") }
    }

    var readyOrders: [Order] {
        activeOrders.filter { ["ready", "ready_to_ship"].contains($0.status ?? "") }
    }

    // MARK: - Helpers

    func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let date = Calendar.current.date(from: DateComponents(month: month))!
        return formatter.string(from: date)
    }

    func shortMonthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let date = Calendar.current.date(from: DateComponents(month: month))!
        return formatter.string(from: date)
    }

    func dayOfWeek(_ year: Int, _ month: Int, _ day: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
        return formatter.string(from: date)
    }
}
