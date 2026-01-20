import SwiftUI

// MARK: - Enhanced Chat Store
// Extracted from EnhancedChatView.swift following Apple engineering standards
// File size: ~150 lines (under Apple's 300 line "excellent" threshold)

@MainActor
class EnhancedChatStore: ObservableObject {
    // MARK: - Local Types

    struct ChatCommand: Identifiable {
        let id = UUID()
        let command: String
        let description: String
    }

    // MARK: - Published Properties

    @Published var conversations: [Conversation] = []
    @Published var conversation: Conversation?
    @Published var messages: [ChatMessage] = []
    @Published var draftMessage = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var pendingMessageIds: Set<UUID> = []

    @Published var isAITyping = false
    @Published var showQuickActions = true
    @Published var showCommandSuggestions = false
    @Published var showMentionSuggestions = false
    @Published var replyToMessage: ChatMessage?

    @Published var filteredCommands: [ChatCommand] = []

    var currentUserId: UUID?
    internal var allCommands: [ChatCommand] = [
        ChatCommand(command: "/search", description: "Search products"),
        ChatCommand(command: "/analyze", description: "Analyze data"),
        ChatCommand(command: "/report", description: "Generate report"),
        ChatCommand(command: "/help", description: "Show help")
    ]

    // MARK: - Context Properties

    var contextProductId: UUID?
    var contextProductName: String?
    var contextCategoryId: UUID?
    var contextCategoryName: String?

    // MARK: - Context Management

    func updateContext(from store: EditorStore) {
        contextProductId = store.selectedProduct?.id
        contextProductName = store.selectedProduct?.name
        contextCategoryId = store.selectedCategory?.id
        contextCategoryName = store.selectedCategory?.name
    }

    // MARK: - Suggestion Management

    func updateSuggestions(_ text: String) {
        if text.starts(with: "/") {
            showCommandSuggestions = true
            filteredCommands = allCommands.filter { $0.command.starts(with: text) }
        } else {
            showCommandSuggestions = false
        }

        showMentionSuggestions = text.contains("@")
    }

    func selectCommand(_ command: ChatCommand) {
        draftMessage = command.command + " "
        showCommandSuggestions = false
    }

    func insertMention(_ mention: String) {
        draftMessage += "@\(mention) "
        showMentionSuggestions = false
    }

    // MARK: - Data Loading

    func loadConversations(storeId: UUID, supabase: SupabaseService) async {
        isLoading = true
        error = nil

        do {
            let user = try await supabase.client.auth.user()
            currentUserId = user.id

            conversations = try await supabase.fetchAllConversationsForStoreLocations(
                storeId: storeId,
                fetchLocations: supabase.fetchLocations
            )

            if let first = conversations.first {
                conversation = first
                messages = try await supabase.fetchMessages(conversationId: first.id, limit: 100)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Message Sending

    func sendMessage(supabase: SupabaseService) async {
        guard !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let conversationId = conversation?.id,
              let userId = currentUserId else { return }

        let content = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        draftMessage = ""

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
            replyToMessageId: replyToMessage?.id,
            createdAt: Date()
        )

        pendingMessageIds.insert(optimisticId)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            messages.append(optimisticMessage)
        }

        replyToMessage = nil

        let insert = ChatMessageInsert(
            conversationId: conversationId,
            role: "user",
            content: content,
            senderId: userId,
            isAiInvocation: false,
            replyToMessageId: replyToMessage?.id
        )

        do {
            let newMessage = try await supabase.sendMessage(insert)
            if let index = messages.firstIndex(where: { $0.id == optimisticId }) {
                withAnimation(.easeOut(duration: 0.15)) {
                    messages[index] = newMessage
                    pendingMessageIds.remove(optimisticId)
                }
            }
        } catch {
            self.error = error.localizedDescription
            withAnimation {
                messages.removeAll { $0.id == optimisticId }
                pendingMessageIds.remove(optimisticId)
            }
            draftMessage = content
        }
    }
}
