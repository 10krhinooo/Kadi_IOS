@preconcurrency import FirebaseAuth
import Foundation
#if canImport(UIKit)
import UIKit
import GoogleSignIn
#endif

/// `AuthService` backed by `FirebaseAuth` (+ `GoogleSignIn` on iOS), per
/// docs/GAME_SPEC.md §L.
public final class FirebaseAuthService: AuthService, @unchecked Sendable {
    private let auth: Auth

    public init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    public var currentUser: AuthUser? {
        mapUser(auth.currentUser)
    }

    public func authStateChanges() -> AsyncStream<AuthUser?> {
        AsyncStream { continuation in
            continuation.yield(self.mapUser(self.auth.currentUser))
            let handle = auth.addStateDidChangeListener { [weak self] _, user in
                continuation.yield(self?.mapUser(user))
            }
            continuation.onTermination = { [auth] _ in
                auth.removeStateDidChangeListener(handle)
            }
        }
    }

    @discardableResult
    public func register(email: String, password: String, displayName: String) async throws -> AuthUser {
        let result = try await auth.createUser(withEmail: email, password: password)

        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()

        try await result.user.sendEmailVerification()
        try await result.user.reload()

        guard let user = mapUser(auth.currentUser) else {
            throw AuthServiceError.notSignedIn
        }
        return user
    }

    @discardableResult
    public func signIn(email: String, password: String) async throws -> AuthUser {
        let result = try await auth.signIn(withEmail: email, password: password)
        guard let user = mapUser(result.user) else {
            throw AuthServiceError.notSignedIn
        }
        return user
    }

    public func sendEmailVerification() async throws {
        guard let user = auth.currentUser else {
            throw AuthServiceError.notSignedIn
        }
        try await user.sendEmailVerification()
    }

    @discardableResult
    public func reload() async throws -> AuthUser? {
        guard let user = auth.currentUser else { return nil }
        try await user.reload()
        return mapUser(auth.currentUser)
    }

    public func signOut() throws {
        try auth.signOut()
    }

    #if canImport(UIKit)
    @discardableResult
    public func signInWithGoogle(presenting viewController: UIViewController) async throws -> AuthUser {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthServiceError.notSignedIn
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await auth.signIn(with: credential)
        guard let user = mapUser(authResult.user) else {
            throw AuthServiceError.notSignedIn
        }
        return user
    }
    #endif

    private func mapUser(_ user: User?) -> AuthUser? {
        guard let user else { return nil }
        let providerId = user.providerData.first?.providerID ?? user.providerID
        return AuthUser(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            isEmailVerified: user.isEmailVerified,
            photoURL: user.photoURL,
            providerId: providerId
        )
    }
}
