import SwiftUI

// MARK: - EditorStore
// Central state management for the agent manager app
// All methods are in extension files (EditorStore+*.swift)
// Uses @Observable for granular SwiftUI updates

@MainActor
@Observable
class EditorStore {
    // MARK: - Store State
    var stores: [Store] = []
    var selectedStore: Store?

    // MARK: - AI Agents State
    var aiAgents: [AIAgent] = []
    var selectedAIAgent: AIAgent?
    var isLoadingAgents = false

    // MARK: - User Tools & Triggers State
    var userTools: [UserTool] = []
    var userTriggers: [UserTrigger] = []
    var isLoadingUserTools = false

    // MARK: - UI State
    var isLoading = false
    var isSaving = false
    var refreshTrigger = UUID()
    var error: String?

    // Sheet states
    var showNewStoreSheet = false

    @ObservationIgnored let supabase = SupabaseService.shared

    @ObservationIgnored let defaultStoreId = UUID(uuidString: "cd2e1122-d511-4edb-be5d-98ef274b4baf")!

    init() {}
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
        selectedStore = store

        // Clear all store-specific data
        aiAgents = []
        selectedAIAgent = nil
        userTools = []
        userTriggers = []
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
                status: "active"
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
}

// MARK: - Environment Support

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
