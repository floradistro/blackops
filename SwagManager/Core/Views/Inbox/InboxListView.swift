import SwiftUI

// MARK: - Inbox List View
// Thread list with mailbox filtering for AI-powered email inbox

struct InboxListView: View {
    @Environment(\.editorStore) private var store
    @Binding var selection: SDSidebarItem?
    @State private var searchText = ""

    private var filteredThreads: [EmailThread] {
        let threads = store.inboxThreads
        if searchText.isEmpty { return threads }
        return threads.filter { thread in
            thread.displaySubject.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            // Mailbox filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(InboxMailbox.allCases) { mailbox in
                        MailboxChip(
                            mailbox: mailbox,
                            count: mailbox == .all
                                ? store.inboxThreads.count
                                : store.inboxCounts[mailbox.rawValue] ?? 0,
                            isSelected: store.selectedMailbox == mailbox
                        ) {
                            store.selectedMailbox = mailbox
                            Task {
                                await store.loadInboxThreads(mailbox: mailbox.filterValue)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            .listRowSeparator(.hidden)

            if filteredThreads.isEmpty && !store.isLoadingInbox {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "tray",
                    description: Text("Inbound emails will appear here")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredThreads) { thread in
                    NavigationLink(value: SDSidebarItem.inboxThread(thread.id)) {
                        ThreadListRow(thread: thread)
                    }
                }
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Search conversations")
        .navigationTitle("Inbox")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Open") {
                        Task { await store.loadInboxThreads(status: "open") }
                    }
                    Button("Awaiting Reply") {
                        Task { await store.loadInboxThreads(status: "awaiting_reply") }
                    }
                    Button("Resolved") {
                        Task { await store.loadInboxThreads(status: "resolved") }
                    }
                    Divider()
                    Button("All") {
                        Task { await store.loadInboxThreads() }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await store.refreshInbox() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .automatic) {
                NavigationLink(value: SDSidebarItem.inboxSettings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .task {
            if store.inboxThreads.isEmpty {
                await store.loadInboxCounts()
                await store.loadInboxThreads()
            }
        }
    }
}

// MARK: - Mailbox Filter Chip

private struct MailboxChip: View {
    let mailbox: InboxMailbox
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: mailbox.icon)
                    .font(.caption2)
                Text(mailbox.label)
                    .font(.caption.weight(.medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Thread List Row

struct ThreadListRow: View {
    let thread: EmailThread

    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator
            Circle()
                .fill(thread.hasUnread ? Color.accentColor : Color.clear)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(thread.displaySubject)
                        .font(.subheadline.weight(thread.hasUnread ? .semibold : .medium))
                        .lineLimit(1)

                    Spacer()

                    Text(thread.displayDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    // Mailbox badge
                    Label(thread.mailboxLabel, systemImage: thread.mailboxIcon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let intent = thread.intentLabel {
                        Text(intent)
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }

                    Spacer()

                    // Status + priority
                    HStack(spacing: 4) {
                        if thread.priority == "urgent" || thread.priority == "high" {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(thread.priorityColor)
                        }

                        Text(thread.statusLabel)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(thread.statusColor.opacity(0.12))
                            .foregroundStyle(thread.statusColor)
                            .clipShape(Capsule())
                    }
                }

                if thread.messageCount > 1 {
                    Text("\(thread.messageCount) messages")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
