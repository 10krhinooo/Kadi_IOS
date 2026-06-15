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
    public var fcmTokens: [String]

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
        createdAt: Date? = nil,
        fcmTokens: [String] = []
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
        self.fcmTokens = fcmTokens
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(String.self, forKey: .uid)
        displayName = try container.decode(String.self, forKey: .displayName)
        displayNameLower = try container.decode(String.self, forKey: .displayNameLower)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        avatarId = try container.decode(Int.self, forKey: .avatarId)
        points = try container.decode(Int.self, forKey: .points)
        wins = try container.decode(Int.self, forKey: .wins)
        losses = try container.decode(Int.self, forKey: .losses)
        gamesPlayed = try container.decode(Int.self, forKey: .gamesPlayed)
        quits = try container.decode(Int.self, forKey: .quits)
        lastSeen = try container.decodeIfPresent(Date.self, forKey: .lastSeen)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        fcmTokens = try container.decodeIfPresent([String].self, forKey: .fcmTokens) ?? []
    }
}
