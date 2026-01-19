import SwiftUI
import Supabase

// MARK: - Creation Store (Focused on Creations & Collections)

/// Manages creations, collections, and collection items
/// Single responsibility: Creation lifecycle and organization
@MainActor
class CreationStore: ObservableObject {

    // MARK: - Published State

    @Published var creations: [Creation] = []
    @Published var collections: [CreationCollection] = []
    @Published var collectionItems: [UUID: [UUID]] = [:] // collectionId -> [creationId]
    @Published var selectedCreation: Creation?
    @Published var selectedCreationIds: Set<UUID> = []
    @Published var editedCode: String?

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?

    // MARK: - Private State

    private var creationIndex: [UUID: Creation] = [:] // O(1) lookups
    private var lastSelectedIndex: Int?
    private var realtimeTask: Task<Void, Never>?

    private let supabase = SupabaseService.shared

    // MARK: - Lifecycle

    init() {
        startRealtimeSubscription()
    }

    deinit {
        realtimeTask?.cancel()
    }

    // MARK: - Computed Properties

    var hasUnsavedChanges: Bool {
        guard let edited = editedCode, let original = selectedCreation?.reactCode else { return false }
        return edited != original
    }

    var selectedCreations: [Creation] {
        selectedCreationIds.compactMap { creationIndex[$0] }
    }

    var orphanCreations: [Creation] {
        let allCollectionCreationIds = Set(collectionItems.values.flatMap { $0 })
        return creations.filter { !allCollectionCreationIds.contains($0.id) }
    }

    // MARK: - Queries

    func creationsForCollection(_ collectionId: UUID) -> [Creation] {
        guard let creationIds = collectionItems[collectionId] else { return [] }
        return creationIds.compactMap { creationIndex[$0] }
    }

    // MARK: - Data Loading

