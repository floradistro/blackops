import Foundation

// MARK: - EditorStore AI Agents Extension

extension EditorStore {

    // MARK: - Load AI Agents

    func loadAIAgents() async {
        guard let storeId = selectedStore?.id else {
            print("[AIAgents] No store selected")
            await MainActor.run { self.aiAgents = [] }
            return
        }

        print("[AIAgents] Loading for store: \(storeId)")
        await MainActor.run { isLoadingAgents = true }
        defer { Task { @MainActor in isLoadingAgents = false } }

        do {
            // Query active agents for this store (use lowercase UUID to match Postgres)
            let response = try await supabase.client
                .from("ai_agent_config")
                .select()
                .eq("is_active", value: true)
                .eq("store_id", value: storeId.uuidString.lowercased())
                .execute()

            print("[AIAgents] Response: \(String(data: response.data, encoding: .utf8) ?? "nil")")

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601

            let agents = try decoder.decode([AIAgent].self, from: response.data)
            print("[AIAgents] Decoded \(agents.count) agents")

            await MainActor.run {
                self.aiAgents = agents
                print("[AIAgents] Set aiAgents to \(agents.count)")
            }
        } catch {
            print("[AIAgents] Failed to load: \(error)")
            await MainActor.run { self.aiAgents = [] }
        }
    }

    // MARK: - Select Agent

    func selectAIAgent(_ agent: AIAgent) {
        selectedAIAgent = agent
        // TODO: Open agent chat or config view
    }
}
