import SwiftUI
import Supabase

// MARK: - Browser Store (Focused on Browser Sessions)

/// Manages browser sessions and tabs
/// Single responsibility: Browser session lifecycle
@MainActor
class BrowserStore: ObservableObject {

    // MARK: - Published State

    @Published var browserSessions: [BrowserSession] = []
    @Published var selectedBrowserSession: BrowserSession?
    @Published var sidebarExpanded = false

    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Private State

    private var sessionIndex: [UUID: BrowserSession] = [:] // O(1) lookups
    private var realtimeTask: Task<Void, Never>?

    private let supabase = SupabaseService.shared

    // MARK: - Lifecycle

    init() {
        startRealtimeSubscription()
    }

    deinit {
        realtimeTask?.cancel()
    }

    // MARK: - Data Loading

    func loadBrowserSessions(storeId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            browserSessions = try await supabase.fetchBrowserSessions(storeId: storeId)
            rebuildIndex()
            NSLog("[BrowserStore] Loaded \(browserSessions.count) browser sessions")
        } catch {
            NSLog("[BrowserStore] Error loading browser sessions: \(error)")
            self.error = "Failed to load browser sessions: \(error.localizedDescription)"
        }
    }

    // MARK: - Selection Management

    func selectBrowserSession(_ session: BrowserSession) {
        selectedBrowserSession = session
    }

    func clearSelection() {
        selectedBrowserSession = nil
    }

    // MARK: - CRUD Operations

    func deleteBrowserSession(_ session: BrowserSession) async {
        do {
            try await supabase.deleteBrowserSession(id: session.id)
            if selectedBrowserSession?.id == session.id {
                selectedBrowserSession = nil
            }
            removeSessionFromStore(session.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func rebuildIndex() {
        sessionIndex = Dictionary(uniqueKeysWithValues: browserSessions.map { ($0.id, $0) })
    }

    private func updateSessionInStore(_ session: BrowserSession) {
        sessionIndex[session.id] = session
        if let idx = browserSessions.firstIndex(where: { $0.id == session.id }) {
            browserSessions[idx] = session
        }
    }

    private func addSessionToStore(_ session: BrowserSession) {
        guard sessionIndex[session.id] == nil else { return }
        sessionIndex[session.id] = session
        browserSessions.insert(session, at: 0)
    }

    private func removeSessionFromStore(_ id: UUID) {
        sessionIndex.removeValue(forKey: id)
        browserSessions.removeAll { $0.id == id }
    }

    // MARK: - Realtime Subscriptions

    private func startRealtimeSubscription() {
        realtimeTask = Task { [weak self] in
            guard let self = self else { return }

            let client = self.supabase.client
            let channel = client.realtimeV2.channel("browser-changes")

            let sessionsInserts = channel.postgresChange(InsertAction.self, table: "browser_sessions")
            let sessionsUpdates = channel.postgresChange(UpdateAction.self, table: "browser_sessions")
            let sessionsDeletes = channel.postgresChange(DeleteAction.self, table: "browser_sessions")

            do {
                try await channel.subscribeWithError()
                NSLog("[BrowserStore] Realtime: Successfully subscribed")
            } catch {
                NSLog("[BrowserStore] Realtime: Failed to subscribe - \(error)")
                return
            }

            await withTaskGroup(of: Void.self) { group in
                // Handle inserts
                group.addTask {
                    for await insert in sessionsInserts {
                        await MainActor.run {
                            if let session = try? insert.decodeRecord(as: BrowserSession.self, decoder: JSONDecoder.supabaseDecoder) {
                                self.addSessionToStore(session)
                                NSLog("[BrowserStore] Realtime: Added session '\(session.displayName)'")
                            }
                        }
                    }
                }

                // Handle updates
                group.addTask {
                    for await update in sessionsUpdates {
                        await MainActor.run {
                            if let session = try? update.decodeRecord(as: BrowserSession.self, decoder: JSONDecoder.supabaseDecoder) {
                                self.updateSessionInStore(session)
                                if self.selectedBrowserSession?.id == session.id {
                                    self.selectedBrowserSession = session
                                }
                                NSLog("[BrowserStore] Realtime: Updated session '\(session.displayName)'")
                            }
                        }
                    }
                }

                // Handle deletes
                group.addTask {
                    for await delete in sessionsDeletes {
                        await MainActor.run {
                            if let idString = delete.oldRecord["id"]?.stringValue,
                               let id = UUID(uuidString: idString) {
                                self.removeSessionFromStore(id)
                                if self.selectedBrowserSession?.id == id {
                                    self.selectedBrowserSession = nil
                                }
                                NSLog("[BrowserStore] Realtime: Removed session \(idString)")
                            }
                        }
                    }
                }
            }
        }
    }
}
