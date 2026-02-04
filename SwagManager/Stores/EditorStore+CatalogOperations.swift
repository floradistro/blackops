import SwiftUI

// MARK: - EditorStore Catalog Operations Extension
// Extracted from EditorStore+CatalogManagement.swift following Apple engineering standards
// File size: ~155 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Catalog Operations

    func loadCatalogs() async {
        await MainActor.run { isLoadingCatalogs = true }

        do {
            let fetchedCatalogs = try await supabase.fetchCatalogs(storeId: currentStoreId)
            await MainActor.run { catalogs = fetchedCatalogs }
            for cat in catalogs {
            }

            // Auto-create default catalog if none exist but categories do
            if catalogs.isEmpty {
                let orphanCategories = try await supabase.fetchCategories(storeId: currentStoreId, catalogId: nil)
                let orphanCount = orphanCategories.filter { $0.catalogId == nil }.count

                if orphanCount > 0 {
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
                    _ = try await supabase.assignCategoriesToCatalog(storeId: currentStoreId, catalogId: defaultCatalog.id, onlyOrphans: false)
                }
            }

            // Don't auto-select - let user expand catalog to see contents
            await MainActor.run { isLoadingCatalogs = false }
        } catch {
            await MainActor.run { isLoadingCatalogs = false }
            // Don't show error if table doesn't exist yet
        }
    }

    internal func createDefaultCatalogAndMigrate() async {
        guard let ownerUserId = selectedStore?.ownerUserId else {
            return
        }

        do {
            // First check if catalog already exists
            catalogs = try await supabase.fetchCatalogs(storeId: currentStoreId)

            if let existingCatalog = catalogs.first {
                // Use existing catalog for migration but don't auto-select

                // Migrate orphan categories
                let migratedCount = try await supabase.assignCategoriesToCatalog(storeId: currentStoreId, catalogId: existingCatalog.id)
                if migratedCount > 0 {
                }
                return
            }


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

            // Migrate orphan categories
            let migratedCount = try await supabase.assignCategoriesToCatalog(storeId: currentStoreId, catalogId: newCatalog.id)

            catalogs = [newCatalog]
            // Don't auto-select - keep collapsed
        } catch {
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
        } catch {
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
        } catch {
            self.error = "Failed to delete catalog: \(error.localizedDescription)"
        }
    }
}
