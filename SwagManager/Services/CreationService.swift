import Foundation
import Supabase

// MARK: - Creation Service
// Extracted from SupabaseService.swift following Apple engineering standards
// Handles: Creations, Collections, Collection Items, Stats
// File size: ~240 lines (under Apple's 300 line "excellent" threshold)

@MainActor
final class CreationService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Creations

    func fetchCreations(
        type: CreationType? = nil,
        status: CreationStatus? = nil,
        search: String? = nil,
        limit: Int = 100
    ) async throws -> [Creation] {
        // Fetch all creations and filter client-side for soft deletes
        var creations: [Creation]

        if let type = type, let status = status, let search = search, !search.isEmpty {
            creations = try await client.from("creations")
                .select()
                .eq("creation_type", value: type.rawValue)
                .eq("status", value: status.rawValue)
                .ilike("name", pattern: "%\(search)%")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else if let type = type, let status = status {
            creations = try await client.from("creations")
                .select()
                .eq("creation_type", value: type.rawValue)
                .eq("status", value: status.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else if let type = type, let search = search, !search.isEmpty {
            creations = try await client.from("creations")
                .select()
                .eq("creation_type", value: type.rawValue)
                .ilike("name", pattern: "%\(search)%")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else if let status = status, let search = search, !search.isEmpty {
            creations = try await client.from("creations")
                .select()
                .eq("status", value: status.rawValue)
                .ilike("name", pattern: "%\(search)%")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else if let type = type {
            creations = try await client.from("creations")
                .select()
                .eq("creation_type", value: type.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else if let status = status {
            creations = try await client.from("creations")
                .select()
                .eq("status", value: status.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else if let search = search, !search.isEmpty {
            creations = try await client.from("creations")
                .select()
                .ilike("name", pattern: "%\(search)%")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else {
            creations = try await client.from("creations")
                .select("id, creation_type, name, slug, description, status, is_public, version, created_at, updated_at, thumbnail_url, deployed_url, react_code, visibility, view_count, install_count, deleted_at")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        }

        // Filter out soft-deleted creations
        return creations.filter { $0.deletedAt == nil }
    }

    func fetchCreation(id: UUID) async throws -> Creation {
        return try await client.from("creations")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createCreation(_ creation: CreationInsert) async throws -> Creation {
        return try await client.from("creations")
            .insert(creation)
            .select()
            .single()
            .execute()
            .value
    }

    func updateCreation(id: UUID, update: CreationUpdate) async throws -> Creation {
        return try await client.from("creations")
            .update(update)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteCreation(id: UUID) async throws {
        // Soft delete: set deleted_at instead of hard delete
        try await client.from("creations")
            .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Collections

    func fetchCollections(limit: Int = 100) async throws -> [CreationCollection] {
        // Explicitly select columns to avoid decoding issues with design_system JSONB
        return try await client.from("creation_collections")
            .select("id, store_id, location_id, name, slug, description, launcher_style, background_color, accent_color, logo_url, is_public, requires_auth, created_at, updated_at, visibility, is_pinned, pinned_at, pin_order, is_template")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchCollection(id: UUID) async throws -> CreationCollection {
        return try await client.from("creation_collections")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createCollection(_ collection: CollectionInsert) async throws -> CreationCollection {
        return try await client.from("creation_collections")
            .insert(collection)
            .select()
            .single()
            .execute()
            .value
    }

    func updateCollection(id: UUID, update: CollectionUpdate) async throws -> CreationCollection {
        return try await client.from("creation_collections")
            .update(update)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteCollection(id: UUID) async throws {
        try await client.from("creation_collections")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Collection Items

    func fetchCollectionItems(collectionId: UUID) async throws -> [CreationCollectionItem] {
        return try await client.from("creation_collection_items")
            .select()
            .eq("collection_id", value: collectionId)
            .order("position", ascending: true)
            .execute()
            .value
    }

    func addToCollection(_ item: CollectionItemInsert) async throws -> CreationCollectionItem {
        return try await client.from("creation_collection_items")
            .insert(item)
            .select()
            .single()
            .execute()
            .value
    }

    func removeFromCollection(itemId: UUID) async throws {
        try await client.from("creation_collection_items")
            .delete()
            .eq("id", value: itemId)
            .execute()
    }

    func updateCollectionItemPosition(itemId: UUID, position: Int) async throws {
        try await client.from("creation_collection_items")
            .update(["position": position])
            .eq("id", value: itemId)
            .execute()
    }

    // MARK: - Fetch collection with creations

    func fetchCollectionWithCreations(id: UUID) async throws -> CollectionWithItems {
        let collection = try await fetchCollection(id: id)
        let items = try await fetchCollectionItems(collectionId: id)

        var creations: [Creation] = []
        for item in items {
            if let creation = try? await fetchCreation(id: item.creationId) {
                creations.append(creation)
            }
        }

        return CollectionWithItems(collection: collection, items: items, creations: creations)
    }

    // MARK: - Stats

    func fetchCreationStats() async throws -> (total: Int, byType: [CreationType: Int], byStatus: [CreationStatus: Int]) {
        let creations: [Creation] = try await client.from("creations")
            .select("id, creation_type, status")
            .execute()
            .value

        var byType: [CreationType: Int] = [:]
        var byStatus: [CreationStatus: Int] = [:]

        for creation in creations {
            byType[creation.creationType, default: 0] += 1
            if let status = creation.status {
                byStatus[status, default: 0] += 1
            }
        }

        return (creations.count, byType, byStatus)
    }
}
