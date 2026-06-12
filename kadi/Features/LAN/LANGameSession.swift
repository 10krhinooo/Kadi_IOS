//
//  LANGameSession.swift
//  kadi
//

import KadiEngine
import KadiNetworking

/// Unifies `LANGameHost` and `LANGameClient` behind a common surface so
/// `LANGameViewModel` can drive a game the same way regardless of whether this device is
/// hosting or has joined as a guest.
protocol LANGameSession: Actor {
    func submitAction(_ action: GameAction) async throws
    func gameStateUpdates() async -> AsyncStream<GameState>
    func connectionEvents() async -> AsyncStream<LANConnectionEvent>
    func stop() async
    var currentGameState: GameState? { get async }
}

extension LANGameHost: LANGameSession {
    func submitAction(_ action: GameAction) async throws {
        try await submitHostAction(action)
    }
}

extension LANGameClient: LANGameSession {
    func submitAction(_ action: GameAction) async throws {
        try await sendAction(action)
    }
}
