import Foundation

/// `/users/{ownerUid}/friends/{friendUid}` document, per docs/GAME_SPEC.md §L.
public struct Friend: Codable, Equatable, Sendable {
    public var uid: String
    public var displayName: String
    public var avatarId: Int
    public var since: Date?

    public init(uid: String, displayName: String, avatarId: Int, since: Date? = nil) {
        self.uid = uid
        self.displayName = displayName
        self.avatarId = avatarId
        self.since = since
    }
}

/// Status of a `/friendRequests/{id}` document, per docs/GAME_SPEC.md §L.
public enum FriendRequestStatus: String, Codable, Sendable {
    case pending
    case accepted
    case declined
}

/// `/friendRequests/{id}` document, per docs/GAME_SPEC.md §L.
///
/// `id` is the Firestore document ID — never stored as a field in the document itself,
/// populated by `FriendsService` from `DocumentSnapshot.documentID` after decoding.
public struct FriendRequest: Codable, Equatable, Sendable {
    public var id: String?
    public var fromUid: String
    public var fromName: String
    public var fromAvatarId: Int
    public var toUid: String
    public var status: FriendRequestStatus
    public var createdAt: Date?

    public init(
        id: String? = nil,
        fromUid: String,
        fromName: String,
        fromAvatarId: Int,
        toUid: String,
        status: FriendRequestStatus,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.fromUid = fromUid
        self.fromName = fromName
        self.fromAvatarId = fromAvatarId
        self.toUid = toUid
        self.status = status
        self.createdAt = createdAt
    }
}

/// `/blocks/{ownerUid}/blocked/{targetUid}` document, per docs/GAME_SPEC.md §L.
public struct BlockedUser: Codable, Equatable, Sendable {
    public var uid: String
    public var blockedAt: Date?

    public init(uid: String, blockedAt: Date? = nil) {
        self.uid = uid
        self.blockedAt = blockedAt
    }
}
