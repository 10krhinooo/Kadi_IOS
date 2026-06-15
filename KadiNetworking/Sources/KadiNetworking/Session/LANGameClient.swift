import Foundation
import Network
import KadiEngine

/// Errors thrown by `LANGameClient`.
public enum LANClientError: Error, Sendable, Equatable {
    /// `promoteToHost` was called before any `GameState` had been received.
    case gameNotStarted
}

/// Client side of a LAN game session: connects to a `LANGameHost`, performs the
/// join/joinAck/gameStart handshake, replies to heartbeat `ping`s with `pong`, and exposes
/// `GameState`/roster/chat updates plus a `hostLost` signal for host-migration handling, per
/// docs/GAME_SPEC.md §J.
public actor LANGameClient {
    public let name: String
    public let uid: String
    public let avatarIndex: Int

    private var connection: any MessageConnection
    private var receiveTask: Task<Void, Never>?
    private var pingWatchdogTask: Task<Void, Never>?
    private var lastPingReceived = Date()

    private var assignedPlayerIndex: Int?
    private var roster: [Player] = []
    private var disconnectedPlayerIndices: Set<Int> = []
    private var gameState: GameState?

    private var connectionLost = false

    private var stateContinuations: [AsyncStream<GameState>.Continuation] = []
    private var rosterContinuations: [AsyncStream<[Player]>.Continuation] = []
    private var chatContinuations: [AsyncStream<ChatPayload>.Continuation] = []
    private var hostLostContinuations: [AsyncStream<Void>.Continuation] = []
    private var connectionEventContinuations: [AsyncStream<LANConnectionEvent>.Continuation] = []

    /// Heartbeat timeout: client disconnects itself after 3 missed 2s pings (6s), per §J.
    public static let pingTimeout: TimeInterval = 6

    public init<C: MessageConnection>(connection: C, name: String, uid: String, avatarIndex: Int) {
        self.connection = connection
        self.name = name
        self.uid = uid
        self.avatarIndex = avatarIndex
    }

    /// Connect to `endpoint` and perform the join handshake.
    public static func connect(to endpoint: NWEndpoint, name: String, uid: String, avatarIndex: Int) async throws -> LANGameClient {
        let connection = try await NWMessageConnection.connect(to: endpoint)
        let client = LANGameClient(connection: connection, name: name, uid: uid, avatarIndex: avatarIndex)
        try await client.start()
        return client
    }

    /// Send `joinRequest` and start the receive loop / heartbeat watchdog.
    public func start() async throws {
        try await connection.send(.joinRequest(JoinRequestPayload(name: name, uid: uid, avatarIndex: avatarIndex)))
        lastPingReceived = Date()
        beginReceiveLoop()
        startPingWatchdog()
    }

    /// Stop the client and close its connection.
    public func stop() async {
        receiveTask?.cancel()
        pingWatchdogTask?.cancel()
        await connection.close()
    }

    // MARK: - Sending

    /// Submit a `GameAction` for this client's player. The host validates it; if invalid it
    /// is silently dropped (no `stateDelta`), per §J.
    public func sendAction(_ action: GameAction) async throws {
        try await connection.send(.playerAction(action))
    }

    /// Send a chat message.
    public func sendChat(_ text: String) async throws {
        try await connection.send(.chat(ChatPayload(text: text, sender: name)))
    }

    // MARK: - Receiving

    private func beginReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task {
            while true {
                let message: NetworkMessage?
                do {
                    message = try await connection.receive()
                } catch {
                    message = nil
                }
                guard let message else {
                    await self.handleConnectionLost()
                    return
                }
                await self.handle(message)
            }
        }
    }

    private func handle(_ message: NetworkMessage) async {
        switch message {
        case .joinAck(let payload):
            assignedPlayerIndex = payload.playerIndex
            roster = payload.players
            publishRoster()
        case .gameStart(let state), .gameStateFull(let state), .stateDelta(let state):
            gameState = state
            roster = state.players
            lastPingReceived = Date()
            publishState()
            publishRoster()
        case .ping:
            lastPingReceived = Date()
            try? await connection.send(.pong)
        case .pong:
            break
        case .playerJoined(let payload):
            let wasDisconnected = disconnectedPlayerIndices.remove(payload.playerIndex) != nil
            if payload.playerIndex < roster.count {
                roster[payload.playerIndex] = payload.player
            } else {
                roster.append(payload.player)
            }
            publishRoster()
            if wasDisconnected {
                publishConnectionEvent(.playerReconnected(playerIndex: payload.playerIndex))
            }
        case .playerDisconnected(let payload):
            disconnectedPlayerIndices.insert(payload.playerIndex)
            publishRoster()
            publishConnectionEvent(.playerDisconnected(playerIndex: payload.playerIndex))
        case .hostTransfer:
            // Informational only; the actual reconnect is driven by `hostLost` +
            // `reconnect(to:)` / `promoteToHost(gameName:rules:)`.
            break
        case .chat(let payload):
            for continuation in chatContinuations {
                continuation.yield(payload)
            }
        case .joinRequest, .playerAction:
            break // not expected client-side
        }
    }

    private func startPingWatchdog() {
        pingWatchdogTask?.cancel()
        pingWatchdogTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if Date().timeIntervalSince(self.lastPingReceived) > Self.pingTimeout {
                    await self.handleConnectionLost()
                    return
                }
            }
        }
    }

    private func handleConnectionLost() async {
        guard !connectionLost else { return }
        connectionLost = true
        pingWatchdogTask?.cancel()
        await connection.close()
        for continuation in hostLostContinuations {
            continuation.yield(())
        }
    }

    // MARK: - Host migration

    /// `true` if this client's player index is the lowest among players not known to be
    /// disconnected (excluding seat 0, the original host) — i.e. it should promote itself
    /// to host after `hostLost` fires.
    public func isLowestSurvivingPlayerIndex() -> Bool {
        guard let myIndex = assignedPlayerIndex, myIndex != 0 else { return false }
        let survivors = (1..<roster.count).filter { !disconnectedPlayerIndices.contains($0) }
        guard let lowest = survivors.min() else { return false }
        return myIndex == lowest
    }

    /// Become the new host, seeded with the last-known `GameState` and roster (every other
    /// seat starts CPU-controlled until its player reconnects). This client transparently
    /// re-attaches to the new host over an in-memory connection so its existing
    /// `gameStateUpdates`/`rosterUpdates` streams keep working.
    public func promoteToHost(gameName: String, rules: RuleSet) async throws -> LANGameHost {
        guard let state = gameState else { throw LANClientError.gameNotStarted }
        let snapshotRoster = roster.enumerated().map {
            (playerIndex: $0.offset, uid: $0.element.id, name: $0.element.name, avatarIndex: $0.element.avatarIndex)
        }
        let newHost = LANGameHost(resumingState: state, roster: snapshotRoster, hostUid: uid, rules: rules)
        _ = try await newHost.start(gameName: gameName)

        let (clientSide, hostSide) = InMemoryMessageConnection.pair()
        try await clientSide.send(.joinRequest(JoinRequestPayload(name: name, uid: uid, avatarIndex: avatarIndex)))
        Task { await newHost.acceptConnection(hostSide) }
        await attach(clientSide)
        return newHost
    }

    /// Reconnect to a newly-promoted host at `endpoint` (discovered via `LANBrowser`),
    /// resuming this client's seat by `uid`.
    public func reconnect(to endpoint: NWEndpoint) async throws {
        let newConnection = try await NWMessageConnection.connect(to: endpoint)
        try await newConnection.send(.joinRequest(JoinRequestPayload(name: name, uid: uid, avatarIndex: avatarIndex)))
        await attach(newConnection)
    }

    private func attach<C: MessageConnection>(_ newConnection: C) async {
        await connection.close()
        receiveTask?.cancel()
        pingWatchdogTask?.cancel()
        connection = newConnection
        lastPingReceived = Date()
        connectionLost = false
        beginReceiveLoop()
        startPingWatchdog()
    }

    // MARK: - Observation

    public func gameStateUpdates() -> AsyncStream<GameState> {
        AsyncStream { continuation in
            if let state = gameState {
                continuation.yield(state)
            }
            stateContinuations.append(continuation)
        }
    }

    public func rosterUpdates() -> AsyncStream<[Player]> {
        AsyncStream { continuation in
            continuation.yield(roster)
            rosterContinuations.append(continuation)
        }
    }

    public func chatUpdates() -> AsyncStream<ChatPayload> {
        AsyncStream { continuation in
            chatContinuations.append(continuation)
        }
    }

    /// Fires once when the host connection is considered lost (EOF or 6s ping timeout).
    public func hostLostUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            hostLostContinuations.append(continuation)
        }
    }

    /// Stream of CPU-takeover/reconnect events for other players, relayed by the host.
    public func connectionEvents() -> AsyncStream<LANConnectionEvent> {
        AsyncStream { continuation in
            connectionEventContinuations.append(continuation)
        }
    }

    private func publishConnectionEvent(_ event: LANConnectionEvent) {
        for continuation in connectionEventContinuations {
            continuation.yield(event)
        }
    }

    private func publishState() {
        guard let state = gameState else { return }
        for continuation in stateContinuations {
            continuation.yield(state)
        }
    }

    private func publishRoster() {
        for continuation in rosterContinuations {
            continuation.yield(roster)
        }
    }

    public var currentGameState: GameState? { gameState }
    public var currentPlayerIndex: Int? { assignedPlayerIndex }
}
