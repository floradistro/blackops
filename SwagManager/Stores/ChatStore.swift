import SwiftUI
import Supabase

// MARK: - Chat Store
// Extracted from TeamChatView.swift for separation of concerns

@MainActor
class ChatStore: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var conversation: Conversation?
    @Published var messages: [ChatMessage] = []
    @Published var draftMessage = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var typingUsers: [UUID] = []
    @Published var pendingMessageIds: Set<UUID> = []

    var currentUserId: UUID?

    func loadConversations(storeId: UUID, supabase: SupabaseService) async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let user = try await supabase.client.auth.user()
            currentUserId = user.id
            NSLog("[ChatStore] Current user: \(user.id)")

            // Fetch ALL conversations for this store AND its locations
            conversations = try await supabase.fetchAllConversationsForStoreLocations(storeId: storeId, fetchLocations: { storeId in
                try await supabase.fetchLocations(storeId: storeId)
            })
            NSLog("[ChatStore] Found \(conversations.count) total conversations for store \(storeId)")

            // Auto-select first conversation if available
            if let first = conversations.first {
                await selectConversation(first, supabase: supabase)
            }
        } catch {
            self.error = error.localizedDescription
            NSLog("[ChatStore] Error loading conversations: \(error)")
        }

        isLoading = false
    }

    func selectConversation(_ conv: Conversation, supabase: SupabaseService) async {
        conversation = conv
        messages = []

        do {
            messages = try await supabase.fetchMessages(conversationId: conv.id, limit: 100)
            NSLog("[ChatStore] Loaded \(messages.count) messages for conversation \(conv.id)")
        } catch {
            NSLog("[ChatStore] Error loading messages: \(error)")
        }
    }

    func loadConversation(storeId: UUID, supabase: SupabaseService) async {
        await loadConversations(storeId: storeId, supabase: supabase)
    }

    func sendMessage(supabase: SupabaseService) async {
        guard !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let conversationId = conversation?.id,
              let userId = currentUserId else { return }

        let content = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        draftMessage = ""

        // Create optimistic message for instant UI update
        let optimisticId = UUID()
        let optimisticMessage = ChatMessage(
            id: optimisticId,
            conversationId: conversationId,
            role: "user",
            content: content,
            toolCalls: nil,
            tokensUsed: nil,
            senderId: userId,
            isAiInvocation: false,
            aiPrompt: nil,
            replyToMessageId: nil,
            createdAt: Date()
        )

        // Add to pending and messages immediately
        pendingMessageIds.insert(optimisticId)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            messages.append(optimisticMessage)
        }

        let insert = ChatMessageInsert(
            conversationId: conversationId,
            role: "user",
            content: content,
            senderId: userId,
            isAiInvocation: false,
            replyToMessageId: nil
        )

        do {
            let newMessage = try await supabase.sendMessage(insert)
            // Replace optimistic message with real one
            if let index = messages.firstIndex(where: { $0.id == optimisticId }) {
                withAnimation(.easeOut(duration: 0.15)) {
                    messages[index] = newMessage
                    pendingMessageIds.remove(optimisticId)
                }
            }
        } catch {
            self.error = error.localizedDescription
            NSLog("[ChatStore] Error sending message: \(error)")
            // Remove optimistic message on error
            withAnimation {
                messages.removeAll { $0.id == optimisticId }
                pendingMessageIds.remove(optimisticId)
            }
            // Restore draft
            draftMessage = content
        }
    }

    func loadMoreMessages(supabase: SupabaseService) async {
        guard let convId = conversation?.id,
              let oldestMessage = messages.first,
              let oldestDate = oldestMessage.createdAt else { return }

        do {
            let olderMessages = try await supabase.fetchMessages(conversationId: convId, limit: 50, before: oldestDate)
            messages.insert(contentsOf: olderMessages, at: 0)
        } catch {
            NSLog("[ChatStore] Error loading more messages: \(error)")
        }
    }

    func loadConversationMessages(_ conv: Conversation, supabase: SupabaseService) async {
        conversation = conv
        messages = []
        isLoading = true
        error = nil

        do {
            // Get current user
            let user = try await supabase.client.auth.user()
            currentUserId = user.id

            messages = try await supabase.fetchMessages(conversationId: conv.id, limit: 100)
            NSLog("[ChatStore] Loaded \(messages.count) messages for conversation \(conv.id)")
        } catch {
            self.error = error.localizedDescription
            NSLog("[ChatStore] Error loading messages: \(error)")
        }

        isLoading = false
    }
}
