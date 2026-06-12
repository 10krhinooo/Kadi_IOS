import Foundation

/// `/users/{uid}` document, per docs/GAME_SPEC.md §L.
///
/// Stat fields (`points`/`wins`/`losses`/`gamesPlayed`/`quits`) are only initialized by
/// `ProfileService.ensureProfile` on first creation and are never overwritten by later
/// profile-refresh writes (see `ProfileService`).
public struct UserProfile: Codable, Equatable, Sendable {
    public var uid: String
    public var displayName: String
    public var displayNameLower: String
    public var email: String?
    public var avatarId: Int
    public var points: Int
    public var wins: Int
    public var losses: Int
    public var gamesPlayed: Int
    public var quits: Int
    public var lastSeen: Date?
    public var createdAt: Date?

    public init(
        uid: String,
        displayName: String,
        displayNameLower: String,
        email: String? = nil,
        avatarId: Int,
        points: Int = 0,
        wins: Int = 0,
        losses: Int = 0,
        gamesPlayed: Int = 0,
        quits: Int = 0,
        lastSeen: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.uid = uid
        self.displayName = displayName
        self.displayNameLower = displayNameLower
        self.email = email
        self.avatarId = avatarId
        self.points = points
        self.wins = wins
        self.losses = losses
        self.gamesPlayed = gamesPlayed
        self.quits = quits
        self.lastSeen = lastSeen
        self.createdAt = createdAt
    }
}
