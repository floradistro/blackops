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
            // Use flexible date parsing for Postgres timestamps with timezone
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Try ISO8601 with fractional seconds
                let formatterWithFraction = ISO8601DateFormatter()
                formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatterWithFraction.date(from: dateString) {
                    return date
                }

                // Try ISO8601 without fractional seconds
                let formatterNoFraction = ISO8601DateFormatter()
                formatterNoFraction.formatOptions = [.withInternetDateTime]
                if let date = formatterNoFraction.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }

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
        editingAgent = agent
        showAgentConfigSheet = true
    }

    // MARK: - Create New Agent

    func createNewAgent() {
        editingAgent = nil  // nil means new agent
        showAgentConfigSheet = true
    }
}
