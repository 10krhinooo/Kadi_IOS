import Foundation
import KadiEngine

// MARK: - Payload types

/// `joinRequest` payload: client → host, first message after connect.
public struct JoinRequestPayload: Codable, Equatable, Sendable {
    public var name: String
    public var uid: String
    public var avatarIndex: Int

    public init(name: String, uid: String, avatarIndex: Int) {
        self.name = name
        self.uid = uid
        self.avatarIndex = avatarIndex
    }
}

/// `joinAck` payload: host → client, assigned player index + current roster.
public struct JoinAckPayload: Codable, Equatable, Sendable {
    public var playerIndex: Int
    public var players: [Player]

    public init(playerIndex: Int, players: [Player]) {
        self.playerIndex = playerIndex
        self.players = players
    }
}

/// `playerJoined` payload: host → clients, a new player joined the lobby/game.
public struct PlayerJoinedPayload: Codable, Equatable, Sendable {
    public var playerIndex: Int
    public var player: Player

    public init(playerIndex: Int, player: Player) {
        self.playerIndex = playerIndex
        self.player = player
    }
}

/// `playerDisconnected` payload: host → clients, a player's connection dropped.
public struct PlayerDisconnectedPayload: Codable, Equatable, Sendable {
    public var playerIndex: Int

    public init(playerIndex: Int) {
        self.playerIndex = playerIndex
    }
}

/// `hostTransfer` payload: announces a new host taking over the game.
public struct HostTransferPayload: Codable, Equatable, Sendable {
    public var newHostPlayerIndex: Int
    public var newHostUid: String

    public init(newHostPlayerIndex: Int, newHostUid: String) {
        self.newHostPlayerIndex = newHostPlayerIndex
        self.newHostUid = newHostUid
    }
}

/// `chat` payload.
public struct ChatPayload: Codable, Equatable, Sendable {
    public var text: String
    public var sender: String

    public init(text: String, sender: String) {
        self.text = text
        self.sender = sender
    }
}

/// Empty `{}` payload, used by `ping`/`pong`.
public struct EmptyPayload: Codable, Equatable, Sendable {
    public init() {}
}

// MARK: - NetworkMessage

/// A single NDJSON-framed protocol message: `{"type": "<NetworkMessageType>", "payload": {...}}`,
/// per docs/GAME_SPEC.md §J.
public enum NetworkMessage: Equatable, Sendable {
    /// Full `GameState`, sent on game start/reconnect. Host → client.
    case gameStateFull(GameState)
    /// Encoded `GameAction`. Client → host.
    case playerAction(GameAction)
    /// Full `GameState` broadcast after every applied action (not actually a diff). Host → all clients.
    case stateDelta(GameState)
    /// A player joined. Host → clients.
    case playerJoined(PlayerJoinedPayload)
    /// A player's connection dropped. Host → clients.
    case playerDisconnected(PlayerDisconnectedPayload)
    /// A new host has taken over. Old host → clients.
    case hostTransfer(HostTransferPayload)
    /// Heartbeat, host → client every 2s.
    case ping
    /// Heartbeat reply, client → host (swallowed by server).
    case pong
    /// First message after connect, client → host.
    case joinRequest(JoinRequestPayload)
    /// Join acknowledgement, host → client.
    case joinAck(JoinAckPayload)
    /// Initial `GameState` + index assignments. Host → clients.
    case gameStart(GameState)
    /// Chat message, any → all.
    case chat(ChatPayload)

    public var type: NetworkMessageType {
        switch self {
        case .gameStateFull: return .gameStateFull
        case .playerAction: return .playerAction
        case .stateDelta: return .stateDelta
        case .playerJoined: return .playerJoined
        case .playerDisconnected: return .playerDisconnected
        case .hostTransfer: return .hostTransfer
        case .ping: return .ping
        case .pong: return .pong
        case .joinRequest: return .joinRequest
        case .joinAck: return .joinAck
        case .gameStart: return .gameStart
        case .chat: return .chat
        }
    }
}

// MARK: - Codable

extension NetworkMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(NetworkMessageType.self, forKey: .type)
        switch type {
        case .gameStateFull:
            self = .gameStateFull(try container.decode(GameState.self, forKey: .payload))
        case .playerAction:
            self = .playerAction(try container.decode(GameAction.self, forKey: .payload))
        case .stateDelta:
            self = .stateDelta(try container.decode(GameState.self, forKey: .payload))
        case .playerJoined:
            self = .playerJoined(try container.decode(PlayerJoinedPayload.self, forKey: .payload))
        case .playerDisconnected:
            self = .playerDisconnected(try container.decode(PlayerDisconnectedPayload.self, forKey: .payload))
        case .hostTransfer:
            self = .hostTransfer(try container.decode(HostTransferPayload.self, forKey: .payload))
        case .ping:
            self = .ping
        case .pong:
            self = .pong
        case .joinRequest:
            self = .joinRequest(try container.decode(JoinRequestPayload.self, forKey: .payload))
        case .joinAck:
            self = .joinAck(try container.decode(JoinAckPayload.self, forKey: .payload))
        case .gameStart:
            self = .gameStart(try container.decode(GameState.self, forKey: .payload))
        case .chat:
            self = .chat(try container.decode(ChatPayload.self, forKey: .payload))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch self {
        case .gameStateFull(let state), .stateDelta(let state), .gameStart(let state):
            try container.encode(state, forKey: .payload)
        case .playerAction(let action):
            try container.encode(action, forKey: .payload)
        case .playerJoined(let payload):
            try container.encode(payload, forKey: .payload)
        case .playerDisconnected(let payload):
            try container.encode(payload, forKey: .payload)
        case .hostTransfer(let payload):
            try container.encode(payload, forKey: .payload)
        case .ping, .pong:
            try container.encode(EmptyPayload(), forKey: .payload)
        case .joinRequest(let payload):
            try container.encode(payload, forKey: .payload)
        case .joinAck(let payload):
            try container.encode(payload, forKey: .payload)
        case .chat(let payload):
            try container.encode(payload, forKey: .payload)
        }
    }
}
