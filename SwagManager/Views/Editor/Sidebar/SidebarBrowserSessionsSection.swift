import SwiftUI

// MARK: - Sidebar Browser Sessions Section
// Extracted from EditorSidebarView.swift following Apple engineering standards
// File size: ~84 lines (under Apple's 300 line "excellent" threshold)

struct SidebarBrowserSessionsSection: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        BrowserSessionsSectionHeader(
            isExpanded: $store.sidebarBrowserExpanded,
            count: store.browserSessions.filter { $0.isActive }.count,
            isLoading: store.isLoadingBrowserSessions,
            onNewSession: {
                Task {
                    await store.createNewBrowserSession()
                }
            }
        )

        if store.sidebarBrowserExpanded {
            if store.selectedStore == nil {
                Text("Select a store")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            } else if store.browserSessions.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("No browser sessions")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundStyle(.tertiary)
                    Text("Sessions will appear here when AI browses the web")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
            } else {
                // Active sessions
                let activeSessions = store.browserSessions.filter { $0.isActive }
                if !activeSessions.isEmpty {
                    ChatSectionLabel(title: "Active")
                    ForEach(activeSessions) { session in
                        BrowserSessionItem(
                            session: session,
                            isSelected: store.selectedBrowserSession?.id == session.id,
                            onTap: { store.openBrowserSession(session) },
                            onClose: {
                                Task {
                                    await store.closeBrowserSession(session)
                                }
                            }
                        )
                    }
                }

                // Recent closed sessions
                let closedSessions = store.browserSessions.filter { !$0.isActive }.prefix(5)
                if !closedSessions.isEmpty {
                    ChatSectionLabel(title: "Recent")
                    ForEach(Array(closedSessions)) { session in
                        BrowserSessionItem(
                            session: session,
                            isSelected: store.selectedBrowserSession?.id == session.id,
                            onTap: { store.openBrowserSession(session) },
                            onClose: {
                                Task {
                                    await store.closeBrowserSession(session)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}
