import SwiftUI
import AppKit

struct AuthView: View {
    @Environment(\.authManager) private var authManager
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if let window = NSApp.windows.first(where: { $0.isVisible }) {
                        window.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: DesignSystem.Spacing.xxl) {
                    // Logo
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "square.grid.3x3.topleft.filled")
                            .font(DesignSystem.font(48, weight: .light))
                            .foregroundStyle(DesignSystem.Colors.accent)

                        Text("Swag Manager")
                            .font(DesignSystem.Typography.title1)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Text("Sign in to continue")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    // Form
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Email
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: "envelope")
                                .font(DesignSystem.font(14))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .frame(width: 20)
                            TextField("Email", text: $email)
                                .textFieldStyle(.plain)
                                .textContentType(.emailAddress)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                        )

                        // Password
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: "lock")
                                .font(DesignSystem.font(14))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .frame(width: 20)
                            SecureField("Password", text: $password)
                                .textFieldStyle(.plain)
                                .textContentType(.password)
                                .onSubmit { login() }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: 320)

                    // Error
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundStyle(DesignSystem.Colors.error)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }

                    // Sign In
                    Button {
                        login()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Sign In")
                                .font(DesignSystem.Typography.button)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: 320)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                }
                .padding(40) // Keep non-grid value as-is

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground(material: .underWindowBackground))
        .onAppear {
            for delay in [0.1, 0.3, 0.5] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
                        window.makeKeyAndOrderFront(nil)
                        window.orderFrontRegardless()
                        window.makeMain()
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            }
        }
    }

    private func login() {
        guard !email.isEmpty, !password.isEmpty else { return }
        errorMessage = ""
        isLoading = true

        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    AuthView()
}
