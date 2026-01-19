import Foundation

// MARK: - EditorStore Creation Functions
// Extracted from EditorView.swift following Apple engineering standards
// File size: ~65 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Create Functions

    func createCreation(name: String, type: CreationType, description: String?) async {
        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let insert = CreationInsert(
            creationType: type,
            name: name,
            slug: slug,
            description: description,
            status: .draft,
            reactCode: defaultReactCode(for: type, name: name)
        )

        do {
            let created = try await supabase.createCreation(insert)
            await loadCreations()
            selectCreation(created, in: creations)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createCollection(name: String, description: String?) async {
        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let insert = CollectionInsert(
            storeId: defaultStoreId,
            name: name,
            slug: slug,
            description: description,
            isPublic: false
        )

        do {
            _ = try await supabase.createCollection(insert)
            collections = try await supabase.fetchCollections()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteCollection(_ collection: CreationCollection) async {
        do {
            try await supabase.deleteCollection(id: collection.id)
            collections = try await supabase.fetchCollections()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func defaultReactCode(for type: CreationType, name: String) -> String {
        """
        const App = () => {
          return (
            <div className="min-h-screen bg-black text-white flex items-center justify-center">
              <div className="text-center">
                <h1 className="text-4xl font-bold mb-4">\(name)</h1>
                <p className="text-gray-400">Start building your \(type.displayName.lowercased())</p>
              </div>
            </div>
          );
        };
        """
    }
}
