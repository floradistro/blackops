import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @State private var store = EditorStore()

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
        .environment(\.editorStore, store)
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
        .environmentObject(AppState.shared)
        .modelContainer(for: [], inMemory: true)
}
