import SwiftUI

// MARK: - Sidebar Agent Builder Section
// Premium monochromatic design

struct SidebarAgentBuilderSection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        Button {
            store.openTab(.agentBuilder)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.5))

                Text("Agent Builder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.85))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.3))
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(store.activeTab == .agentBuilder ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Build and configure AI agents")
    }
}
