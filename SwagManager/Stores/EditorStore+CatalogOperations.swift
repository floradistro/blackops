import SwiftUI

// MARK: - EditorStore Catalog Operations Extension
// Extracted from EditorStore+CatalogManagement.swift following Apple engineering standards
// File size: ~155 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Catalog Operations

    func loadCatalogs() async {
        await MainActor.run { isLoadingCatalogs = true }

        do {
            NSLog("[EditorStore] Loading catalogs for store: %@ (%@)", selectedStore?.storeName ?? "unknown", currentStoreId.uuidString)
            let fetchedCatalogs = try await supabase.fetchCatalogs(storeId: currentStoreId)
            await MainActor.run { catalogs = fetchedCatalogs }
            NSLog("[EditorStore] Found %d catalogs for store %@:", catalogs.count, selectedStore?.storeName ?? "unknown")
            for cat in catalogs {
                NSLog("[EditorStore]   - %@ (id: %@, store_id: %@)", cat.name, cat.id.uuidString, cat.storeId.uuidString)
            }

            // Auto-create default catalog if none exist but categories do
            if catalogs.isEmpty {
                NSLog("[EditorStore] No catalogs found, checking for orphan categories...")
                let orphanCategories = try await supabase.fetchCategories(storeId: currentStoreId, catalogId: nil)
                let orphanCount = orphanCategories.filter { $0.catalogId == nil }.count
                NSLog("[EditorStore] Found %d total categories, %d without catalog_id", orphanCategories.count, orphanCount)

                if orphanCount > 0 {
                    NSLog("[EditorStore] Creating default Distro catalog and migrating %d categories...", orphanCount)
                    await createDefaultCatalogAndMigrate()
                    await MainActor.run { isLoadingCatalogs = false }
                    return // createDefaultCatalogAndMigrate will reload catalogs
                }
            } else if let defaultCatalog = catalogs.first(where: { $0.isDefault == true }) ?? catalogs.first {
                // Catalogs exist - assign ALL categories for this store to the default catalog
                // This ensures categories don't belong to other/orphaned catalogs
                let allCategories = try await supabase.fetchCategories(storeId: currentStoreId, catalogId: nil)
                let wrongCatalogCount = allCategories.filter { $0.catalogId != defaultCatalog.id }.count
                if wrongCatalogCount > 0 {
                    NSLog("[EditorStore] Found %d categories not in default catalog, migrating to %@...", wrongCatalogCount, defaultCatalog.name)
                    _ = try await supabase.assignCategoriesToCatalog(storeId: currentStoreId, catalogId: defaultCatalog.id, onlyOrphans: false)
                    NSLog("[EditorStore] Migrated %d categories to %@", wrongCatalogCount, defaultCatalog.name)
                }
            }

            // Don't auto-select - let user expand catalog to see contents
            NSLog("[EditorStore] Loaded %d catalogs for store %@", catalogs.count, selectedStore?.storeName ?? "default")
            await MainActor.run { isLoadingCatalogs = false }
        } catch {
            NSLog("[EditorStore] Error loading catalogs: %@", String(describing: error))
            await MainActor.run { isLoadingCatalogs = false }
            // Don't show error if table doesn't exist yet
        }
    }

    internal func createDefaultCatalogAndMigrate() async {
        guard let ownerUserId = selectedStore?.ownerUserId else {
            NSLog("[EditorStore] Cannot create catalog: store owner_user_id is nil")
            return
        }

        do {
            // First check if catalog already exists
            catalogs = try await supabase.fetchCatalogs(storeId: currentStoreId)

            if let existingCatalog = catalogs.first {
                // Use existing catalog for migration but don't auto-select
                NSLog("[EditorStore] Found existing catalog: %@ (id: %@)", existingCatalog.name, existingCatalog.id.uuidString)

                // Migrate orphan categories
                let migratedCount = try await supabase.assignCategoriesToCatalog(storeId: currentStoreId, catalogId: existingCatalog.id)
                if migratedCount > 0 {
                    NSLog("[EditorStore] Migrated %d categories to %@", migratedCount, existingCatalog.name)
                }
                return
            }

            NSLog("[EditorStore] Creating default Distro catalog for store: %@", currentStoreId.uuidString)

            // Create default "Distro" catalog
            let insert = CatalogInsert(
                storeId: currentStoreId,
                ownerUserId: ownerUserId,
                name: "Distro",
                slug: "distro-\(Int(Date().timeIntervalSince1970))",
                description: "Main product catalog",
                vertical: "cannabis",
                isActive: true,
                isDefault: true
            )

            let newCatalog = try await supabase.createCatalog(insert)
            NSLog("[EditorStore] Created catalog: %@ (id: %@)", newCatalog.name, newCatalog.id.uuidString)

            // Migrate orphan categories
            let migratedCount = try await supabase.assignCategoriesToCatalog(storeId: currentStoreId, catalogId: newCatalog.id)
            NSLog("[EditorStore] Migrated %d categories", migratedCount)

            catalogs = [newCatalog]
            // Don't auto-select - keep collapsed
        } catch {
            NSLog("[EditorStore] Error in createDefaultCatalogAndMigrate: %@", String(describing: error))
            // Don't show error to user - just load what we have
            await loadCatalogData()
        }
    }

    func selectCatalog(_ catalog: Catalog) async {
        selectedCatalog = catalog
        await loadCatalogData()
    }

    func createCatalog(name: String, vertical: String?, isDefault: Bool = false) async {
        guard let ownerUserId = selectedStore?.ownerUserId else {
            NSLog("[EditorStore] Cannot create catalog: store owner_user_id is nil")
            self.error = "Cannot create catalog: store owner not found"
            return
        }

        do {
            let slug = name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

            let insert = CatalogInsert(
                storeId: currentStoreId,
                ownerUserId: ownerUserId,
                name: name,
                slug: slug,
                description: nil,
                vertical: vertical,
                isActive: true,
                isDefault: isDefault
            )

            let newCatalog = try await supabase.createCatalog(insert)
            await loadCatalogs()
            selectedCatalog = newCatalog
            await loadCatalogData()
            NSLog("[EditorStore] Created catalog: %@", name)
        } catch {
            NSLog("[EditorStore] Error creating catalog: %@", String(describing: error))
            self.error = "Failed to create catalog: \(error.localizedDescription)"
        }
    }

    func deleteCatalog(_ catalog: Catalog) async {
        do {
            try await supabase.deleteCatalog(id: catalog.id)
            if selectedCatalog?.id == catalog.id {
                selectedCatalog = nil
            }
            await loadCatalogs()
            await loadCatalogData()
            NSLog("[EditorStore] Deleted catalog: %@", catalog.name)
        } catch {
            NSLog("[EditorStore] Error deleting catalog: %@", String(describing: error))
            self.error = "Failed to delete catalog: \(error.localizedDescription)"
        }
    }
}
