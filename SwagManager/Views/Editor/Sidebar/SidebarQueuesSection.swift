import SwiftUI

// MARK: - Sidebar Queues Section
// Following Apple engineering standards

struct SidebarQueuesSection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        TreeSectionHeader(
            title: "QUEUES",
            isExpanded: $store.sidebarQueuesExpanded,
            count: store.locations.count
        )
        .padding(.top, DesignSystem.Spacing.xxs)

        if store.sidebarQueuesExpanded {
            ForEach(store.locations) { location in
                Button {
                    store.openQueue(location)
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Spacer().frame(width: 10)

                        Image(systemName: "person.3.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                            .frame(width: 16)

                        Text(location.name)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(store.selectedQueue?.id == location.id ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                            .lineLimit(1)

                        Spacer()

                        if location.isActive == true {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        }

                        // Realtime indicator
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .fill(store.selectedQueue?.id == location.id ? DesignSystem.Colors.selectionActive : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(TreeItemButtonStyle())
                .contextMenu {
                    Button("View Queue") {
                        store.openQueue(location)
                    }
                }
            }

            // Empty state
            if store.locations.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("No locations")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
    }
}
