import SwiftUI
import Realtime

// MARK: - EditorStore
// Central state management for the SwagManager app
// All methods are in extension files (EditorStore+*.swift)
// Uses @Observable for granular SwiftUI updates (only re-renders views that read changed properties)

@MainActor
@Observable
class EditorStore {
    // MARK: - Store State
    var stores: [Store] = []
    var selectedStore: Store?
    var catalogs: [Catalog] = []
    var selectedCatalog: Catalog?
    var categories: [Category] = []
    var isLoadingCatalogs = false

    // MARK: - Chat/Conversations State
    var conversations: [Conversation] = []
    var selectedConversation: Conversation?
    var isLoadingConversations = false

    // MARK: - Locations State
    var locations: [Location] = []
    var selectedLocation: Location?
    var selectedQueue: Location?
    var sidebarLocationsExpanded = false
    var isLoadingLocations = false

    // MARK: - Category Config State
    var selectedCategory: Category?

    // MARK: - AI Agents State
    var aiAgents: [AIAgent] = []
    var selectedAIAgent: AIAgent?
    var sidebarAgentsExpanded = true
    var isLoadingAgents = false

    // MARK: - User Tools & Triggers State
    var userTools: [UserTool] = []
    var userTriggers: [UserTrigger] = []
    var isLoadingUserTools = false

    // MARK: - Emails State (Resend)
    var emails: [ResendEmail] = []
    var selectedEmail: ResendEmail?
    var sidebarEmailsExpanded = false
    var isLoadingEmails = false
    var emailTotalCount: Int = 0
    var emailCategoryCounts: [String: Int] = [:]
    var loadedCategories: Set<String> = []

    // MARK: - Inbox State (Inbound Email)
    var inboxThreads: [EmailThread] = []
    var selectedThread: EmailThread?
    var selectedThreadMessages: [InboxEmail] = []
    var inboxCounts: [String: Int] = [:]  // by mailbox
    var inboxTotalUnread: Int = 0
    var isLoadingInbox = false
    var selectedMailbox: InboxMailbox = .all
    var sidebarInboxExpanded = false

    // MARK: - CRM/Campaigns State
    var emailCampaigns: [EmailCampaign] = []
    var selectedEmailCampaign: EmailCampaign?
    var metaCampaigns: [MetaCampaign] = []
    var selectedMetaCampaign: MetaCampaign?
    var metaIntegrations: [MetaIntegration] = []
    var selectedMetaIntegration: MetaIntegration?
    var smsCampaigns: [SMSCampaign] = []
    var marketingCampaigns: [MarketingCampaign] = []
    var sidebarCRMExpanded = false
    var sidebarEmailCampaignsExpanded = false
    var sidebarMetaCampaignsExpanded = false
    var sidebarSMSCampaignsExpanded = false
    var isLoadingCampaigns = false

    // MARK: - Tabs
    var openTabs: [OpenTabItem] = []
    var activeTab: OpenTabItem?

    // MARK: - UI State
    var isLoading = false
    var isSaving = false
    var refreshTrigger = UUID()
    var error: String?
    var sidebarCatalogExpanded = false
    var sidebarChatExpanded = false

    // MARK: - Section Group Collapse State
    var workspaceGroupCollapsed = false
    var contentGroupCollapsed = false
    var operationsGroupCollapsed = false
    var infrastructureGroupCollapsed = true

    // Sheet states
    var showNewStoreSheet = false

    @ObservationIgnored var lastSelectedIndex: Int?

    @ObservationIgnored let supabase = SupabaseService.shared
    @ObservationIgnored var realtimeTask: Task<Void, Never>?

    @ObservationIgnored let defaultStoreId = UUID(uuidString: "cd2e1122-d511-4edb-be5d-98ef274b4baf")!

    init() {
        // Note: Realtime subscriptions start when store data is loaded
        // Not in init to avoid side effects during Environment default creation
    }

    /// Call this after store is configured and ready
    /// DISABLED: Realtime subscriptions cause cascading re-renders with @Observable
    func startSubscriptions() {
        // startRealtimeSubscription()  // DISABLED - causes performance issues
    }

    deinit {
        // Cancel tasks - this is safe from nonisolated context
        // The channel cleanup happens via task cancellation
        realtimeTask?.cancel()
    }
}

// MARK: - Store Management Extension

extension EditorStore {
    func loadStores() async {
        do {
            let session = try? await supabase.client.auth.session
            stores = try await supabase.fetchStores()
            if selectedStore == nil, let first = stores.first {
                selectedStore = first
            }
        } catch {
            self.error = "Failed to load stores: \(error.localizedDescription)"
        }
    }

    func selectStore(_ store: Store) async {
        // Cleanup all realtime subscriptions before switching stores
        stopRealtimeSubscription()
        selectedStore = store

        // Clear AI telemetry (tool logs, conversation trace, etc.)
        AgentClient.shared.clearAllTelemetry()

        // Clear all store-specific data
        selectedCatalog = nil
        catalogs = []
        categories = []
        selectedCategory = nil
        conversations = []
        selectedConversation = nil
        aiAgents = []
        selectedAIAgent = nil
        userTools = []
        userTriggers = []
        emails = []
        selectedEmail = nil
        emailTotalCount = 0
        emailCategoryCounts = [:]
        loadedCategories = []
        emailCampaigns = []
        selectedEmailCampaign = nil
        metaCampaigns = []
        selectedMetaCampaign = nil
        metaIntegrations = []
        selectedMetaIntegration = nil
        smsCampaigns = []
        marketingCampaigns = []
        openTabs = []
        activeTab = nil
    }

    func createStore(name: String, email: String, ownerUserId: UUID?) async {
        do {
            let slug = name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

            let insert = StoreInsert(
                storeName: name,
                slug: slug,
                email: email,
                ownerUserId: nil,
                status: "active",
                storeType: "standard"
            )

            let newStore = try await supabase.createStore(insert)
            stores.append(newStore)
            selectedStore = newStore
        } catch {
            self.error = "Failed to create store: \(error.localizedDescription)"
        }
    }

    var currentStoreId: UUID {
        selectedStore?.id ?? defaultStoreId
    }

    func loadLocations() async {
        guard let storeId = selectedStore?.id else { return }
        isLoadingLocations = true
        do {
            locations = try await supabase.fetchLocations(storeId: storeId)
        } catch {
            self.error = "Failed to load locations: \(error.localizedDescription)"
        }
        isLoadingLocations = false
    }
}

// MARK: - Environment Support
// Use @Environment(\.editorStore) in views instead of passing as parameter

private struct EditorStoreKey: EnvironmentKey {
    static var defaultValue: EditorStore {
        MainActor.assumeIsolated {
            _sharedDefault
        }
    }
    @MainActor private static let _sharedDefault = EditorStore()
}

extension EnvironmentValues {
    var editorStore: EditorStore {
        get { self[EditorStoreKey.self] }
        set { self[EditorStoreKey.self] = newValue }
    }
}
