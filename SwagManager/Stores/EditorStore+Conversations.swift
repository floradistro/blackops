import Foundation

// MARK: - EditorStore Conversations & Locations
// Extracted from EditorView.swift following Apple engineering standards
// File size: ~60 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Conversations & Locations

    func loadConversations() async {
        guard let store = selectedStore else {
            return
        }

        await MainActor.run { isLoadingConversations = true }

        do {
            // Load locations first
            let fetchedLocations = try await supabase.fetchLocations(storeId: store.id)

            // Load conversations
            let fetchedConversations = try await supabase.fetchAllConversationsForStoreLocations(storeId: store.id, fetchLocations: { [weak self] storeId in
                guard let self = self else { return [] }
                return try await self.supabase.fetchLocations(storeId: storeId)
            })

            // Filter out empty conversations (no messages) - reduces spam
            let nonEmptyConversations = fetchedConversations.filter { conversation in
                // Keep if has messages OR is a special channel type
                let hasMessages = (conversation.messageCount ?? 0) > 0
                let isSpecialChannel = ["team", "alerts", "bugs"].contains(conversation.chatType ?? "")
                return hasMessages || isSpecialChannel
            }

            let filteredCount = fetchedConversations.count - nonEmptyConversations.count
            if filteredCount > 0 {
            }

            await MainActor.run {
                locations = fetchedLocations
                conversations = nonEmptyConversations
                isLoadingConversations = false
            }

            // Auto-cleanup old empty conversations in background
            Task {
                await cleanupEmptyConversations(storeId: store.id)
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load conversations: \(error.localizedDescription)"
                isLoadingConversations = false
            }
        }
    }

    func openConversation(_ conversation: Conversation) {
        selectedConversation = conversation
        openTab(.conversation(conversation))
    }

    func openLocationChat(_ location: Location) {
        // Find existing conversation for this location, or create a placeholder
        if let existingConvo = conversations.first(where: { $0.locationId == location.id }) {
            openConversation(existingConvo)
        } else {
            // Create a virtual conversation for this location (will be created on first message)
            let virtualConvo = Conversation(
                id: UUID(),
                storeId: selectedStore?.id,
                userId: nil,
                title: location.name,
                status: "new",
                messageCount: 0,
                chatType: "location",
                locationId: location.id,
                metadata: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            openConversation(virtualConvo)
        }
    }

    // MARK: - Auto-Cleanup

    /// Deletes empty conversations older than 1 hour (reduces database spam)
    private func cleanupEmptyConversations(storeId: UUID) async {
        do {
            // Delete conversations with 0 messages that are older than 1 hour
            // Excludes special channel types (team, alerts, bugs)
            try await supabase.client
                .from("conversations")
                .delete()
                .eq("store_id", value: storeId.uuidString.lowercased())
                .eq("message_count", value: 0)
                .lt("created_at", value: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)))
                .not("chat_type", operator: .in, value: "(team,alerts,bugs)")
                .execute()

        } catch {
            // Non-critical, just log
        }
    }
}
