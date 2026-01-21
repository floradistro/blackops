import SwiftUI

// MARK: - MCP Server Detail View
// Simplified - uses single comprehensive developer view (no tabs)

struct MCPServerDetailView: View {
    let server: MCPServer
    @ObservedObject var store: EditorStore

    var body: some View {
        MCPDeveloperView(server: server, store: store)
            .id("mcp-dev-\(server.id)")
            .onAppear {
                NSLog("[MCPServerDetailView] Loaded server: \(server.name)")
            }
    }
}
