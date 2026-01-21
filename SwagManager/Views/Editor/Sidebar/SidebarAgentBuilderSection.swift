import SwiftUI

// MARK: - Sidebar Agent Builder Section
// Follows Apple HIG and matches existing sidebar sections

struct SidebarAgentBuilderSection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        Button {
            store.openTab(.agentBuilder)
        } label: {
            HStack(spacing: DesignSystem.TreeSpacing.iconSpacing) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: DesignSystem.TreeSpacing.iconSize))
                    .foregroundStyle(.purple)

                Text("Agent Builder")
                    .font(.system(size: DesignSystem.TreeSpacing.primaryTextSize))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: DesignSystem.TreeSpacing.chevronSize - 1))
                    .foregroundStyle(.tertiary)
            }
            .frame(height: DesignSystem.TreeSpacing.itemHeight)
            .padding(.horizontal, DesignSystem.TreeSpacing.itemPaddingHorizontal)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(store.activeTab == .agentBuilder ? DesignSystem.Colors.selectionActive : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Build and configure AI agents")
    }
}
