import SwiftUI

// MARK: - EditorStore AI Agents Extension
// Handles loading and managing AI agents

// MARK: - Agent Update Payload

private struct AgentUpdatePayload: Encodable {
    let name: String
    let description: String
    let icon: String?
    let accentColor: String?
    let systemPrompt: String
    let model: String
    let temperature: Double
    let maxTokens: Int
    let maxToolCalls: Int?
    let isActive: Bool
    let status: String?
    let enabledTools: [String]
    let tone: String
    let verbosity: String
    let canQuery: Bool
    let canSend: Bool
    let canModify: Bool
    let apiKey: String?
    let contextConfig: AgentContextConfig?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case icon
        case accentColor = "accent_color"
        case systemPrompt = "system_prompt"
        case model
        case temperature
        case maxTokens = "max_tokens"
        case maxToolCalls = "max_tool_calls"
        case isActive = "is_active"
        case status
        case enabledTools = "enabled_tools"
        case tone
        case verbosity
        case canQuery = "can_query"
        case canSend = "can_send"
        case canModify = "can_modify"
        case apiKey = "api_key"
        case contextConfig = "context_config"
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
            // Include both store-specific agents AND global agents (store_id IS NULL)
            let response: [AIAgent] = try await SupabaseService.shared.adminClient
                .from("ai_agent_config")
                .select()
                .or("store_id.eq.\(storeId.uuidString),store_id.is.null")
                .order("created_at", ascending: false)
                .execute()
                .value

            aiAgents = response
        } catch is CancellationError {
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            self.error = "Failed to load agents: \(error.localizedDescription)"
            self.showError = true
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
            self.error = "Failed to toggle agent: \(error.localizedDescription)"
            self.showError = true
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
            self.error = "Failed to create agent: \(error.localizedDescription)"
            self.showError = true
            return nil
        }
    }

    // MARK: - Update Agent (full)

    @MainActor
    func updateAgent(_ agent: AIAgent) async {
        let updatePayload = AgentUpdatePayload(
            name: agent.name ?? "",
            description: agent.description ?? "",
            icon: agent.icon,
            accentColor: agent.accentColor,
            systemPrompt: agent.systemPrompt ?? "",
            model: agent.model ?? "claude-sonnet-4-20250514",
            temperature: agent.temperature ?? 0.7,
            maxTokens: agent.maxTokens ?? 32000,
            maxToolCalls: agent.maxToolCalls,
            isActive: agent.isActive,
            status: agent.status ?? "draft",
            enabledTools: agent.enabledTools ?? [],
            tone: agent.tone ?? "professional",
            verbosity: agent.verbosity ?? "moderate",
            canQuery: agent.canQuery ?? true,
            canSend: agent.canSend ?? false,
            canModify: agent.canModify ?? false,
            apiKey: agent.apiKey,
            contextConfig: agent.contextConfig
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
            self.error = "Failed to update agent: \(error.localizedDescription)"
            self.showError = true
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
            self.error = "Failed to delete agent: \(error.localizedDescription)"
            self.showError = true
        }
    }
}
