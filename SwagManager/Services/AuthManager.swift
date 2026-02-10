import Foundation
import SwiftUI
import Supabase
import Auth

@MainActor
@Observable
class AuthManager {
    static let shared = AuthManager()

    var currentUser: User?
    var session: Session?
    var isAuthenticated = false
    var isLoading = true
    var error: String?
    var email = ""
    var password = ""

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
            // Add timeout to prevent hanging
            try await withTimeout(seconds: 3) {
                self.session = try await self.supabase.auth.session
                self.currentUser = self.session?.user
                self.isAuthenticated = self.session != nil
            }
        } catch {
            // No active session or timeout
            isAuthenticated = false
        }
        isLoading = false
    }

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "Timeout", code: -1, userInfo: nil)
            }

            // First task to complete wins; the other is cancelled
            guard let result = try await group.next() else {
                throw NSError(domain: "Timeout", code: -1, userInfo: nil)
            }
            group.cancelAll()
            return result
        }
    }

    private func listenToAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession:
                // With emitLocalSessionAsInitialSession: true, we get the cached session immediately.
                // Must check isExpired since the local session may be stale.
                if let session, !session.isExpired {
                    self.session = session
                    self.currentUser = session.user
                    self.isAuthenticated = true
                } else {
                    self.session = nil
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
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

// MARK: - Environment Support

private struct AuthManagerKey: EnvironmentKey {
    static var defaultValue: AuthManager {
        MainActor.assumeIsolated {
            AuthManager.shared
        }
    }
}

extension EnvironmentValues {
    var authManager: AuthManager {
        get { self[AuthManagerKey.self] }
        set { self[AuthManagerKey.self] = newValue }
    }
}
