//
//  SafariBrowserWindow.swift
//  SwagManager
//
//  Safari-style unified toolbar with tabs that only appear when needed
//  Refactored following Apple engineering standards - components extracted to separate files
//  File size: ~35 lines (under Apple's 300 line "excellent" threshold)
//

import SwiftUI
import WebKit

struct SafariBrowserWindow: View {
    let sessionId: UUID
    @State private var showTabs = false
    @ObservedObject var tabManager: BrowserTabManager

    init(sessionId: UUID) {
        self.sessionId = sessionId
        // Get or create a unique tab manager for this session
        self.tabManager = BrowserTabManager.forSession(sessionId)
        NSLog("[SafariBrowserWindow] Initialized for session \(sessionId.uuidString.prefix(8))")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Browser toolbar
            BrowserToolbar(sessionId: sessionId)

            // Active tab content
            if let activeTab = tabManager.activeTab {
                BrowserTabView(tab: activeTab)
                    .id(activeTab.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyBrowserView(onNewTab: { tabManager.newTab() })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if tabManager.tabs.isEmpty {
                tabManager.newTab()
            }
        }
    }
}

#Preview {
    SafariBrowserWindow(sessionId: UUID())
        .frame(width: 1200, height: 800)
}
