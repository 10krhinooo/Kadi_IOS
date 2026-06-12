import Foundation

/// Direction of play. Raw values match the Dart `Direction` enum's `.name` (see
/// docs/GAME_SPEC.md §C, §K).
public enum Direction: String, Codable, Sendable {
    case clockwise, anticlockwise

    /// Index offset applied to `currentPlayerIndex` per step in this direction.
    public var step: Int {
        switch self {
        case .clockwise: return 1
        case .anticlockwise: return -1
        }
    }

    public var flipped: Direction {
        switch self {
        case .clockwise: return .anticlockwise
        case .anticlockwise: return .clockwise
        }
    }
}

/// Game phase. Raw values match the Dart `GamePhase` enum's `.name` (see docs/GAME_SPEC.md
/// §C, §K).
public enum GamePhase: String, Codable, Sendable {
    /// Normal turn.
    case playing
    /// Current player must choose a suit (after non-A♠️ Ace, or after 8/Q).
    case suitChoice
    /// A♠️ (or 2+ Aces) played; current player must call `MakeDemand`.
    case demandEntry
    /// A demand is active; the next player must play the demanded card or counter with an Ace.
    case cardDemand
    /// Same player who played 8/Q must immediately play a card of `forcedSuit`, or pass.
    case questionAnswer
    /// Blocking chain where queued players decide to intercept a pending skip.
    case skipIntercept
    /// Game over.
    case finished
}

/// Non-blocking active Kadi declaration. See docs/GAME_SPEC.md §C, §K.
public struct KadiState: Codable, Equatable, Hashable, Sendable {
    public var declaringPlayerIndex: Int

    public init(declaringPlayerIndex: Int) {
        self.declaringPlayerIndex = declaringPlayerIndex
    }
}

/// The full, immutable state of a Kadi game. All mutation happens by producing a new
/// `GameState` via `GameEngine.applyAction`. Field names/types and JSON shape match the Dart
/// `GameState` + `GameStateCodec` exactly (see docs/GAME_SPEC.md §C, §K) for LAN/Firestore
/// wire compatibility.
///
/// Note: `kadiGracePeriodPlayerIndex` and `skipInterceptGracePeriodPlayerIndex` are
/// engine-local bookkeeping fields that are **not** part of the Dart wire format (§K does not
/// list them) and are therefore not encoded/decoded.
public struct GameState: Equatable, Sendable {
    public var players: [Player]
    public var drawPile: [PlayingCard]
    public var discardPile: [PlayingCard]
    public var currentPlayerIndex: Int
    public var rules: RuleSet
    public var direction: Direction
    public var pendingDrawCount: Int
    public var forcedSuit: Suit?
    public var demandedCard: PlayingCard?
    public var kadiState: KadiState?
    public var phase: GamePhase
    public var preSuitChoicePhase: GamePhase?
    public var pendingSkipTarget: Int?
    public var winningCards: [PlayingCard]
    public var kadiGracePeriodPlayerIndex: Int?
    public var skipInterceptQueue: [Int]
    public var pendingSkipCount: Int
    public var skipOriginIndex: Int?
    public var skipInterceptedBy: Set<Int>
    public var skipInterceptGracePeriodPlayerIndex: Int?

    public init(
        players: [Player],
        drawPile: [PlayingCard],
        discardPile: [PlayingCard],
        currentPlayerIndex: Int = 0,
        rules: RuleSet = RuleSet(),
        direction: Direction = .clockwise,
        pendingDrawCount: Int = 0,
        forcedSuit: Suit? = nil,
        demandedCard: PlayingCard? = nil,
        kadiState: KadiState? = nil,
        phase: GamePhase = .playing,
        preSuitChoicePhase: GamePhase? = nil,
        pendingSkipTarget: Int? = nil,
        winningCards: [PlayingCard] = [],
        kadiGracePeriodPlayerIndex: Int? = nil,
        skipInterceptQueue: [Int] = [],
        pendingSkipCount: Int = 0,
        skipOriginIndex: Int? = nil,
        skipInterceptedBy: Set<Int> = [],
        skipInterceptGracePeriodPlayerIndex: Int? = nil
    ) {
        self.players = players
        self.drawPile = drawPile
        self.discardPile = discardPile
        self.currentPlayerIndex = currentPlayerIndex
        self.rules = rules
        self.direction = direction
        self.pendingDrawCount = pendingDrawCount
        self.forcedSuit = forcedSuit
        self.demandedCard = demandedCard
        self.kadiState = kadiState
        self.phase = phase
        self.preSuitChoicePhase = preSuitChoicePhase
        self.pendingSkipTarget = pendingSkipTarget
        self.winningCards = winningCards
        self.kadiGracePeriodPlayerIndex = kadiGracePeriodPlayerIndex
        self.skipInterceptQueue = skipInterceptQueue
        self.pendingSkipCount = pendingSkipCount
        self.skipOriginIndex = skipOriginIndex
        self.skipInterceptedBy = skipInterceptedBy
        self.skipInterceptGracePeriodPlayerIndex = skipInterceptGracePeriodPlayerIndex
    }

    // MARK: - Derived properties (docs/GAME_SPEC.md §C)

    public var topCard: PlayingCard? { discardPile.last }

    public var currentPlayer: Player { players[currentPlayerIndex] }

