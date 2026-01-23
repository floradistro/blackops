import Foundation

// MARK: - EditorStore AI Agents Extension

extension EditorStore {

    // MARK: - Load AI Agents

    func loadAIAgents() async {
        guard let storeId = selectedStore?.id else {
            await MainActor.run { self.aiAgents = [] }
            return
        }

        await MainActor.run { isLoadingAgents = true }
        defer { Task { @MainActor in isLoadingAgents = false } }

        do {
            // Query active agents for this store
            let response = try await supabase.client
                .from("ai_agent_config")
                .select()
                .eq("is_active", value: true)
                .eq("store_id", value: storeId.uuidString)
                .execute()

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601

            let agents = try decoder.decode([AIAgent].self, from: response.data)

            await MainActor.run {
                self.aiAgents = agents
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
