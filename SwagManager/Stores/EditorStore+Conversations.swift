import Foundation

// MARK: - EditorStore Conversations & Locations
// Extracted from EditorView.swift following Apple engineering standards
// File size: ~60 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Conversations & Locations

    func loadConversations() async {
        guard let store = selectedStore else {
            NSLog("[EditorStore] No store selected, cannot load conversations")
            return
        }

        await MainActor.run { isLoadingConversations = true }

        do {
            // Load locations first
            NSLog("[EditorStore] Loading locations for store: \(store.id)")
            let fetchedLocations = try await supabase.fetchLocations(storeId: store.id)
            NSLog("[EditorStore] Loaded \(fetchedLocations.count) locations")

            // Load conversations
            NSLog("[EditorStore] Loading conversations for store: \(store.id)")
            let fetchedConversations = try await supabase.fetchAllConversationsForStoreLocations(storeId: store.id, fetchLocations: { [weak self] storeId in
                guard let self = self else { return [] }
                return try await self.supabase.fetchLocations(storeId: storeId)
            })
            NSLog("[EditorStore] Loaded \(fetchedConversations.count) conversations")

            await MainActor.run {
                locations = fetchedLocations
                conversations = fetchedConversations
                isLoadingConversations = false
            }
        } catch {
            NSLog("[EditorStore] Failed to load conversations: \(error)")
            await MainActor.run {
                self.error = "Failed to load conversations: \(error.localizedDescription)"
                isLoadingConversations = false
            }
        }
    }

    func openConversation(_ conversation: Conversation) {
        selectedConversation = conversation
        selectedCreation = nil
        selectedProduct = nil
        editedCode = nil
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
}