    func loadCreations() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedCreations = try await supabase.fetchCreations()
            creations = fetchedCreations
            rebuildIndex()
        } catch {
            NSLog("[CreationStore] Error loading creations: \(error)")
            self.error = "Failed to load creations: \(error.localizedDescription)"
        }
    }

    func loadCollections() async {
        do {
            NSLog("[CreationStore] Fetching collections...")
            collections = try await supabase.fetchCollections()
            NSLog("[CreationStore] Loaded \(collections.count) collections")

            // Load all collection items
            var itemsMap: [UUID: [UUID]] = [:]
            for collection in collections {
                let items = try await supabase.fetchCollectionItems(collectionId: collection.id)
                itemsMap[collection.id] = items.map { $0.creationId }
            }
            collectionItems = itemsMap
            NSLog("[CreationStore] Loaded collection items for \(itemsMap.count) collections")
        } catch {
            NSLog("[CreationStore] Error loading collections: \(error)")
            if self.error == nil {
                self.error = "Failed to load collections: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Selection Management

    func selectCreation(_ creation: Creation, add: Bool = false, range: Bool = false, in list: [Creation] = []) {
        if range, let lastIdx = lastSelectedIndex, let currentIdx = list.firstIndex(where: { $0.id == creation.id }) {
            // Shift+click: select range
            let start = min(lastIdx, currentIdx)
            let end = max(lastIdx, currentIdx)
            for i in start...end {
                selectedCreationIds.insert(list[i].id)
            }
        } else if add {
            // Cmd+click: toggle selection
            if selectedCreationIds.contains(creation.id) {
                selectedCreationIds.remove(creation.id)
                if selectedCreation?.id == creation.id {
                    selectedCreation = selectedCreations.first
                    editedCode = selectedCreation?.reactCode
                }
            } else {
                selectedCreationIds.insert(creation.id)
            }
        } else {
            // Normal click: single select
            selectedCreationIds = [creation.id]
        }

        // Update active creation for editing
        if selectedCreationIds.contains(creation.id) {
            selectedCreation = creation
            editedCode = creation.reactCode
            lastSelectedIndex = list.firstIndex(where: { $0.id == creation.id })
        }
    }

    func clearSelection() {
        selectedCreationIds.removeAll()
        selectedCreation = nil
        editedCode = nil
        lastSelectedIndex = nil
    }

    // MARK: - CRUD Operations

    func saveCurrentCreation() async {
        guard let creation = selectedCreation, let code = editedCode else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let update = CreationUpdate(reactCode: code)
            let updated = try await supabase.updateCreation(id: creation.id, update: update)
            updateCreationInStore(updated)
            selectedCreation = updated
            editedCode = updated.reactCode
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateCreationSettings(
        id: UUID,
        status: CreationStatus? = nil,
        isPublic: Bool? = nil,
        visibility: String? = nil,
        name: String? = nil,
        description: String? = nil
    ) async {
        isSaving = true
        defer { isSaving = false }

        do {
            let update = CreationUpdate(
                name: name,
                description: description,
                status: status,
                isPublic: isPublic,
                visibility: visibility
            )
            let updated = try await supabase.updateCreation(id: id, update: update)
            updateCreationInStore(updated)
            if selectedCreation?.id == id {
                selectedCreation = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteCreation(_ creation: Creation) async {
        do {
            try await supabase.deleteCreation(id: creation.id)
            if selectedCreation?.id == creation.id {
                selectedCreation = nil
                editedCode = nil
            }
            selectedCreationIds.remove(creation.id)
            removeCreationFromStore(creation.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func rebuildIndex() {
        creationIndex = Dictionary(uniqueKeysWithValues: creations.map { ($0.id, $0) })
    }

    private func updateCreationInStore(_ creation: Creation) {
        creationIndex[creation.id] = creation
        if let idx = creations.firstIndex(where: { $0.id == creation.id }) {
            creations[idx] = creation
        }
    }

    private func addCreationToStore(_ creation: Creation) {
        guard creationIndex[creation.id] == nil else { return }
        creationIndex[creation.id] = creation
        creations.insert(creation, at: 0)
    }

    private func removeCreationFromStore(_ id: UUID) {
        creationIndex.removeValue(forKey: id)
        creations.removeAll { $0.id == id }
    }

    // MARK: - Realtime Subscriptions

    private func startRealtimeSubscription() {
        realtimeTask = Task { [weak self] in
            guard let self = self else { return }

            let client = self.supabase.client
            let channel = client.realtimeV2.channel("creation-changes")

            let creationsInserts = channel.postgresChange(InsertAction.self, table: "creations")
            let creationsUpdates = channel.postgresChange(UpdateAction.self, table: "creations")
            let creationsDeletes = channel.postgresChange(DeleteAction.self, table: "creations")

            do {
                try await channel.subscribeWithError()
                NSLog("[CreationStore] Realtime: Successfully subscribed")
            } catch {
                NSLog("[CreationStore] Realtime: Failed to subscribe - \(error)")
                return
            }

            await withTaskGroup(of: Void.self) { group in
                // Handle inserts
                group.addTask {
                    for await insert in creationsInserts {
                        await MainActor.run {
                            if let creation = try? insert.decodeRecord(as: Creation.self, decoder: JSONDecoder.supabaseDecoder) {
                                self.addCreationToStore(creation)
                                NSLog("[CreationStore] Realtime: Added creation '\(creation.name)'")
                            }
                        }
                    }
                }

                // Handle updates
                group.addTask {
                    for await update in creationsUpdates {
                        await MainActor.run {
                            if let creation = try? update.decodeRecord(as: Creation.self, decoder: JSONDecoder.supabaseDecoder) {
                                self.updateCreationInStore(creation)
                                if self.selectedCreation?.id == creation.id {
                                    self.selectedCreation = creation
                                    if self.editedCode == nil || !self.hasUnsavedChanges {
                                        self.editedCode = creation.reactCode
                                    }
                                }
                                NSLog("[CreationStore] Realtime: Updated creation '\(creation.name)'")
                            }
                        }
                    }
                }

                // Handle deletes
                group.addTask {
                    for await delete in creationsDeletes {
                        await MainActor.run {
                            if let idString = delete.oldRecord["id"]?.stringValue,
                               let id = UUID(uuidString: idString) {
                                self.removeCreationFromStore(id)
                                self.selectedCreationIds.remove(id)
                                if self.selectedCreation?.id == id {
                                    self.selectedCreation = nil
                                    self.editedCode = nil
                                }
                                NSLog("[CreationStore] Realtime: Removed creation \(idString)")
                            }
                        }
                    }
                }
            }
        }
    }
}
