import SwiftUI
import AppKit

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            // Invisible background that accepts clicks to make window key
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if let window = NSApp.windows.first(where: { $0.isVisible }) {
                        window.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }

            VStack(spacing: 20) {
                Text("Swag Manager Login")
                    .font(.largeTitle)
                    .padding(.bottom, 40)

                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .frame(height: 30)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .frame(height: 30)
                        .onSubmit { login() }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Button("Sign In") {
                        login()
                    }
                    .keyboardShortcut(.return)
                    .padding(.top, 10)
                }
                .frame(width: 350)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            FreezeDebugger.onAppear("AuthView")
            // FORCE the window to become key - multiple attempts
            for delay in [0.1, 0.3, 0.5] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    NSApp.activate(ignoringOtherApps: true)

                    if let window = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
                        // Try multiple methods to force it
                        window.makeKeyAndOrderFront(nil)
                        window.orderFrontRegardless()
                        window.makeMain()
                        NSApp.activate(ignoringOtherApps: true)

                    }
                }
            }
        }
        .onDisappear {
            FreezeDebugger.onDisappear("AuthView")
        }
    }

    private func login() {
        errorMessage = ""

        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager.shared)
}