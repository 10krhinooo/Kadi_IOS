@preconcurrency import FirebaseFirestore
import Foundation
import KadiEngine

/// Host-authoritative online game session, mirroring `LANGameHost` but backed by Firestore
/// (`/rooms/{roomId}`) instead of TCP, per docs/GAME_SPEC.md §L.
///
/// Runs on the host's device. Listens to `/rooms/{roomId}/actions` (ordered by `timestamp`),
/// validates and applies each one via `GameEngine`, then commits a `WriteBatch` that updates
/// the room's `gameState`/`eventSeq`, appends an `/events/{id}` doc, and deletes the
/// processed `/actions/{id}` doc. The host's own moves go through `submitHostAction(_:)`,
/// which skips the actions-subcollection round trip.
public actor RoomHost {
    public let roomId: String
    public let hostUid: String

    private let db: Firestore
    private var players: [RoomPlayer]
    private var rules: RuleSet
    private var gameState: GameState?
    private var eventSeq: Int

    private var actionsListener: ListenerRegistration?
    private var actionStreamTask: Task<Void, Never>?
    private var processedActionIds: Set<String> = []

    public init(
        roomId: String,
        hostUid: String,
        players: [RoomPlayer],
        rules: RuleSet,
        gameState: GameState? = nil,
        eventSeq: Int = 0,
        db: Firestore = Firestore.firestore()
    ) {
        self.roomId = roomId
        self.hostUid = hostUid
        self.players = players
        self.rules = rules
        self.gameState = gameState
        self.eventSeq = eventSeq
        self.db = db
    }

    deinit {
        actionsListener?.remove()
        actionStreamTask?.cancel()
    }

    private func roomRef() -> DocumentReference {
        db.collection("rooms").document(roomId)
    }

    private func actionsRef() -> CollectionReference {
        roomRef().collection("actions")
    }

    private func eventsRef() -> CollectionReference {
        roomRef().collection("events")
    }

    // MARK: - Lifecycle

    /// Creates the initial `GameState` (if one wasn't supplied at init) and writes it to the
    /// room doc, marking the room `playing`. No-op if the game has already started.
    public func startGame() async throws {
        guard gameState == nil else { return }
        let enginePlayers = players
            .sorted { $0.playerIndex < $1.playerIndex }
            .map { Player(id: $0.uid, name: $0.name, hand: [], isHuman: true) }
        let state = try GameEngine.createGame(players: enginePlayers, rules: rules)
        gameState = state
        try await commitStateUpdate(
            state,
            eventKind: "gameStart",
            playerUid: nil,
            deleteActionRef: nil,
            extraFields: [
                "status": RoomStatus.playing.rawValue,
                "startedAt": FieldValue.serverTimestamp(),
            ]
        )
    }

    /// Begins listening to `/rooms/{roomId}/actions`, processing new documents in
    /// `timestamp` order as they're committed. Idempotent.
    public func startProcessingActions() {
        guard actionsListener == nil else { return }

        let (stream, continuation) = AsyncStream<[QueryDocumentSnapshot]>.makeStream()
        actionsListener = actionsRef()
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, _ in
                guard let snapshot else { return }
                continuation.yield(snapshot.documents)
            }

        actionStreamTask = Task { [weak self] in
            for await docs in stream {
                guard let self else { return }
                await self.processDocs(docs)
            }
        }
    }

    /// Stops listening for new actions.
    public func stop() {
        actionsListener?.remove()
        actionsListener = nil
        actionStreamTask?.cancel()
        actionStreamTask = nil
    }

    // MARK: - Action processing

    private func processDocs(_ docs: [QueryDocumentSnapshot]) async {
        for doc in docs {
            guard !processedActionIds.contains(doc.documentID) else { continue }
            processedActionIds.insert(doc.documentID)

            guard let roomAction = try? doc.data(as: RoomAction.self) else {
                try? await doc.reference.delete()
                continue
            }
            await processAction(roomAction, ref: doc.reference)
        }
    }

    private func processAction(_ roomAction: RoomAction, ref: DocumentReference) async {
        guard
            let state = gameState,
            let playerIndex = players.first(where: { $0.uid == roomAction.playerUid })?.playerIndex,
            isAuthorized(playerIndex: playerIndex, action: roomAction.action, state: state),
            GameEngine.validateAction(state, roomAction.action) == nil,
            let newState = try? GameEngine.applyAction(state, roomAction.action)
        else {
            try? await ref.delete()
            return
        }

        gameState = newState
        try? await commitStateUpdate(
            newState,
            eventKind: eventKind(for: roomAction.action),
            playerUid: roomAction.playerUid,
            deleteActionRef: ref
        )
    }

    /// Applies an action on behalf of the host's own seated player, bypassing
    /// `/rooms/{roomId}/actions`.
    public func submitHostAction(_ action: GameAction) async throws {
        guard let state = gameState else {
            throw InvalidActionError("Game has not started")
        }
        guard let hostIndex = players.first(where: { $0.uid == hostUid })?.playerIndex else {
            throw InvalidActionError("Host is not seated in this room")
        }
        guard isAuthorized(playerIndex: hostIndex, action: action, state: state) else {
            throw InvalidActionError("It is not the host's turn")
        }

        let newState = try GameEngine.applyAction(state, action)
        gameState = newState
        try await commitStateUpdate(
            newState,
            eventKind: eventKind(for: action),
            playerUid: hostUid,
            deleteActionRef: nil
        )
    }

    // MARK: - Commit

    private func commitStateUpdate(
        _ state: GameState,
        eventKind: String,
        playerUid: String?,
        deleteActionRef: DocumentReference?,
        extraFields: [String: Any] = [:]
    ) async throws {
        let batch = db.batch()
        let newSeq = eventSeq + 1

        var roomUpdate: [String: Any] = [
            "gameState": try Firestore.Encoder().encode(state),
            "eventSeq": newSeq,
        ]
        for (key, value) in extraFields {
            roomUpdate[key] = value
        }
        batch.updateData(roomUpdate, forDocument: roomRef())

        var eventData: [String: Any] = [
            "seq": newSeq,
            "kind": eventKind,
            "timestamp": FieldValue.serverTimestamp(),
        ]
        if let playerUid {
            eventData["playerUid"] = playerUid
        }
        batch.setData(eventData, forDocument: eventsRef().document())

        if let deleteActionRef {
            batch.deleteDocument(deleteActionRef)
        }

        try await batch.commit()
        eventSeq = newSeq
    }

    private func eventKind(for action: GameAction) -> String {
        switch action {
        case .playCards: return "playCards"
        case .pass: return "pass"
        case .drawStack: return "drawStack"
        case .declareKadi: return "declareKadi"
        case .chooseSuit: return "chooseSuit"
        case .makeDemand: return "makeDemand"
        case .respondToDemand: return "respondToDemand"
        case .refuseDraw: return "refuseDraw"
        case .refuseSkip: return "refuseSkip"
        case .refuseReverse: return "refuseReverse"
        case .interceptSkip: return "interceptSkip"
        case .declineIntercept: return "declineIntercept"
        case .jumpDraw: return "jumpDraw"
        }
    }

    /// Whether `playerIndex` is the player allowed to submit `action` right now. Ported from
    /// `LANGameHost.isAuthorized` — pins each action to `state.currentPlayerIndex` or the
    /// relevant grace-period/intercept-queue actor.
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
}
