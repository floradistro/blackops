import SwiftUI

// MARK: - Safari Tab Bar
// Extracted from SafariBrowserWindow.swift following Apple engineering standards
// File size: ~22 lines (under Apple's 300 line "excellent" threshold)

struct SafariTabBar: View {
    @ObservedObject var tabManager: BrowserTabManager
    @Binding var showTabs: Bool

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(tabManager.tabs) { tab in
                    SafariTabItem(
                        tab: tab,
                        isActive: tab.id == tabManager.activeTab?.id,
                        onSelect: { tabManager.selectTab(tab) },
                        onClose: { tabManager.closeTab(tab) }
                    )
                    .frame(width: geometry.size.width / CGFloat(max(1, tabManager.tabs.count)))
                }
            }
        }
        .frame(height: 36)
        .background(DesignSystem.Colors.surfacePrimary)
    }
}
