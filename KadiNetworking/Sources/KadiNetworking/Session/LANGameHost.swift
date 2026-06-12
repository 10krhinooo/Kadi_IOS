import Foundation
import Network
import KadiEngine

/// Host-authoritative LAN game session.
///
/// Owns the canonical `GameState`, accepts incoming player connections (via `LANAdvertiser`
/// or directly via `acceptConnection(_:)` for tests/migration), validates and applies
/// `playerAction`s through `GameEngine`, and broadcasts `stateDelta` to everyone after every
/// applied action, per docs/GAME_SPEC.md §J.
///
/// The host's own local player (index 0 by convention) has no `connection` — the host app
/// drives it directly via `submitHostAction(_:)`.
public actor LANGameHost {
    public let hostUid: String
    public let maxPlayers: Int

    private var rules: RuleSet
    private var players: [ConnectedPlayer]
    private var gameState: GameState?
    private var advertiser: LANAdvertiser?
    private var pingTask: Task<Void, Never>?
    private var receiveTasks: [String: Task<Void, Never>] = [:]
    private var stateContinuations: [AsyncStream<GameState>.Continuation] = []
    private var lobbyContinuations: [AsyncStream<[Player]>.Continuation] = []
    private var connectionEventContinuations: [AsyncStream<LANConnectionEvent>.Continuation] = []
    private let cpuAgentFactory: @Sendable () -> CpuAgent

    /// The `playerIndex` of this host's own local player (0 for a fresh lobby; the seat
    /// matching `hostUid` in the roster when resuming after host migration).
    private let hostPlayerIndex: Int

    /// The TCP port bound by `start(gameName:)`, once started.
    public private(set) var port: UInt16?

    /// Create a fresh lobby with the host as player 0.
    public init(
        hostName: String,
        hostUid: String,
        hostAvatarIndex: Int = 0,
        rules: RuleSet = RuleSet(),
        maxPlayers: Int = 4,
        cpuAgentFactory: @escaping @Sendable () -> CpuAgent = { MediumCpu() }
    ) {
        self.hostUid = hostUid
        self.maxPlayers = maxPlayers
        self.rules = rules
        self.players = [ConnectedPlayer(playerIndex: 0, uid: hostUid, name: hostName, avatarIndex: hostAvatarIndex)]
        self.cpuAgentFactory = cpuAgentFactory
        self.hostPlayerIndex = 0
    }

    /// Re-create a host from a previously-received `GameState` and roster, for host
    /// migration: every seat other than `hostUid` starts CPU-controlled until its player
    /// reconnects.
    public init(
        resumingState state: GameState,
        roster: [(playerIndex: Int, uid: String, name: String, avatarIndex: Int)],
        hostUid: String,
        rules: RuleSet,
        maxPlayers: Int = 4,
        cpuAgentFactory: @escaping @Sendable () -> CpuAgent = { MediumCpu() }
    ) {
        self.hostUid = hostUid
        self.maxPlayers = maxPlayers
        self.rules = rules
        self.gameState = state
        self.cpuAgentFactory = cpuAgentFactory
        self.players = roster.map { seat in
            let isHost = seat.uid == hostUid
            return ConnectedPlayer(
                playerIndex: seat.playerIndex,
                uid: seat.uid,
                name: seat.name,
                avatarIndex: seat.avatarIndex,
                connection: nil,
                isCPUControlled: !isHost,
                cpuAgent: isHost ? nil : cpuAgentFactory()
            )
        }
        self.hostPlayerIndex = roster.first(where: { $0.uid == hostUid })?.playerIndex ?? 0
    }

    // MARK: - Lifecycle

    /// Start advertising via Bonjour/UDP beacon and accept incoming connections. Returns the
    /// bound TCP port.
    @discardableResult
    public func start(gameName: String) async throws -> UInt16 {
        let advertiser = LANAdvertiser(gameName: gameName) { [weak self] connection in
            Task { await self?.acceptRawConnection(connection) }
        }
        self.advertiser = advertiser
        let port = try await advertiser.start()
        self.port = port
        if gameState != nil {
            startHeartbeat()
            await runCPUTurnsIfNeeded()
        }
        return port
    }

    /// Stop advertising and the heartbeat loop, and close all connections.
    public func stop() async {
        await advertiser?.stop()
        advertiser = nil
        pingTask?.cancel()
        pingTask = nil
        for task in receiveTasks.values { task.cancel() }
        receiveTasks.removeAll()
        for player in players {
            await player.connection?.close()
        }
    }

    private func acceptRawConnection(_ raw: NWConnection) async {
        guard let connection = try? await NWMessageConnection.accepted(raw) else { return }
        await acceptConnection(connection)
    }

    /// Accept an already-established `MessageConnection` (used by `start()` for real TCP
    /// connections, and directly by tests / in-process host migration for in-memory pairs).
    public func acceptConnection<C: MessageConnection>(_ connection: C) async {
        guard let first = try? await connection.receive(), case let .joinRequest(payload) = first else {
            await connection.close()
            return
        }
        await processJoin(payload: payload, connection: connection)
    }

    // MARK: - Join / reconnect

    private func processJoin<C: MessageConnection>(payload: JoinRequestPayload, connection: C) async {
        if let index = players.firstIndex(where: { $0.uid == payload.uid }) {
            // Reconnect: reattach connection, clear CPU takeover, resync full state.
            let wasCPUControlled = players[index].isCPUControlled
            players[index].connection = connection
            players[index].isCPUControlled = false
            players[index].cpuAgent = nil
            players[index].name = payload.name
            players[index].avatarIndex = payload.avatarIndex

            try? await connection.send(.joinAck(JoinAckPayload(playerIndex: index, players: rosterPlayers())))
            if let state = gameState {
                try? await connection.send(.gameStateFull(state))
            }
            await broadcast(.playerJoined(PlayerJoinedPayload(playerIndex: index, player: rosterPlayers()[index])), excludingUid: payload.uid)
            startReceiveLoop(for: payload.uid, connection: connection)
            publishLobby()
            if wasCPUControlled {
                publishConnectionEvent(.playerReconnected(playerIndex: index))
            }
            return
        }

        guard gameState == nil, players.count < maxPlayers else {
            await connection.close()
            return
        }

        let index = players.count
        players.append(ConnectedPlayer(playerIndex: index, uid: payload.uid, name: payload.name, avatarIndex: payload.avatarIndex, connection: connection))

        try? await connection.send(.joinAck(JoinAckPayload(playerIndex: index, players: rosterPlayers())))
        await broadcast(.playerJoined(PlayerJoinedPayload(playerIndex: index, player: rosterPlayers()[index])), excludingUid: payload.uid)
        startReceiveLoop(for: payload.uid, connection: connection)
        publishLobby()
    }

    private func startReceiveLoop<C: MessageConnection>(for uid: String, connection: C) {
        receiveTasks[uid]?.cancel()
        receiveTasks[uid] = Task {
            while true {
                let message: NetworkMessage?
                do {
                    message = try await connection.receive()
                } catch {
                    message = nil
                }
                guard let message else {
                    await self.handleDisconnect(uid: uid)
                    return
                }
                await self.handle(message: message, fromUid: uid)
            }
        }
    }

    // MARK: - Game start

    /// Start the game with the currently-joined players. No-op if already started.
    public func startGame() async throws {
        guard gameState == nil else { return }
        let enginePlayers = players.map { Player(id: $0.uid, name: $0.name, hand: [], isHuman: true, avatarIndex: $0.avatarIndex) }
        let state = try GameEngine.createGame(players: enginePlayers, rules: rules)
        gameState = state
        await broadcast(.gameStart(state))
        publishState()
        publishLobby()
        startHeartbeat()
        await runCPUTurnsIfNeeded()
    }

    private func startHeartbeat() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: LANAdvertiser.beaconInterval)
                guard let self else { return }
                await self.broadcast(.ping)
            }
        }
    }

    // MARK: - Message handling

    private func handle(message: NetworkMessage, fromUid uid: String) async {
        switch message {
        case .playerAction(let action):
            await applyPlayerAction(action, uid: uid)
        case .pong:
            break
        case .chat(let payload):
            await broadcast(.chat(payload))
        default:
            break
        }
    }

    /// Submit an action on behalf of the host's own (local) player.
    public func submitHostAction(_ action: GameAction) async throws {
        try await applyAction(action, playerIndex: hostPlayerIndex)
    }

    private func applyAction(_ action: GameAction, playerIndex: Int) async throws {
        guard let state = gameState else {
            throw InvalidActionError("Game has not started")
        }
        guard isAuthorized(playerIndex: playerIndex, action: action, state: state) else {
            throw InvalidActionError("It is not player \(playerIndex)'s turn")
        }
        if let error = GameEngine.validateAction(state, action) {
            throw InvalidActionError(error)
        }
        gameState = try GameEngine.applyAction(state, action)
        await broadcastStateDelta()
        await runCPUTurnsIfNeeded()
    }

    private func applyPlayerAction(_ action: GameAction, uid: String) async {
        guard let index = players.firstIndex(where: { $0.uid == uid }), let state = gameState else { return }
        guard isAuthorized(playerIndex: index, action: action, state: state) else { return }
        guard GameEngine.validateAction(state, action) == nil else { return }
        guard let newState = try? GameEngine.applyAction(state, action) else { return }
        gameState = newState
        await broadcastStateDelta()
        await runCPUTurnsIfNeeded()
    }

    /// Whether `playerIndex` is the player allowed to submit `action` right now. This is a
    /// host-side authorization check on top of `GameEngine.validateAction` (which is
    /// turn-agnostic): it pins each action to `state.currentPlayerIndex` or the relevant
    /// grace-period/intercept-queue actor.
    private func isAuthorized(playerIndex: Int, action: GameAction, state: GameState) -> Bool {
        switch action {
        case .declareKadi:
            if let grace = state.kadiGracePeriodPlayerIndex { return playerIndex == grace }
            return playerIndex == state.currentPlayerIndex
        case .interceptSkip, .declineIntercept:
            if let grace = state.skipInterceptGracePeriodPlayerIndex { return playerIndex == grace }
            if state.phase == .skipIntercept { return state.skipInterceptQueue.first == playerIndex }
            return playerIndex == state.currentPlayerIndex
        default:
            return playerIndex == state.currentPlayerIndex
        }
    }

    // MARK: - CPU takeover

    /// Resolve the next CPU-controlled decision (if any): out-of-turn skip-intercept/late-Kadi
    /// grace decisions take priority over the current player's turn, mirroring
    /// `GameEngine`'s own resolution order.
    private func nextCPUAction(state: GameState) -> GameAction? {
        if let grace = state.skipInterceptGracePeriodPlayerIndex,
           let agent = cpuAgent(for: grace) {
            return agent.graceInterceptDecision(state: state, playerIndex: grace)
        }
        if state.phase == .skipIntercept, let head = state.skipInterceptQueue.first,
           let agent = cpuAgent(for: head) {
            return agent.interceptDecision(state: state, playerIndex: head)
        }
        if state.rules.lateKadiDeclaration, let grace = state.kadiGracePeriodPlayerIndex,
           let agent = cpuAgent(for: grace),
           let action = agent.lateKadiDecision(state: state, playerIndex: grace),
           GameEngine.validateAction(state, action) == nil {
            return action
        }
        guard state.phase != .finished else { return nil }
        if let agent = cpuAgent(for: state.currentPlayerIndex) {
            return CpuActionResolver.resolve(agent: agent, state: state, playerIndex: state.currentPlayerIndex)
        }
        return nil
    }

    private func cpuAgent(for playerIndex: Int) -> CpuAgent? {
        guard let player = players.first(where: { $0.playerIndex == playerIndex }), player.isCPUControlled else {
            return nil
        }
        return player.cpuAgent
    }

    private func runCPUTurnsIfNeeded() async {
        var iterations = 0
        while let state = gameState, let action = nextCPUAction(state: state) {
            guard let newState = try? GameEngine.applyAction(state, action) else { break }
            gameState = newState
            await broadcastStateDelta()
            iterations += 1
            if iterations > 1000 { break } // guard against unexpected non-terminating loops
        }
    }

    // MARK: - Disconnect / reconnect

    private func handleDisconnect(uid: String) async {
        guard let index = players.firstIndex(where: { $0.uid == uid }) else { return }
        players[index].connection = nil
        receiveTasks[uid] = nil

        guard gameState != nil, index != hostPlayerIndex else { return }
        players[index].isCPUControlled = true
        players[index].cpuAgent = players[index].cpuAgent ?? cpuAgentFactory()
        await broadcast(.playerDisconnected(PlayerDisconnectedPayload(playerIndex: index)))
        publishConnectionEvent(.playerDisconnected(playerIndex: index))
        await runCPUTurnsIfNeeded()
    }

    // MARK: - Broadcast helpers

    private func broadcastStateDelta() async {
        guard let state = gameState else { return }
        await broadcast(.stateDelta(state))
        publishState()
    }

    private func broadcast(_ message: NetworkMessage, excludingUid: String? = nil) async {
        for player in players where player.uid != excludingUid {
            guard let connection = player.connection else { continue }
            try? await connection.send(message)
        }
    }

    private func rosterPlayers() -> [Player] {
        if let state = gameState {
            return state.players
        }
        return players.map { Player(id: $0.uid, name: $0.name, hand: [], isHuman: true, avatarIndex: $0.avatarIndex) }
    }

    // MARK: - Observation / migration support

    /// Stream of `GameState` updates (current state immediately, then every change).
    public func gameStateUpdates() -> AsyncStream<GameState> {
        AsyncStream { continuation in
            if let state = gameState {
                continuation.yield(state)
            }
            stateContinuations.append(continuation)
        }
    }

    private func publishState() {
        guard let state = gameState else { return }
        for continuation in stateContinuations {
            continuation.yield(state)
        }
    }

    /// Stream of the lobby roster (current roster immediately, then on every join/reconnect
    /// and once more when `startGame()` is called).
    public func lobbyUpdates() -> AsyncStream<[Player]> {
        AsyncStream { continuation in
            continuation.yield(rosterPlayers())
            lobbyContinuations.append(continuation)
        }
    }

    private func publishLobby() {
        let roster = rosterPlayers()
        for continuation in lobbyContinuations {
            continuation.yield(roster)
        }
    }

    /// Stream of CPU-takeover/reconnect events for this host's own UI.
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

    /// Snapshot for host migration: current `GameState` (if started) and roster.
    public func migrationSnapshot() -> (state: GameState?, roster: [(playerIndex: Int, uid: String, name: String, avatarIndex: Int)]) {
        (gameState, players.map { ($0.playerIndex, $0.uid, $0.name, $0.avatarIndex) })
    }

    public var currentGameState: GameState? { gameState }
}
