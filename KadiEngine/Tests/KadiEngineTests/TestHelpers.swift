import Foundation
@testable import KadiEngine

/// Deterministic, seedable RNG (xorshift64*) for reproducible tests.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xdead_beef : seed
    }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545_F491_4F6C_DD1D
    }
}

func makePlayer(_ id: String, hand: [PlayingCard], isHuman: Bool = false) -> Player {
    Player(id: id, name: id, hand: hand, isHuman: isHuman)
}

func makeState(
    players: [Player],
    drawPile: [PlayingCard] = [],
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
    kadiGracePeriodPlayerIndex: Int? = nil,
    skipInterceptQueue: [Int] = [],
    pendingSkipCount: Int = 0,
    skipOriginIndex: Int? = nil,
    skipInterceptedBy: Set<Int> = [],
    skipInterceptGracePeriodPlayerIndex: Int? = nil
) -> GameState {
    GameState(
        players: players,
        drawPile: drawPile,
        discardPile: discardPile,
        currentPlayerIndex: currentPlayerIndex,
        rules: rules,
        direction: direction,
        pendingDrawCount: pendingDrawCount,
        forcedSuit: forcedSuit,
        demandedCard: demandedCard,
        kadiState: kadiState,
        phase: phase,
        preSuitChoicePhase: preSuitChoicePhase,
        kadiGracePeriodPlayerIndex: kadiGracePeriodPlayerIndex,
        skipInterceptQueue: skipInterceptQueue,
        pendingSkipCount: pendingSkipCount,
        skipOriginIndex: skipOriginIndex,
        skipInterceptedBy: skipInterceptedBy,
        skipInterceptGracePeriodPlayerIndex: skipInterceptGracePeriodPlayerIndex
    )
}

func card(_ rank: Rank, _ suit: Suit?) -> PlayingCard {
    PlayingCard(rank: rank, suit: suit)
}
