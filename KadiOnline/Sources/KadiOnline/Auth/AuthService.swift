import Foundation
#if canImport(UIKit)
import UIKit
#endif

public enum AuthServiceError: Error, Equatable {
    case notSignedIn
}

/// Email/Password + Google Sign-In, per docs/GAME_SPEC.md §L.
///
/// Email/Password registration requires verification before the account can join
/// `/rooms` (enforced by Phase 4 UI via `AuthUser.isEmailVerified`); Google accounts are
/// pre-verified.
public protocol AuthService: Sendable {
    /// The currently signed-in user, if any. Updated synchronously after `signIn`,
    /// `register`, `signOut`, and `reload`.
    var currentUser: AuthUser? { get }

    /// Yields the current user immediately, then again whenever Firebase's auth state
    /// changes (sign-in, sign-out, token refresh).
    func authStateChanges() -> AsyncStream<AuthUser?>

    /// Creates an account with `email`/`password`, sets `displayName`, and sends a
    /// verification email. The returned user's `isEmailVerified` is `false`.
    @discardableResult
    func register(email: String, password: String, displayName: String) async throws -> AuthUser

    /// Signs in an existing Email/Password account.
    @discardableResult
    func signIn(email: String, password: String) async throws -> AuthUser

    /// Re-sends the verification email to the current user.
    func sendEmailVerification() async throws

    /// Refreshes the current user's data (e.g. to pick up `isEmailVerified` after the
    /// user clicks the link in their verification email) and returns the updated user.
    @discardableResult
    func reload() async throws -> AuthUser?

    func signOut() throws

    #if canImport(UIKit)
    /// Signs in with Google via the pinned web client ID (docs/GAME_SPEC.md §L). Google
    /// accounts are pre-verified.
    @discardableResult
    func signInWithGoogle(presenting viewController: UIViewController) async throws -> AuthUser
    #endif
}
