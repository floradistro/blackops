import SwiftUI

// MARK: - Sidebar Loading State
// Minimal terminal-style loading

struct SidebarLoadingState: View {
    var body: some View {
        Spacer()
        Text("Loading···")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Color.primary.opacity(0.3))
        Spacer()
    }
}
