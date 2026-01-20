import SwiftUI

// MARK: - EditorStore Store Management Extension
// Extracted from EditorStore+CatalogManagement.swift following Apple engineering standards
// File size: ~70 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Store Operations

    func loadStores() async {
        do {
            // Check if user is authenticated first
            let session = try? await supabase.client.auth.session
            NSLog("[EditorStore] Auth session: %@", session != nil ? "authenticated" : "NOT authenticated")

            // RLS automatically filters to stores the user owns/works at
            stores = try await supabase.fetchStores()
            NSLog("[EditorStore] Loaded %d stores", stores.count)
            // Auto-select first store if none selected
            if selectedStore == nil, let first = stores.first {
                selectedStore = first
                NSLog("[EditorStore] Auto-selected store: %@", first.storeName)
            }
        } catch {
            NSLog("[EditorStore] Error loading stores: %@", String(describing: error))
            self.error = "Failed to load stores: \(error.localizedDescription)"
        }
    }

    func selectStore(_ store: Store) async {
        selectedStore = store
        // Clear old data
        selectedCatalog = nil
        catalogs = []
        categories = []
        products = []
        conversations = []
        locations = []
        // Reload all data for new store
        await loadCatalog()
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
                ownerUserId: nil,  // DB trigger will auto-set from logged-in user
                status: "active",
                storeType: "standard"
            )

            let newStore = try await supabase.createStore(insert)
            stores.append(newStore)
            selectedStore = newStore
            await loadCatalog()
            NSLog("[EditorStore] Created store: %@", name)
        } catch {
            NSLog("[EditorStore] Error creating store: %@", String(describing: error))
            self.error = "Failed to create store: \(error.localizedDescription)"
        }
    }

    /// Current store ID for catalog queries
    var currentStoreId: UUID {
        selectedStore?.id ?? defaultStoreId
    }
}
