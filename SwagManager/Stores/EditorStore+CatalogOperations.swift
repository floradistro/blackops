import SwiftUI

// MARK: - EditorStore Catalog Operations Extension
// Extracted from EditorStore+CatalogManagement.swift following Apple engineering standards
// File size: ~155 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Catalog Operations

    func loadCatalogs() async {
        isLoadingCatalogs = true

        do {
            // Fetch catalogs (lightweight — just the catalog records)
            let catalogService = supabase.catalogs
            let storeId = currentStoreId
            let fetchedCatalogs = try await catalogService.fetchCatalogs(storeId: storeId)
            catalogs = fetchedCatalogs

            // One-time migration: if no catalogs exist, check for orphan categories
            // This only triggers when the store has never had catalogs set up
            if catalogs.isEmpty {
                await createDefaultCatalogAndMigrate()
            }

            isLoadingCatalogs = false
        } catch {
            isLoadingCatalogs = false
        }
    }

    internal func createDefaultCatalogAndMigrate() async {
        guard let ownerUserId = selectedStore?.ownerUserId else {
            return
        }

        let catalogService = supabase.catalogs
        let storeId = currentStoreId

        do {
            // Re-check catalogs (another task might have created one)
            let existing = try await catalogService.fetchCatalogs(storeId: storeId)
            if let existingCatalog = existing.first {
                catalogs = existing
                // Migrate orphan categories via RPC (lightweight server-side operation)
                _ = try? await catalogService.assignCategoriesToCatalog(
                    storeId: storeId, catalogId: existingCatalog.id, onlyOrphans: true)
                return
            }

            // Create default catalog
            let insert = CatalogInsert(
                storeId: storeId,
                ownerUserId: ownerUserId,
                name: "Distro",
                slug: "distro-\(Int(Date().timeIntervalSince1970))",
                description: "Main product catalog",
                vertical: "cannabis",
                isActive: true,
                isDefault: true
            )

            let newCatalog = try await catalogService.createCatalog(insert)
            _ = try? await catalogService.assignCategoriesToCatalog(
                storeId: storeId, catalogId: newCatalog.id)
            catalogs = [newCatalog]
        } catch {
            // Silent — catalog will be created on next load
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
