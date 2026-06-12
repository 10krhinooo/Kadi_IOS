import Foundation
import KadiEngine

/// Status of a `/rooms/{roomId}` document, per docs/GAME_SPEC.md §L.
public enum RoomStatus: String, Codable, Sendable {
    case waiting
    case playing
    case finished
}

/// A seat in a room's roster, per docs/GAME_SPEC.md §L `players` field.
public struct RoomPlayer: Codable, Equatable, Sendable {
    public var uid: String
    public var name: String
    public var playerIndex: Int
    public var isConnected: Bool

    public init(uid: String, name: String, playerIndex: Int, isConnected: Bool) {
        self.uid = uid
        self.name = name
        self.playerIndex = playerIndex
        self.isConnected = isConnected
    }
}

/// `/rooms/{roomId}` document, per docs/GAME_SPEC.md §L.
public struct Room: Codable, Equatable, Sendable {
    public var roomId: String
    public var hostUid: String
    public var hostName: String
    public var players: [RoomPlayer]
    public var playerUids: [String]
    public var status: RoomStatus
    public var rules: RuleSet
    public var gameState: GameState?
    public var quitPenaltyEnabled: Bool
    public var eventSeq: Int
    public var createdAt: Date?
    public var startedAt: Date?

    public init(
        roomId: String,
        hostUid: String,
        hostName: String,
        players: [RoomPlayer],
        playerUids: [String],
        status: RoomStatus,
        rules: RuleSet,
        gameState: GameState? = nil,
        quitPenaltyEnabled: Bool = false,
        eventSeq: Int = 0,
        createdAt: Date? = nil,
        startedAt: Date? = nil
    ) {
        self.roomId = roomId
        self.hostUid = hostUid
        self.hostName = hostName
        self.players = players
        self.playerUids = playerUids
        self.status = status
        self.rules = rules
        self.gameState = gameState
        self.quitPenaltyEnabled = quitPenaltyEnabled
        self.eventSeq = eventSeq
        self.createdAt = createdAt
        self.startedAt = startedAt
    }
}

/// `/rooms/{roomId}/actions/{id}` document, per docs/GAME_SPEC.md §L.
///
/// Guests create these (with `timestamp` set via server timestamp); the host reads them
/// ordered by `timestamp`, applies them via `GameEngine`, and deletes them.
public struct RoomAction: Codable, Equatable, Sendable {
    public var playerUid: String
    public var action: GameAction
    public var timestamp: Date?

    public init(playerUid: String, action: GameAction, timestamp: Date? = nil) {
        self.playerUid = playerUid
        self.action = action
        self.timestamp = timestamp
    }
}

/// `/rooms/{roomId}/events/{id}` document, per docs/GAME_SPEC.md §L.
///
/// The host writes these (with a monotonically increasing `seq`, tracked via the room
/// document's `eventSeq` field) for the client-visible game log. `kind`/`detail` describe
/// the event in a UI-agnostic way; Phase 4 decides how to render them.
public struct RoomEvent: Codable, Equatable, Sendable {
    public var seq: Int
    public var kind: String
    public var detail: String?
    public var playerUid: String?
    public var timestamp: Date?

    public init(seq: Int, kind: String, detail: String? = nil, playerUid: String? = nil, timestamp: Date? = nil) {
        self.seq = seq
        self.kind = kind
        self.detail = detail
        self.playerUid = playerUid
        self.timestamp = timestamp
    }
}

/// `/rooms/{roomId}/messages/{id}` document, per docs/GAME_SPEC.md §L — room chat.
public struct RoomMessage: Codable, Equatable, Sendable {
    public var senderUid: String
    public var senderName: String
    public var text: String
    public var timestamp: Date?

    public init(senderUid: String, senderName: String, text: String, timestamp: Date? = nil) {
        self.senderUid = senderUid
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
    }
}
