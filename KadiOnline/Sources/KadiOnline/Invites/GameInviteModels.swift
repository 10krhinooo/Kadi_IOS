import Foundation

/// `/gameInvites/{id}` document, per docs/GAME_SPEC.md §L.
///
/// `id` is the Firestore document ID — never stored as a field in the document itself,
/// populated by `GameInviteService` from `DocumentSnapshot.documentID` after decoding.
public struct GameInvite: Codable, Equatable, Sendable {
    public var id: String?
    public var fromUid: String
    public var fromName: String
    public var toUid: String
    public var roomId: String
    public var createdAt: Date?
    public var expiresAt: Date?

    public init(
        id: String? = nil,
        fromUid: String,
        fromName: String,
        toUid: String,
        roomId: String,
        createdAt: Date? = nil,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.fromUid = fromUid
        self.fromName = fromName
        self.toUid = toUid
        self.roomId = roomId
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}