    public var isDrawStackActive: Bool { pendingDrawCount > 0 }
}

// MARK: - Codable (matches docs/GAME_SPEC.md §K wire format)

extension GameState: Codable {
    enum CodingKeys: String, CodingKey {
        case players
        case drawPileCount
        case drawPile
        case discardPile
        case currentPlayerIndex
        case direction
        case pendingDrawCount
        case forcedSuit
        case demandedCard
        case kadiState
        case rules
        case phase
        case preSuitChoicePhase
        case pendingSkipTarget
        case winningCards
        case skipInterceptQueue
        case pendingSkipCount
        case skipOriginIndex
        case skipInterceptedBy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode([Player].self, forKey: .players)
        drawPile = try container.decode([PlayingCard].self, forKey: .drawPile)
        discardPile = try container.decode([PlayingCard].self, forKey: .discardPile)
        currentPlayerIndex = try container.decode(Int.self, forKey: .currentPlayerIndex)
        direction = try container.decode(Direction.self, forKey: .direction)
        pendingDrawCount = try container.decode(Int.self, forKey: .pendingDrawCount)
        forcedSuit = try container.decodeIfPresent(Suit.self, forKey: .forcedSuit)
        demandedCard = try container.decodeIfPresent(PlayingCard.self, forKey: .demandedCard)
        kadiState = try container.decodeIfPresent(KadiState.self, forKey: .kadiState)
        rules = try container.decode(RuleSet.self, forKey: .rules)
        phase = try container.decode(GamePhase.self, forKey: .phase)
        preSuitChoicePhase = try container.decodeIfPresent(GamePhase.self, forKey: .preSuitChoicePhase)
        pendingSkipTarget = try container.decodeIfPresent(Int.self, forKey: .pendingSkipTarget)
        winningCards = try container.decodeIfPresent([PlayingCard].self, forKey: .winningCards) ?? []
        skipInterceptQueue = try container.decodeIfPresent([Int].self, forKey: .skipInterceptQueue) ?? []
        pendingSkipCount = try container.decodeIfPresent(Int.self, forKey: .pendingSkipCount) ?? 0
        skipOriginIndex = try container.decodeIfPresent(Int.self, forKey: .skipOriginIndex)
        let interceptedByArray = try container.decodeIfPresent([Int].self, forKey: .skipInterceptedBy) ?? []
        skipInterceptedBy = Set(interceptedByArray)
        // Engine-local bookkeeping, not part of the wire format.
        kadiGracePeriodPlayerIndex = nil
        skipInterceptGracePeriodPlayerIndex = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(players, forKey: .players)
        try container.encode(drawPile.count, forKey: .drawPileCount)
        try container.encode(drawPile, forKey: .drawPile)
        try container.encode(discardPile, forKey: .discardPile)
        try container.encode(currentPlayerIndex, forKey: .currentPlayerIndex)
        try container.encode(direction, forKey: .direction)
        try container.encode(pendingDrawCount, forKey: .pendingDrawCount)
        try container.encodeIfPresent(forcedSuit, forKey: .forcedSuit)
        try container.encodeIfPresent(demandedCard, forKey: .demandedCard)
        try container.encodeIfPresent(kadiState, forKey: .kadiState)
        try container.encode(rules, forKey: .rules)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(preSuitChoicePhase, forKey: .preSuitChoicePhase)
        try container.encodeIfPresent(pendingSkipTarget, forKey: .pendingSkipTarget)
        try container.encode(winningCards, forKey: .winningCards)
        try container.encode(skipInterceptQueue, forKey: .skipInterceptQueue)
        try container.encode(pendingSkipCount, forKey: .pendingSkipCount)
        try container.encodeIfPresent(skipOriginIndex, forKey: .skipOriginIndex)
        try container.encode(skipInterceptedBy.sorted(), forKey: .skipInterceptedBy)
    }
}

// MARK: - Equatable

extension GameState {
    public static func == (lhs: GameState, rhs: GameState) -> Bool {
        lhs.players == rhs.players &&
            lhs.drawPile == rhs.drawPile &&
            lhs.discardPile == rhs.discardPile &&
            lhs.currentPlayerIndex == rhs.currentPlayerIndex &&
            lhs.rules == rhs.rules &&
            lhs.direction == rhs.direction &&
            lhs.pendingDrawCount == rhs.pendingDrawCount &&
            lhs.forcedSuit == rhs.forcedSuit &&
            lhs.demandedCard == rhs.demandedCard &&
            lhs.kadiState == rhs.kadiState &&
            lhs.phase == rhs.phase &&
            lhs.preSuitChoicePhase == rhs.preSuitChoicePhase &&
            lhs.pendingSkipTarget == rhs.pendingSkipTarget &&
            lhs.winningCards == rhs.winningCards &&
            lhs.kadiGracePeriodPlayerIndex == rhs.kadiGracePeriodPlayerIndex &&
            lhs.skipInterceptQueue == rhs.skipInterceptQueue &&
            lhs.pendingSkipCount == rhs.pendingSkipCount &&
            lhs.skipOriginIndex == rhs.skipOriginIndex &&
            lhs.skipInterceptedBy == rhs.skipInterceptedBy &&
            lhs.skipInterceptGracePeriodPlayerIndex == rhs.skipInterceptGracePeriodPlayerIndex
    }
}
