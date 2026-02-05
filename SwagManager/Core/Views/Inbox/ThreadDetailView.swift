import SwiftUI

// MARK: - Thread Detail View
// Conversation view with messages, AI drafts, and reply composer

struct ThreadDetailView: View {
    let thread: EmailThread
    var store: EditorStore
    @State private var replyText = ""
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            // Thread header
            threadHeader

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.selectedThreadMessages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        // AI Draft (if available on latest inbound)
                        if let draft = latestAIDraft {
                            AIDraftView(draft: draft) { approvedText in
                                replyText = approvedText
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: store.selectedThreadMessages.count) { _, _ in
                    if let lastId = store.selectedThreadMessages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Reply composer
            replyComposer
        }
        .navigationTitle(thread.displaySubject)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Mark Resolved") {
                        Task { await store.updateThreadStatus(thread, status: "resolved") }
                    }
                    Button("Close") {
                        Task { await store.updateThreadStatus(thread, status: "closed") }
                    }
                    Button("Reopen") {
                        Task { await store.updateThreadStatus(thread, status: "open") }
                    }
                } label: {
                    Label("Status", systemImage: "checkmark.circle")
                }
            }
        }
    }

    // MARK: - Thread Header

    private var threadHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: thread.mailboxIcon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(thread.displaySubject)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(thread.statusLabel)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(thread.statusColor.opacity(0.12))
                        .foregroundStyle(thread.statusColor)
                        .clipShape(Capsule())

                    Text(thread.mailboxLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let intent = thread.intentLabel {
                        Text(intent)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }

                    Text("\(thread.messageCount) messages")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if thread.priority == "urgent" || thread.priority == "high" {
                Label(thread.priorityLabel, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(thread.priorityColor)
            }
        }
        .padding()
    }

    // MARK: - Reply Composer

    private var replyComposer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Type a reply...", text: $replyText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(10)
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                Task { await sendReply() }
            } label: {
                Image(systemName: isSending ? "ellipsis.circle" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(12)
    }

    // MARK: - AI Draft

    private var latestAIDraft: String? {
        store.selectedThreadMessages
            .last(where: { $0.isInbound && $0.hasAIDraft })
            .flatMap { $0.aiDraft }
    }

    // MARK: - Send Reply

    private func sendReply() async {
        let body = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        // Convert plain text to basic HTML
        let html = "<p>" + body
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n\n", with: "</p><p>")
            .replacingOccurrences(of: "\n", with: "<br>")
            + "</p>"

        // Use the agent tool to send reply (handles threading)
        do {
            try await store.supabase.client
                .functions
                .invoke(
                    "send-email",
                    options: .init(body: [
                        "to": store.selectedThreadMessages.last(where: { $0.isInbound })?.fromEmail ?? "",
                        "subject": "Re: \(thread.displaySubject)",
                        "html": html,
                        "thread_id": thread.id.uuidString,
                        "in_reply_to": store.selectedThreadMessages.last(where: { $0.isInbound })?.messageId ?? "",
                    ] as [String: String])
                )

            await MainActor.run {
                replyText = ""
            }

            // Reload messages to show the sent reply
            await store.loadThreadMessages(thread)
        } catch {
            await MainActor.run {
                store.error = "Failed to send reply: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: InboxEmail

    var body: some View {
        HStack {
            if !message.isInbound { Spacer(minLength: 60) }

            VStack(alignment: message.isInbound ? .leading : .trailing, spacing: 4) {
                // Sender + time
                HStack(spacing: 6) {
                    if message.isInbound {
                        Text(message.displayFrom)
                            .font(.caption.weight(.medium))
                        Text(message.displayDate)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(message.displayDate)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("You")
                            .font(.caption.weight(.medium))
                    }
                }

                // Body
                Text(message.displayBody)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(message.bubbleColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Attachments
                if message.hasAttachments, let attachments = message.attachments {
                    HStack(spacing: 6) {
                        ForEach(attachments) { attachment in
                            Label(attachment.filename, systemImage: attachment.icon)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if message.isInbound { Spacer(minLength: 60) }
        }
    }
}

// MARK: - AI Draft View

struct AIDraftView: View {
    let draft: String
    let onApprove: (String) -> Void
    @State private var editedDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.purple)
                Text("AI Suggested Reply")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.purple)
                Spacer()
            }

            Text(draft)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                Button("Use This Reply") {
                    onApprove(draft)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.small)

                Button("Dismiss") {
                    // Just hide - no action needed
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.purple.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Thread Detail Wrapper (for navigation)

struct ThreadDetailWrapper: View {
    let threadId: UUID
    var store: EditorStore
    @State private var isLoading = true
    @State private var thread: EmailThread?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let thread {
                ThreadDetailView(thread: thread, store: store)
            } else {
                ContentUnavailableView("Thread not found", systemImage: "tray")
            }
        }
        .task(id: threadId) {
            isLoading = true

            // Find thread in current list or reload
            if let found = store.inboxThreads.first(where: { $0.id == threadId }) {
                thread = found
            } else {
                await store.loadInboxThreads()
                thread = store.inboxThreads.first(where: { $0.id == threadId })
            }

            // Load messages for this thread
            if let thread {
                await store.loadThreadMessages(thread)
            }

            isLoading = false
        }
    }
}
