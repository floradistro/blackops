import Foundation
import Supabase
import Auth

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var session: Session?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var error: String?
    @Published var email = ""
    @Published var password = ""

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private init() {
        Task {
            await checkSession()
            await listenToAuthChanges()
        }
    }

    private func checkSession() async {
        isLoading = true
        do {
            session = try await supabase.auth.session
            currentUser = session?.user
            isAuthenticated = session != nil
        } catch {
            // No active session
            isAuthenticated = false
        }
        isLoading = false
    }

    private func listenToAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .signedIn:
                self.session = session
                self.currentUser = session?.user
                self.isAuthenticated = true
            case .signedOut:
                self.session = nil
                self.currentUser = nil
                self.isAuthenticated = false
            case .tokenRefreshed:
                self.session = session
            default:
                break
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil
        do {
            let authSession = try await supabase.auth.signIn(email: email, password: password)
            session = authSession
            currentUser = authSession.user
            isAuthenticated = true
            // Clear password for security
            self.password = ""
        } catch {
            self.error = error.localizedDescription
            throw error
        }
        isLoading = false
    }

    func signUp(email: String, password: String) async throws {
        isLoading = true
        error = nil
        do {
            let response = try await supabase.auth.signUp(email: email, password: password)
            if let session = response.session {
                self.session = session
                self.currentUser = response.user
                self.isAuthenticated = true
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }
        isLoading = false
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        session = nil
        currentUser = nil
        isAuthenticated = false
    }

    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
}
