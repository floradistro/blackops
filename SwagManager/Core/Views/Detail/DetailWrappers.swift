import SwiftUI

// MARK: - Agent Detail Wrapper

struct AgentDetailWrapper: View {
    let agentId: UUID
    @Environment(\.editorStore) private var store

    var body: some View {
        if let agent = store.aiAgents.first(where: { $0.id == agentId }) {
            AgentConfigPanel(agent: agent)
        } else {
            ContentUnavailableView("Agent not found", systemImage: "cpu")
        }
    }
}
