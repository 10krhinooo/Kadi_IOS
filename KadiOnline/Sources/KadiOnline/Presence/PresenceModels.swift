import Foundation

/// Presence status for `/presence/{uid}`, per docs/GAME_SPEC.md §L.
public enum PresenceStatus: String, Codable, Equatable, Sendable {
    case online
    case offline
    case busy
}

/// `/presence/{uid}` document, per docs/GAME_SPEC.md §L.
///
/// `uid` is the Realtime Database path key — never stored as a field in the node
/// itself, populated by `PresenceService` after decoding. `lastSeen` is RTDB's
/// `ServerValue.timestamp()`, which the server resolves to epoch milliseconds.
public struct Presence: Codable, Equatable, Sendable {
    public var uid: String?
    public var status: PresenceStatus
    public var customStatus: String?
    public var inGame: Bool
    public var roomId: String?
    public var lastSeen: Double?

    public init(
        uid: String? = nil,
        status: PresenceStatus = .offline,
        customStatus: String? = nil,
        inGame: Bool = false,
        roomId: String? = nil,
        lastSeen: Double? = nil
    ) {
        self.uid = uid
        self.status = status
        self.customStatus = customStatus
        self.inGame = inGame
        self.roomId = roomId
        self.lastSeen = lastSeen
    }
}
