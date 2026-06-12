import Foundation

/// A signed-in Firebase user, per docs/GAME_SPEC.md §L Auth.
public struct AuthUser: Equatable, Sendable {
    public let uid: String
    public let email: String?
    public let displayName: String?
    public let isEmailVerified: Bool
    public let photoURL: URL?
    public let providerId: String

    public init(uid: String, email: String?, displayName: String?, isEmailVerified: Bool, photoURL: URL?, providerId: String) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.isEmailVerified = isEmailVerified
        self.photoURL = photoURL
        self.providerId = providerId
    }
}
