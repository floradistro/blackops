import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isSignUp = false

    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case email, password, confirmPassword
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            Image(systemName: "cube.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Swag Manager")
                .font(.title)
                .fontWeight(.semibold)

            // Form
            VStack(spacing: 12) {
                TextField("Email", text: $authManager.email)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .email)
                    .onSubmit {
                        focusedField = .password
                    }

                SecureField("Password", text: $authManager.password)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        if isSignUp {
                            focusedField = .confirmPassword
                        } else {
                            submit()
                        }
                    }

                if isSignUp {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .confirmPassword)
                        .onSubmit {
                            submit()
                        }
                }

                Button(isSignUp ? "Create Account" : "Sign In") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || !isFormValid)
                .padding(.top, 8)
            }
            .frame(width: 260)

            Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                isSignUp.toggle()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            focusedField = .email
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private var isFormValid: Bool {
        authManager.email.contains("@") && authManager.password.count >= 6 && (!isSignUp || authManager.password == confirmPassword)
    }

    private func submit() {
        guard isFormValid else { return }
        isLoading = true
        Task {
            do {
                if isSignUp {
                    try await authManager.signUp(email: authManager.email, password: authManager.password)
                } else {
                    try await authManager.signIn(email: authManager.email, password: authManager.password)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager.shared)
}