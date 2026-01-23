import SwiftUI

// MARK: - Sidebar AI Agents Section
// Premium monochromatic design

struct SidebarAgentsSection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(DesignSystem.Animation.spring) {
                    store.sidebarAgentsExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .rotationEffect(.degrees(store.sidebarAgentsExpanded ? 90 : 0))
                        .frame(width: 12)

                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.5))

                    Text("Agents")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.85))

                    Spacer()

                    LoadingCountBadge(
                        count: store.aiAgents.count,
                        isLoading: store.isLoadingAgents
                    )

                    // New agent button
                    Button {
                        store.createNewAgent()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.5))
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("New Agent")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded Content
            if store.sidebarAgentsExpanded {
                if store.aiAgents.isEmpty && !store.isLoadingAgents {
                    Text("No agents configured")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                } else {
                    ForEach(store.aiAgents) { agent in
                        agentRow(agent)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await store.loadAIAgents()
            }
        }
        .onChange(of: store.selectedStore?.id) { _, _ in
            Task {
                await store.loadAIAgents()
            }
        }
    }

    @ViewBuilder
    private func agentRow(_ agent: AIAgent) -> some View {
        let isSelected = store.selectedAIAgent?.id == agent.id

        Button {
            store.selectAIAgent(agent)
        } label: {
            HStack(spacing: 8) {
                // Agent icon - monochromatic circle
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 22, height: 22)

                    Image(systemName: agent.displayIcon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(agent.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.9))

                    Text(agent.shortDescription)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.primary.opacity(0.4))
                }

                Spacer()

                // Active indicator - subtle dot
                if agent.isActive {
                    Circle()
                        .fill(Color.primary.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .padding(.leading, 16)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
