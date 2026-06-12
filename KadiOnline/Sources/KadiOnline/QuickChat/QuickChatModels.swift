import Foundation

/// `/quickChat/{roomId}/{uid}` document, per docs/GAME_SPEC.md §L.
///
/// `uid` is the Realtime Database child key — never stored as a field in the node
/// itself, populated by `QuickChatService` after decoding. `timestamp` is RTDB's
/// `ServerValue.timestamp()`, which the server resolves to epoch milliseconds.
public struct QuickChatMessage: Codable, Equatable, Sendable {
    public var uid: String?
    public var message: String
    public var timestamp: Double?

    public init(
        uid: String? = nil,
        message: String,
        timestamp: Double? = nil
    ) {
        self.uid = uid
        self.message = message
        self.timestamp = timestamp
    }
}
