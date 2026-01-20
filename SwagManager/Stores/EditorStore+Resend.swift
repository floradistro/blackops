import Foundation
import Supabase

// MARK: - EditorStore+Resend
// Resend email management extension
// Following Apple engineering standards

extension EditorStore {
    // MARK: - Email Channels (Legacy)

    /// Failed emails (high priority, cross-channel)
    var failedEmails: [ResendEmail] {
        emails.filter { $0.status.lowercased() == "failed" }
    }

    /// Transactional emails (receipts, confirmations, shipping)
    var transactionalEmails: [ResendEmail] {
        emails.filter { $0.emailType.lowercased() == "transactional" && $0.status.lowercased() != "failed" }
    }

    /// Marketing emails (campaigns, newsletters)
    var marketingEmails: [ResendEmail] {
        emails.filter { $0.emailType.lowercased() == "marketing" && $0.status.lowercased() != "failed" }
    }

    // MARK: - Category-Based Filters

    /// Emails grouped by category group
    var emailsByGroup: [EmailCategory.Group: [ResendEmail]] {
        Dictionary(grouping: emails) { email in
            email.categoryGroup ?? .system
        }
    }

    /// Authentication emails (password resets, verifications, etc.)
    var authenticationEmails: [ResendEmail] {
        emails.filter(group: .authentication)
    }

    /// Order emails (confirmations, shipping, delivery, etc.)
    var orderEmails: [ResendEmail] {
        emails.filter(group: .orders)
    }

    /// Receipt and payment emails
    var receiptPaymentEmails: [ResendEmail] {
        emails.filter(group: .receiptsPayments)
    }

    /// Customer support emails
    var supportEmails: [ResendEmail] {
        emails.filter(group: .support)
    }

    /// Marketing campaign emails
    var campaignEmails: [ResendEmail] {
        emails.filter(group: .campaigns)
    }

    /// Loyalty and retention emails
    var loyaltyEmails: [ResendEmail] {
        emails.filter(group: .loyalty)
    }

    /// System emails
    var systemEmails: [ResendEmail] {
        emails.filter(group: .system)
    }

    /// Filter emails by specific category
    func emails(for category: EmailCategory) -> [ResendEmail] {
        emails.filter(category: category)
    }

    /// Filter emails by category group
    func emails(for group: EmailCategory.Group) -> [ResendEmail] {
        emails.filter(group: group)
    }

    // MARK: - Legacy Email Filtering (kept for compatibility)

    var sentEmails: [ResendEmail] {
        emails.filter { $0.status.lowercased() == "sent" }
    }

    var deliveredEmails: [ResendEmail] {
        emails.filter { $0.status.lowercased() == "delivered" }
    }

    var openedEmails: [ResendEmail] {
        emails.filter { $0.status.lowercased() == "opened" }
    }

    var clickedEmails: [ResendEmail] {
        emails.filter { $0.status.lowercased() == "clicked" }
    }

    var bouncedEmails: [ResendEmail] {
        emails.filter { $0.status.lowercased() == "bounced" }
    }

    // MARK: - Load Email Counts (Fast - No Email Data)

    /// Load email counts by category (uses SQL COUNT - no row limits)
    func loadEmailCounts() async {
        guard !isLoadingEmails else {
            NSLog("[EditorStore] ⚠️ Already loading email counts")
            return
        }

        do {
            await MainActor.run {
                self.isLoadingEmails = true
            }

            NSLog("[EditorStore] 📊 Loading email counts using pagination...")

            struct EmailCategory: Codable {
                let category: String?
            }

            var allCategories: [EmailCategory] = []
            var offset = 0
            let batchSize = 1000

            // Pagination loop to get ALL categories
            while true {
                NSLog("[EditorStore] 📊 Fetching batch at offset \(offset)...")

                let batch: [EmailCategory]
                if let storeId = selectedStore?.id {
                    NSLog("[EditorStore] 📊 Querying for store: \(storeId)")
                    batch = try await supabase.client
                        .from("email_sends")
                        .select("category")
                        .eq("store_id", value: storeId.uuidString)
                        .order("created_at", ascending: false)
                        .range(from: offset, to: offset + batchSize - 1)
                        .execute()
                        .value
                } else {
                    NSLog("[EditorStore] 📊 Querying all email_sends (no store filter)")
                    batch = try await supabase.client
                        .from("email_sends")
                        .select("category")
                        .order("created_at", ascending: false)
                        .range(from: offset, to: offset + batchSize - 1)
                        .execute()
                        .value
                }

                NSLog("[EditorStore] 📊 Received batch: \(batch.count) rows")

                if batch.isEmpty {
                    NSLog("[EditorStore] 📊 Empty batch - stopping pagination")
                    break
                }

                allCategories.append(contentsOf: batch)
                offset += batchSize

                NSLog("[EditorStore] 📊 Total categories loaded: \(allCategories.count)")

                // Safety break if batch not full (last batch)
                if batch.count < batchSize {
                    NSLog("[EditorStore] 📊 Last batch (size: \(batch.count)) - stopping")
                    break
                }
            }

            NSLog("[EditorStore] 📊 Pagination complete. Total categories: \(allCategories.count)")

            // Count by category
            var categoryCounts: [String: Int] = [:]
            for item in allCategories {
                if let cat = item.category {
                    categoryCounts[cat, default: 0] += 1
                } else {
                    categoryCounts["uncategorized", default: 0] += 1
                }
            }

            await MainActor.run {
                self.emailTotalCount = allCategories.count
                self.emailCategoryCounts = categoryCounts
                self.isLoadingEmails = false
                NSLog("[EditorStore] ✅ Loaded counts for \(allCategories.count) emails across \(categoryCounts.count) categories")
            }

        } catch {
            await MainActor.run {
                self.error = "Failed to load email counts: \(error.localizedDescription)"
                self.isLoadingEmails = false
                NSLog("[EditorStore] ❌ Error loading counts: \(error)")
                NSLog("[EditorStore] ❌ Error details: \(String(describing: error))")

                // Print stack trace if available
                if let error = error as NSError? {
                    NSLog("[EditorStore] ❌ Error domain: \(error.domain)")
                    NSLog("[EditorStore] ❌ Error code: \(error.code)")
                    NSLog("[EditorStore] ❌ Error userInfo: \(error.userInfo)")
                }
            }
        }
    }

