import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.editorStore) private var store

    var body: some View {
        Group {
            if authManager.isLoading {
                loadingView
            } else if authManager.isAuthenticated {
                AppleContentView()
            } else {
                AuthView()
            }
        }
        .font(DesignSystem.Typography.body)  // Apply 17pt default to all text
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .freezeDebugLifecycle("ContentView")
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.95))
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
}
