import Foundation
import Supabase

// MARK: - EditorStore+Resend
// Resend email management extension
// Following Apple engineering standards

extension EditorStore {
    // MARK: - Email Channels

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

    // MARK: - Load Emails

    func loadEmails() async {
        do {
            NSLog("[EditorStore] Loading emails... selectedStore: \(selectedStore?.id.uuidString ?? "nil")")

            // Build query with optional store filter
            let response: [ResendEmail]

            if let storeId = selectedStore?.id {
                NSLog("[EditorStore] Querying email_sends for store: \(storeId)")
                response = try await supabase.client
                    .from("email_sends")
                    .select()
                    .eq("store_id", value: storeId.uuidString)
                    .order("created_at", ascending: false)
                    .limit(200)
                    .execute()
                    .value
            } else {
                NSLog("[EditorStore] Querying all email_sends (no store filter)")
                response = try await supabase.client
                    .from("email_sends")
                    .select()
                    .order("created_at", ascending: false)
                    .limit(200)
                    .execute()
                    .value
            }

            await MainActor.run {
                self.emails = response
                NSLog("[EditorStore] ✅ Loaded \(response.count) emails")
                if response.isEmpty {
                    NSLog("[EditorStore] ⚠️ No emails found in database")
                }
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load emails: \(error.localizedDescription)"
                NSLog("[EditorStore] ❌ Error loading emails: \(error)")
            }
        }
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
