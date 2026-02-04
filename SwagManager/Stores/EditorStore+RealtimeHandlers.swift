import SwiftUI
import Supabase
import Realtime

// MARK: - EditorStore Realtime Handlers Extension
// Extracted from EditorStore+RealtimeSync.swift following Apple engineering standards
// File size: ~230 lines (under Apple's 300 line "excellent" threshold)

extension EditorStore {
    // MARK: - Event Processing

    internal func processRealtimeEvents(
        creationsInserts: AsyncStream<InsertAction>,
        creationsUpdates: AsyncStream<UpdateAction>,
        creationsDeletes: AsyncStream<DeleteAction>,
        collectionsInserts: AsyncStream<InsertAction>,
        collectionsUpdates: AsyncStream<UpdateAction>,
        collectionsDeletes: AsyncStream<DeleteAction>,
        collectionItemsInserts: AsyncStream<InsertAction>,
        collectionItemsDeletes: AsyncStream<DeleteAction>,
        browserSessionsInserts: AsyncStream<InsertAction>,
        browserSessionsUpdates: AsyncStream<UpdateAction>,
        browserSessionsDeletes: AsyncStream<DeleteAction>
    ) async {
        // Keep processing events in parallel
        await withTaskGroup(of: Void.self) { group in
            // Handle creations inserts
            group.addTask {
                for await insert in creationsInserts {
                    await MainActor.run {
                        if let creation = try? insert.decodeRecord(as: Creation.self, decoder: JSONDecoder.supabaseDecoder) {
                            if !self.creations.contains(where: { $0.id == creation.id }) {
                                self.creations.insert(creation, at: 0)
                            }
                        } else {
                            Task { await self.loadCreations() }
                        }
                    }
                }
            }

            // Handle creations updates
            group.addTask {
                for await update in creationsUpdates {
                    await MainActor.run {
                        if let creation = try? update.decodeRecord(as: Creation.self, decoder: JSONDecoder.supabaseDecoder) {
                            if let idx = self.creations.firstIndex(where: { $0.id == creation.id }) {
                                self.creations[idx] = creation
                                if self.selectedCreation?.id == creation.id {
                                    self.selectedCreation = creation
                                    // Don't overwrite editedCode if user has local changes
                                    if self.editedCode == nil || !self.hasUnsavedChanges {
                                        self.editedCode = creation.reactCode
                                    }
                                    self.refreshTrigger = UUID()
                                }
                            }
                        }
                    }
                }
            }

            // Handle creations deletes
            group.addTask {
                for await delete in creationsDeletes {
                    await MainActor.run {
                        let oldRecord = delete.oldRecord
                        if let idString = oldRecord["id"]?.stringValue,
                           let id = UUID(uuidString: idString) {
                            self.creations.removeAll { $0.id == id }
                            self.selectedCreationIds.remove(id)
                            if self.selectedCreation?.id == id {
                                self.selectedCreation = nil
                                self.editedCode = nil
                            }
                        }
                    }
                }
            }

            // Handle collections inserts
            group.addTask {
                for await insert in collectionsInserts {
                    await MainActor.run {
                        if let collection = try? insert.decodeRecord(as: CreationCollection.self, decoder: JSONDecoder.supabaseDecoder) {
                            if !self.collections.contains(where: { $0.id == collection.id }) {
                                self.collections.insert(collection, at: 0)
                            }
                        } else {
                            Task {
                                self.collections = try await self.supabase.fetchCollections()
                            }
                        }
                    }
                }
            }

            // Handle collections updates
            group.addTask {
                for await update in collectionsUpdates {
                    await MainActor.run {
                        if let collection = try? update.decodeRecord(as: CreationCollection.self, decoder: JSONDecoder.supabaseDecoder) {
                            if let idx = self.collections.firstIndex(where: { $0.id == collection.id }) {
                                self.collections[idx] = collection
                            }
                        }
                    }
                }
            }

            // Handle collections deletes
            group.addTask {
                for await delete in collectionsDeletes {
                    await MainActor.run {
                        let oldRecord = delete.oldRecord
                        if let idString = oldRecord["id"]?.stringValue,
                           let id = UUID(uuidString: idString) {
                            self.collections.removeAll { $0.id == id }
                            self.collectionItems.removeValue(forKey: id)
                        }
                    }
                }
            }

            // Handle collection items inserts
            group.addTask {
                for await insert in collectionItemsInserts {
                    await MainActor.run {
                        let record = insert.record
                        if let collectionIdStr = record["collection_id"]?.stringValue,
                           let creationIdStr = record["creation_id"]?.stringValue,
                           let collectionId = UUID(uuidString: collectionIdStr),
                           let creationId = UUID(uuidString: creationIdStr) {
                            if self.collectionItems[collectionId] == nil {
                                self.collectionItems[collectionId] = []
                            }
                            if !self.collectionItems[collectionId]!.contains(creationId) {
                                self.collectionItems[collectionId]!.append(creationId)
                            }
                        }
                    }
                }
            }

            // Handle collection items deletes
            group.addTask {
                for await delete in collectionItemsDeletes {
                    await MainActor.run {
                        let oldRecord = delete.oldRecord
                        if let collectionIdStr = oldRecord["collection_id"]?.stringValue,
                           let creationIdStr = oldRecord["creation_id"]?.stringValue,
                           let collectionId = UUID(uuidString: collectionIdStr),
                           let creationId = UUID(uuidString: creationIdStr) {
                            self.collectionItems[collectionId]?.removeAll { $0 == creationId }
                        }
                    }
                }
            }

            // Handle browser sessions inserts
            group.addTask {
                for await insert in browserSessionsInserts {
                    await MainActor.run {
                        if let session = try? insert.decodeRecord(as: BrowserSession.self, decoder: JSONDecoder.supabaseDecoder) {
                            // Only add if it belongs to current store
                            if session.storeId == self.selectedStore?.id {
                                if !self.browserSessions.contains(where: { $0.id == session.id }) {
                                    self.browserSessions.insert(session, at: 0)
                                }
                            }
                        } else {
                        }
                    }
                }
            }

            // Handle browser sessions updates
            group.addTask {
                for await update in browserSessionsUpdates {
                    await MainActor.run {
                        if let session = try? update.decodeRecord(as: BrowserSession.self, decoder: JSONDecoder.supabaseDecoder) {
                            if let idx = self.browserSessions.firstIndex(where: { $0.id == session.id }) {
                                self.browserSessions[idx] = session
                                // Update selected if this is the selected one
                                if self.selectedBrowserSession?.id == session.id {
                                    self.selectedBrowserSession = session
                                }
                                // Update in open tabs
                                if let tabIndex = self.openTabs.firstIndex(where: {
                                    if case .browserSession(let s) = $0, s.id == session.id { return true }
                                    return false
                                }) {
                                    self.openTabs[tabIndex] = .browserSession(session)
                                }
                                if case .browserSession(let s) = self.activeTab, s.id == session.id {
                                    self.activeTab = .browserSession(session)
                                }
                            }
                        }
                    }
                }
            }

            // Handle browser sessions deletes
            group.addTask {
                for await delete in browserSessionsDeletes {
                    await MainActor.run {
                        let oldRecord = delete.oldRecord
                        if let idString = oldRecord["id"]?.stringValue,
                           let id = UUID(uuidString: idString) {
                            self.browserSessions.removeAll { $0.id == id }
                            if self.selectedBrowserSession?.id == id {
                                self.selectedBrowserSession = nil
                            }
                            // Close tab if open
                            self.openTabs.removeAll {
                                if case .browserSession(let s) = $0, s.id == id { return true }
                                return false
                            }
                            if case .browserSession(let s) = self.activeTab, s.id == id {
                                self.activeTab = self.openTabs.first
                            }
                        }
                    }
                }
            }
        }
    }
}
