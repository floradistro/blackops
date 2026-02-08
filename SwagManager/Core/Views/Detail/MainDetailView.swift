import SwiftUI

// MARK: - Main Detail View
// Routes sidebar selections to content views

struct MainDetailView: View {
    @Binding var selection: SDSidebarItem?
    @Environment(\.editorStore) private var store

    var body: some View {
        Group {
            switch selection {
            case .agents:
                AgentsListView(selection: $selection, storeId: store.currentStoreId)

            case .agentDetail(let id):
                AgentDetailWrapper(agentId: id)

            case .telemetry:
                TelemetryPanel(storeId: store.selectedStore?.id)

            case .none:
                WelcomeView()
            }
        }
        .freezeDebugLifecycle("MainDetailView")
    }
}

// MARK: - Agents List

struct AgentsListView: View {
    @Environment(\.editorStore) private var store
    @Binding var selection: SDSidebarItem?
    let storeId: UUID

    var body: some View {
        Group {
            if store.aiAgents.isEmpty {
                ContentUnavailableView("No AI Agents", systemImage: "cpu", description: Text("Create agents to automate tasks"))
            } else {
                List {
                    ForEach(store.aiAgents) { agent in
                        NavigationLink(value: SDSidebarItem.agentDetail(agent.id)) {
                            AgentListRow(agent: agent)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("")
    }
}

struct AgentListRow: View {
    let agent: AIAgent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: agent.displayIcon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName)
                    .font(.subheadline.weight(.medium))
                if let prompt = agent.systemPrompt {
                    Text(String(prompt.prefix(60)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Circle()
                .fill(agent.isActive ? DesignSystem.Colors.success : DesignSystem.Colors.textQuaternary)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Agent Manager", systemImage: "cpu")
        } description: {
            Text("Select an agent from the sidebar")
        }
        .navigationTitle("")
    }
}
