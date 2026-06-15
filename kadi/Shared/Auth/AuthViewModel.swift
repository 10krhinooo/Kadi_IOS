//
//  AuthViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiOnline
#if canImport(UIKit)
import UIKit
#endif

/// Drives the email/password auth flow gating `Features/Online/` and `Features/Social/`:
/// tracks the current `AuthUser` via `AuthService.authStateChanges()` and exposes sign
/// in/up/out plus email-verification actions. Owned at app scope (`kadiApp.swift`) and
/// shared via `@EnvironmentObject` so both feature areas (and `PresenceCoordinator`)
/// observe the same session.
@MainActor
final class AuthViewModel: ObservableObject {
    enum AuthState: Equatable {
        case loading
        case signedOut
        case needsVerification(AuthUser)
        case signedIn(AuthUser)
    }

    @Published private(set) var authState: AuthState = .loading
    @Published var errorMessage: String?
    @Published var isWorking = false

    private let authService: AuthService
    private var authTask: Task<Void, Never>?

    init(authService: AuthService = FirebaseAuthService()) {
        self.authService = authService
    }

    func start() {
        guard authTask == nil else { return }
        authTask = Task { [weak self] in
            guard let self else { return }
            for await user in self.authService.authStateChanges() {
                self.authState = Self.state(for: user)
            }
        }
    }

    func stop() {
        authTask?.cancel()
        authTask = nil
    }

    func signIn(email: String, password: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let user = try await authService.signIn(email: email, password: password)
            authState = Self.state(for: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register(email: String, password: String, displayName: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let user = try await authService.register(email: email, password: password, displayName: displayName)
            authState = Self.state(for: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    #if canImport(UIKit)
    func signInWithGoogle(presenting viewController: UIViewController) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let user = try await authService.signInWithGoogle(presenting: viewController)
            authState = Self.state(for: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif

    func resendVerification() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await authService.sendEmailVerification()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reload() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let user = try await authService.reload()
            authState = Self.state(for: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try authService.signOut()
            authState = .signedOut
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func state(for user: AuthUser?) -> AuthState {
        guard let user else { return .signedOut }
        return user.isEmailVerified ? .signedIn(user) : .needsVerification(user)
    }
}
