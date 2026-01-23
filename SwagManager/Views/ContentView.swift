import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState

    // Toggle to switch between old and new navigation (for testing)
    @AppStorage("useNativeNavigation") private var useNativeNavigation = true

    var body: some View {
        Group {
            if authManager.isLoading {
                loadingView
            } else if authManager.isAuthenticated {
                if useNativeNavigation {
                    NativeEditorView()
                } else {
                    EditorView()
                }
            } else {
                AuthView()
            }
        }
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
}