    // MARK: - Load Emails for Category (Lazy Load)

    /// Load actual emails for a specific category (lazy load when category expanded)
    func loadEmailsForCategory(_ category: String?) async {
        // Check if already loaded
        let categoryKey = category ?? "uncategorized"
        if loadedCategories.contains(categoryKey) {
            NSLog("[EditorStore] ℹ️ Category '\(categoryKey)' already loaded")
            return
        }

        do {
            NSLog("[EditorStore] 📧 Loading emails for category: \(categoryKey)")

            let response: [ResendEmail]
            if let storeId = selectedStore?.id {
                if let category = category {
                    response = try await supabase.client
                        .from("email_sends")
                        .select()
                        .eq("store_id", value: storeId.uuidString)
                        .eq("category", value: category)
                        .order("created_at", ascending: false)
                        .limit(10000) // Very high limit to get all
                        .execute()
                        .value
                } else {
                    // Uncategorized (NULL category) - load all then filter client-side
                    let allEmails: [ResendEmail] = try await supabase.client
                        .from("email_sends")
                        .select()
                        .eq("store_id", value: storeId.uuidString)
                        .order("created_at", ascending: false)
                        .limit(10000)
                        .execute()
                        .value
                    response = allEmails.filter { $0.category == nil }
                }
            } else {
                if let category = category {
                    response = try await supabase.client
                        .from("email_sends")
                        .select()
                        .eq("category", value: category)
                        .order("created_at", ascending: false)
                        .limit(10000)
                        .execute()
                        .value
                } else {
                    // Uncategorized (NULL category) - load all then filter client-side
                    let allEmails: [ResendEmail] = try await supabase.client
                        .from("email_sends")
                        .select()
                        .order("created_at", ascending: false)
                        .limit(10000)
                        .execute()
                        .value
                    response = allEmails.filter { $0.category == nil }
                }
            }

            await MainActor.run {
                // Remove old emails from this category (in case of refresh)
                self.emails.removeAll { email in
                    (email.category ?? "uncategorized") == categoryKey
                }

                // Add new emails
                self.emails.append(contentsOf: response)
                self.loadedCategories.insert(categoryKey)

                NSLog("[EditorStore] ✅ Loaded \(response.count) emails for '\(categoryKey)'")
            }

        } catch {
            await MainActor.run {
                self.error = "Failed to load emails for category: \(error.localizedDescription)"
                NSLog("[EditorStore] ❌ Error loading category '\(categoryKey)': \(error)")
            }
        }
    }

    /// Load emails for a category group (authentication, orders, etc.)
    func loadEmailsForGroup(_ group: EmailCategory.Group) async {
        let categories = group.categories.map { $0.rawValue }

        for category in categories {
            await loadEmailsForCategory(category)
        }
    }

    /// Refresh emails (reload counts)
    func refreshEmails() async {
        await MainActor.run {
            self.emails = []
            self.loadedCategories = []
            self.emailCategoryCounts = [:]
            self.emailTotalCount = 0
        }
        await loadEmailCounts()
    }

    // MARK: - Open Email

    func openEmail(_ email: ResendEmail) {
        selectedEmail = email

        // Add to or update tabs
        let tabItem = OpenTabItem.email(email)

        if let existingIndex = openTabs.firstIndex(where: {
            if case .email(let e) = $0 { return e.id == email.id }
            return false
        }) {
            // Tab already exists, just activate it
            activeTab = openTabs[existingIndex]
        } else {
            // Add new tab
            openTabs.append(tabItem)
            activeTab = tabItem
        }
    }

    // MARK: - Close Email Tab

    func closeEmailTab(_ email: ResendEmail) {
        openTabs.removeAll { tab in
            if case .email(let e) = tab {
                return e.id == email.id
            }
            return false
        }

        if let active = activeTab, case .email(let e) = active, e.id == email.id {
            activeTab = openTabs.last
        }

        if selectedEmail?.id == email.id {
            selectedEmail = nil
        }
    }

}
