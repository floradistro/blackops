import SwiftUI

// MARK: - Sidebar AI Agents Section
// Ultra minimal terminal style

struct SidebarAgentsSection: View {
    @ObservedObject var store: EditorStore
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(.easeOut(duration: 0.15)) {
                    store.sidebarAgentsExpanded.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.3))
                        .rotationEffect(.degrees(store.sidebarAgentsExpanded ? 90 : 0))
                        .frame(width: 10)

                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.primary.opacity(0.4))

                    Text("Agents")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.7))

                    Spacer()

                    if store.isLoadingAgents {
                        ProgressView()
                            .scaleEffect(0.4)
                            .frame(width: 12, height: 12)
                    } else if store.aiAgents.count > 0 {
                        Text("\(store.aiAgents.count)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.3))
                    }

                    if isHovering {
                        Button { store.createNewAgent() } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Color.primary.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }

            // Expanded Content
            if store.sidebarAgentsExpanded {
                if store.aiAgents.isEmpty && !store.isLoadingAgents {
                    Text("No agents")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.primary.opacity(0.3))
                        .padding(.leading, 24)
                        .padding(.vertical, 4)
                } else {
                    ForEach(store.aiAgents) { agent in
                        agentRow(agent)
                    }
                }
            }
        }
        .onAppear {
            Task { await store.loadAIAgents() }
        }
        .onChange(of: store.selectedStore?.id) { _, _ in
            Task { await store.loadAIAgents() }
        }
    }

    @ViewBuilder
    private func agentRow(_ agent: AIAgent) -> some View {
        let isSelected = store.selectedAIAgent?.id == agent.id

        Button {
            store.selectAIAgent(agent)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: agent.displayIcon)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.primary.opacity(isSelected ? 0.7 : 0.4))
                    .frame(width: 14)

                Text(agent.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(isSelected ? 0.9 : 0.6))
                    .lineLimit(1)

                Spacer()

                if agent.isActive {
                    Circle()
                        .fill(Color.primary.opacity(0.2))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .padding(.leading, 14)
            .background(isSelected ? Color.primary.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
