import Foundation
import Supabase

// MARK: - EditorStore+Inbox
// AI-powered inbound email inbox management

extension EditorStore {

    // MARK: - Load Inbox Counts

    func loadInboxCounts() async {
        do {
            // Get counts by mailbox for open/awaiting threads
            let threads: [EmailThread] = try await supabase.client
                .from("email_threads")
                .select("id, mailbox, unread_count")
                .in("status", values: ["open", "awaiting_reply"])
                .order("last_message_at", ascending: false)
                .execute()
                .value

            var counts: [String: Int] = [:]
            var totalUnread = 0

            for thread in threads {
                counts[thread.mailbox, default: 0] += 1
                totalUnread += thread.unreadCount
            }

            await MainActor.run {
                self.inboxCounts = counts
                self.inboxTotalUnread = totalUnread
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load inbox counts: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Load Threads

    func loadInboxThreads(mailbox: String? = nil, status: String? = nil) async {
        guard !isLoadingInbox else { return }

        await MainActor.run {
            self.isLoadingInbox = true
        }

        do {
            // Apply filters first, then order/limit (Supabase query chaining requirement)
            var query = supabase.client
                .from("email_threads")
                .select()

            if let mailbox, !mailbox.isEmpty {
                query = query.eq("mailbox", value: mailbox)
            }

            if let status, !status.isEmpty {
                query = query.eq("status", value: status)
            } else {
                // Default: show open and awaiting_reply
                query = query.in("status", values: ["open", "awaiting_reply"])
            }

            let threads: [EmailThread] = try await query
                .order("last_message_at", ascending: false)
                .limit(100)
                .execute()
                .value

            await MainActor.run {
                self.inboxThreads = threads
                self.isLoadingInbox = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load inbox: \(error.localizedDescription)"
                self.isLoadingInbox = false
            }
        }
    }

    // MARK: - Load Thread Messages

    func loadThreadMessages(_ thread: EmailThread) async {
        do {
            let messages: [InboxEmail] = try await supabase.client
                .from("email_inbox")
                .select()
                .eq("thread_id", value: thread.id)
                .order("received_at", ascending: true)
                .execute()
                .value

            await MainActor.run {
                self.selectedThreadMessages = messages
            }

            // Mark unread as read
            let unreadIds = messages
                .filter { $0.isInbound && $0.readAt == nil }
                .map { $0.id }

            if !unreadIds.isEmpty {
                try await supabase.client
                    .from("email_inbox")
                    .update(["status": "read", "read_at": ISO8601DateFormatter().string(from: Date())])
                    .in("id", values: unreadIds.map { $0.uuidString })
                    .execute()

                try await supabase.client
                    .from("email_threads")
                    .update(["unread_count": 0])
                    .eq("id", value: thread.id)
                    .execute()

                // Update local thread unread count
                await MainActor.run {
                    if let idx = self.inboxThreads.firstIndex(where: { $0.id == thread.id }) {
                        // Reload to get updated count
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load messages: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Open Thread (Tab Navigation)

    func openThread(_ thread: EmailThread) {
        selectedThread = thread

        let tabItem = OpenTabItem.thread(thread)

        if let existingIndex = openTabs.firstIndex(where: {
            if case .thread(let t) = $0 { return t.id == thread.id }
            return false
        }) {
            activeTab = openTabs[existingIndex]
        } else {
            openTabs.append(tabItem)
            activeTab = tabItem
        }

        Task {
            await loadThreadMessages(thread)
        }
    }

    // MARK: - Close Thread Tab

    func closeThreadTab(_ thread: EmailThread) {
        openTabs.removeAll { tab in
            if case .thread(let t) = tab {
                return t.id == thread.id
            }
            return false
        }

        if let active = activeTab, case .thread(let t) = active, t.id == thread.id {
            activeTab = openTabs.last
        }

        if selectedThread?.id == thread.id {
            selectedThread = nil
            selectedThreadMessages = []
        }
    }

    // MARK: - Update Thread Status

    func updateThreadStatus(_ thread: EmailThread, status: String) async {
        do {
            try await supabase.client
                .from("email_threads")
                .update(["status": status, "updated_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: thread.id)
                .execute()

            await MainActor.run {
                if let idx = self.inboxThreads.firstIndex(where: { $0.id == thread.id }) {
                    self.inboxThreads.remove(at: idx)
                    // Removed from active list if resolved/closed
                }
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to update thread: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Refresh Inbox

    func refreshInbox() async {
        await MainActor.run {
            self.inboxThreads = []
            self.selectedThreadMessages = []
            self.inboxCounts = [:]
        }
        await loadInboxCounts()
        await loadInboxThreads(mailbox: selectedMailbox.filterValue)
    }
}
