import SwiftUI
import Supabase

// MARK: - EditorStore Creation Management Extension
// Extracted from EditorStore+RealtimeSync.swift following Apple engineering standards
// File size: ~180 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Computed Properties

    var hasUnsavedChanges: Bool {
        guard let edited = editedCode, let original = selectedCreation?.reactCode else { return false }
        return edited != original
    }

    var selectedCreations: [Creation] {
        creations.filter { selectedCreationIds.contains($0.id) }
    }

    // Get creations for a specific collection
    func creationsForCollection(_ collectionId: UUID) -> [Creation] {
        guard let creationIds = collectionItems[collectionId] else { return [] }
        return creations.filter { creationIds.contains($0.id) }
    }

    // Get creations not in any collection
    var orphanCreations: [Creation] {
        let allCollectionCreationIds = Set(collectionItems.values.flatMap { $0 })
        return creations.filter { !allCollectionCreationIds.contains($0.id) }
    }

    // MARK: - Load Operations

    func loadCreations() async {
        isLoading = true
        do {
            creations = try await supabase.fetchCreations()
        } catch {
            self.error = "Failed to load creations: \(error.localizedDescription)"
        }

        // Load collections separately so one failure doesn't block the other
        do {
            collections = try await supabase.fetchCollections()

            // Load all collection items
            var itemsMap: [UUID: [UUID]] = [:]
            for collection in collections {
                let items = try await supabase.fetchCollectionItems(collectionId: collection.id)
                itemsMap[collection.id] = items.map { $0.creationId }
            }
            collectionItems = itemsMap
        } catch {
            // Don't override error if creations also failed
            if self.error == nil {
                self.error = "Failed to load collections: \(error.localizedDescription)"
            }
        }
        isLoading = false
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
            selectedProduct = nil
            selectedProductIds.removeAll()
            lastSelectedIndex = list.firstIndex(where: { $0.id == creation.id })
            openTab(.creation(creation))
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
        do {
            let update = CreationUpdate(reactCode: code)
            let updated = try await supabase.updateCreation(id: creation.id, update: update)
            selectedCreation = updated
            editedCode = updated.reactCode
            refreshTrigger = UUID()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func updateCreationSettings(id: UUID, status: CreationStatus? = nil, isPublic: Bool? = nil, visibility: String? = nil, name: String? = nil, description: String? = nil) async {
        isSaving = true
        do {
            let update = CreationUpdate(name: name, description: description, status: status, isPublic: isPublic, visibility: visibility)
            let updated = try await supabase.updateCreation(id: id, update: update)
            if let idx = creations.firstIndex(where: { $0.id == id }) {
                creations[idx] = updated
            }
            if selectedCreation?.id == id {
                selectedCreation = updated
            }
            refreshTrigger = UUID()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func deleteCreation(_ creation: Creation) async {
        do {
            try await supabase.deleteCreation(id: creation.id)
            if selectedCreation?.id == creation.id {
                selectedCreation = nil
                editedCode = nil
            }
            selectedCreationIds.remove(creation.id)
            await loadCreations()
        } catch {
            self.error = "Failed to delete '\(creation.name)': \(error.localizedDescription)"
        }
    }

    func deleteSelectedCreations() async {
        let idsToDelete = selectedCreationIds
        var failedCount = 0
        var errors: [String] = []

        for id in idsToDelete {
            do {
                try await supabase.deleteCreation(id: id)
            } catch {
                failedCount += 1
                errors.append(error.localizedDescription)
            }
        }

        // Clear selection
        selectedCreationIds.removeAll()
        selectedCreation = nil
        editedCode = nil
        lastSelectedIndex = nil

        // Reload once at the end
        await loadCreations()

        // Report errors if any
        if failedCount > 0 {
            self.error = "Failed to delete \(failedCount) item(s): \(errors.first ?? "Unknown error")"
        }
    }

    func triggerRefresh() {
        refreshTrigger = UUID()
    }
}
