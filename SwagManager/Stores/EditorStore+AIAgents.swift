import SwiftUI

// MARK: - EditorStore AI Agents Extension
// Handles loading and managing AI agents

// MARK: - Agent Update Payload

private struct AgentUpdatePayload: Encodable {
    let name: String
    let description: String
    let systemPrompt: String
    let model: String
    let temperature: Double
    let maxTokens: Int
    let isActive: Bool
    let enabledTools: [String]
    let tone: String
    let verbosity: String

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case systemPrompt = "system_prompt"
        case model
        case temperature
        case maxTokens = "max_tokens"
        case isActive = "is_active"
        case enabledTools = "enabled_tools"
        case tone
        case verbosity
    }
}

private struct AgentInsertPayload: Encodable {
    let storeId: UUID
    let name: String
    let systemPrompt: String
    let model: String
    let isActive: Bool
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case storeId = "store_id"
        case name
        case systemPrompt = "system_prompt"
        case model
        case isActive = "is_active"
        case temperature
        case maxTokens = "max_tokens"
    }
}

extension EditorStore {
    // MARK: - Load Agents

    func loadAIAgents() async {
        guard let storeId = selectedStore?.id else { return }
        isLoadingAgents = true

        do {
            // Use adminClient to bypass RLS for agent config
            let response: [AIAgent] = try await SupabaseService.shared.adminClient
                .from("ai_agent_config")
                .select()
                .eq("store_id", value: storeId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            aiAgents = response
        } catch {
            print("[Agent Load] Error: \(error)")
        }

        isLoadingAgents = false
    }

    // MARK: - Toggle Agent Status

    func toggleAgentStatus(_ agent: AIAgent) async {
        do {
            try await SupabaseService.shared.adminClient
                .from("ai_agent_config")
                .update(["is_active": !agent.isActive])
                .eq("id", value: agent.id.uuidString)
                .execute()

            await loadAIAgents()
        } catch {
            print("[Agent Toggle] Error: \(error)")
        }
    }

    // MARK: - Create Agent

    func createAgent(name: String, systemPrompt: String, model: String = "claude-sonnet-4-20250514") async -> AIAgent? {
        guard let storeId = selectedStore?.id else { return nil }

        let payload = AgentInsertPayload(
            storeId: storeId,
            name: name,
            systemPrompt: systemPrompt,
            model: model,
            isActive: true,
            temperature: 0.7,
            maxTokens: 32000
        )

        do {
            let newAgent: AIAgent = try await SupabaseService.shared.adminClient
                .from("ai_agent_config")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value

            await loadAIAgents()
            return newAgent
        } catch {
            print("[Agent Create] Error: \(error)")
            return nil
        }
    }

    // MARK: - Update Agent (full)

    @MainActor
    func updateAgent(_ agent: AIAgent) async {
        let updatePayload = AgentUpdatePayload(
            name: agent.name ?? "",
            description: agent.description ?? "",
            systemPrompt: agent.systemPrompt ?? "",
            model: agent.model ?? "claude-sonnet-4-20250514",
            temperature: agent.temperature ?? 0.7,
            maxTokens: agent.maxTokens ?? 32000,
            isActive: agent.isActive,
            enabledTools: agent.enabledTools ?? [],
            tone: agent.tone ?? "professional",
            verbosity: agent.verbosity ?? "moderate"
        )

        print("[Agent Update] Updating agent \(agent.id): \(agent.name ?? "unnamed")")
        print("[Agent Update] Payload: name=\(updatePayload.name), model=\(updatePayload.model), temp=\(updatePayload.temperature)")

        do {
            let response = try await SupabaseService.shared.adminClient
                .from("ai_agent_config")
                .update(updatePayload)
                .eq("id", value: agent.id.uuidString)
                .select()
                .execute()

            print("[Agent Update] Success! Response: \(response.count) rows affected")
            await loadAIAgents()
        } catch {
            print("[Agent Update] ERROR: \(error)")
        }
    }

    // MARK: - Delete Agent

    func deleteAgent(_ agent: AIAgent) async {
        do {
            try await SupabaseService.shared.adminClient
                .from("ai_agent_config")
                .delete()
                .eq("id", value: agent.id.uuidString)
                .execute()

            await loadAIAgents()
        } catch {
            print("[Agent Delete] Error: \(error)")
        }
    }
}
