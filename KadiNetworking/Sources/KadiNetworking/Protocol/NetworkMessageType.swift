import Foundation

/// The `"type"` discriminator for `NetworkMessage`, matching the `.name` values from
/// docs/GAME_SPEC.md §J exactly.
public enum NetworkMessageType: String, Codable, Sendable {
    case gameStateFull
    case playerAction
    case stateDelta
    case playerJoined
    case playerDisconnected
    case hostTransfer
    case ping
    case pong
    case joinRequest
    case joinAck
    case gameStart
    case chat
}
