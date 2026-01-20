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
                        print("🖱️ Background clicked - activating window")
                    }
                }

            VStack(spacing: 20) {
                Text("Swag Manager Login")
                    .font(.largeTitle)
                    .padding(.bottom, 40)

                VStack(spacing: 15) {
                    NativeTextField(text: $email, placeholder: "Email") {
                        // Focus password field
                    }
                    .frame(height: 30)

                    NativeSecureField(text: $password, placeholder: "Password") {
                        login()
                    }
                    .frame(height: 30)

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

                        print("🪟 Attempt \(delay): Window isKeyWindow: \(window.isKeyWindow), isMainWindow: \(window.isMainWindow)")
                    }
                }
            }
        }
    }

    private func login() {
        print("🔐 Login attempt: \(email)")
        errorMessage = ""

        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
                print("❌ Login error: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager.shared)
}