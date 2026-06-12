import Foundation

/// Type-erased `RandomNumberGenerator` so CPU agents can be given a deterministic seed for
/// testing while defaulting to `SystemRandomNumberGenerator` in production.
public struct AnyRNG: RandomNumberGenerator {
    private var box: any RandomNumberGenerator

    public init(_ generator: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.box = generator
    }

    public mutating func next() -> UInt64 {
        box.next()
    }
}

/// AI opponent move selection for solo play. See docs/GAME_SPEC.md §I.
///
/// `chooseAction` is the top-level entry point, dispatching on `state.phase` /
/// `state.isDrawStackActive` to the decision-point hooks below. Subclasses (`MediumCpu`,
/// `HardCpu`) override individual hooks to change behavior; `EasyCpu` uses the base-class
/// (random / simplest-legal) implementations directly.
///
/// Two additional entry points are not phase-dispatched because they apply to a player who
/// is not necessarily `state.currentPlayer`:
/// - `graceInterceptDecision` — called when `state.skipInterceptGracePeriodPlayerIndex ==
///   playerIndex`.
/// - `lateKadiDecision` — called when `state.kadiGracePeriodPlayerIndex == playerIndex` and
///   `state.rules.lateKadiDeclaration`.
open class CpuAgent {
    public var rng: AnyRNG

    public init(rng: AnyRNG = AnyRNG()) {
        self.rng = rng
    }

    // MARK: - Top-level dispatch

    open func chooseAction(state: GameState, playerIndex: Int) -> GameAction {
        switch state.phase {
        case .suitChoice:
            return .chooseSuit(suit: chooseSuit(state: state, playerIndex: playerIndex))
        case .demandEntry:
            let (rank, suit) = makeDemand(state: state, playerIndex: playerIndex)
            return .makeDemand(rank: rank, suit: suit)
        case .questionAnswer:
            return answerQuestion(state: state, playerIndex: playerIndex)
        case .cardDemand:
            return respondToDemand(state: state, playerIndex: playerIndex)
        case .skipIntercept:
            return interceptDecision(state: state, playerIndex: playerIndex)
        case .playing, .finished:
            if state.isDrawStackActive {
                return drawStackResponse(state: state, playerIndex: playerIndex)
            }
            if let kadi = kadiDecision(state: state, playerIndex: playerIndex) {
                return kadi
            }
            return normalPlay(state: state, playerIndex: playerIndex)
        }
    }

    // MARK: - Decision points (default = Easy behavior)

    /// `ChooseSuit`: random suit.
    open func chooseSuit(state: GameState, playerIndex: Int) -> Suit {
        Suit.allCases.randomElement(using: &rng) ?? .hearts
    }

    /// `MakeDemand`: random non-Joker rank, random suit.
    open func makeDemand(state: GameState, playerIndex: Int) -> (rank: Rank, suit: Suit) {
        let ranks = Rank.allCases.filter { $0 != .joker }
        let rank = ranks.randomElement(using: &rng) ?? .six
        let suit = Suit.allCases.randomElement(using: &rng) ?? .hearts
        return (rank, suit)
    }

    /// `.questionAnswer`: play a matching-suit card if available, else pass.
    open func answerQuestion(state: GameState, playerIndex: Int) -> GameAction {
        let hand = state.players[playerIndex].hand
        guard let forcedSuit = state.forcedSuit else { return .pass }
        let matching = hand.filter { $0.suit == forcedSuit }
        guard let card = matching.randomElement(using: &rng) else { return .pass }
        return .playCards(cards: [card])
    }

    /// `.cardDemand`: play the demanded card if held, else counter with an Ace if held, else
    /// draw 1.
    open func respondToDemand(state: GameState, playerIndex: Int) -> GameAction {
        let hand = state.players[playerIndex].hand
        if let demanded = state.demandedCard, hand.contains(demanded) {
            return .respondToDemand(card: demanded)
        }
        if let ace = hand.first(where: \.isAce) {
            return .respondToDemand(card: ace)
        }
        return .respondToDemand(card: nil)
    }

    /// Draw stack active: play an Ace if held (refuse), else any valid draw card, else accept
    /// the stack.
    open func drawStackResponse(state: GameState, playerIndex: Int) -> GameAction {
        let hand = state.players[playerIndex].hand
        let valid = KadiValidator.validPlays(
            hand: hand, topCard: state.topCard, forcedSuit: state.forcedSuit, rules: state.rules
        )
        if let ace = valid.first(where: \.isAce) {
            return .refuseDraw(ace: ace)
        }
        if let drawCard = valid.first(where: { GameEngine.isRuledDrawCard($0, rules: state.rules) }) {
            return .playCards(cards: [drawCard])
        }
        return .drawStack
    }

    /// Whether (and how) to declare/play out a Kadi win this turn. Only declares by actually
    /// playing a game-ending hand — never a bare declaration unless it can win immediately.
    /// Returns `nil` if there's no winning chain (the caller should fall through to
    /// `normalPlay`).
    open func kadiDecision(state: GameState, playerIndex: Int) -> GameAction? {
        let hand = state.players[playerIndex].hand
        guard let chain = CpuAgent.findWinningChain(hand: hand, topCard: state.topCard, forcedSuit: state.forcedSuit) else {
            return nil
        }
        return .declareKadi(cards: chain)
    }

    /// Late-Kadi grace window (`state.kadiGracePeriodPlayerIndex == playerIndex`): declare if
    /// the hand can still be played out as a winning chain, else `nil` (decline by inaction).
    open func lateKadiDecision(state: GameState, playerIndex: Int) -> GameAction? {
        let hand = state.players[playerIndex].hand
        guard KadiValidator.canDeclareKadi(hand: hand, topCard: state.topCard, forcedSuit: state.forcedSuit, rules: state.rules) else {
            return nil
        }
        return .declareKadi(cards: [])
    }

    /// Blocking skip-intercept (`phase == .skipIntercept`). Default (Easy): decline.
    open func interceptDecision(state: GameState, playerIndex: Int) -> GameAction {
        .declineIntercept
    }

    /// Non-blocking skip-intercept grace window. Default (Easy): decline.
    open func graceInterceptDecision(state: GameState, playerIndex: Int) -> GameAction {
        .declineIntercept
    }

    /// Normal play (`.playing`, no draw stack): fully random among legal single-card plays,
    /// or pass/draw if none.
    open func normalPlay(state: GameState, playerIndex: Int) -> GameAction {
        let hand = state.players[playerIndex].hand
        let valid = KadiValidator.validPlays(
            hand: hand, topCard: state.topCard, forcedSuit: state.forcedSuit, rules: state.rules
        )
        guard let card = valid.randomElement(using: &rng) else { return .pass }
        return .playCards(cards: [card])
    }

    // MARK: - Shared helpers

    /// Returns true iff any opponent of `playerIndex` has 2 or fewer cards in hand.
    func anyOpponentHasFewCards(state: GameState, playerIndex: Int) -> Bool {
        state.players.indices.contains { $0 != playerIndex && state.players[$0].cardCount <= 2 }
    }

    /// All Jacks currently in `playerIndex`'s hand.
    func jacksInHand(state: GameState, playerIndex: Int) -> [PlayingCard] {
        state.players[playerIndex].hand.filter(\.isSkipCard)
    }

    /// The most common suit among `playerIndex`'s hand (first match in `Suit.allCases` order
    /// on ties; `.hearts` if the hand has no suited cards).
    func mostCommonSuit(state: GameState, playerIndex: Int) -> Suit {
        let counts = suitCounts(state: state, playerIndex: playerIndex)
        let maxCount = counts.values.max() ?? 0
        return Suit.allCases.first { counts[$0, default: 0] == maxCount } ?? .hearts
    }

    /// The least common suit among `playerIndex`'s hand (first match in `Suit.allCases` order
    /// on ties; `.hearts` if the hand has no suited cards).
    func leastCommonSuit(state: GameState, playerIndex: Int) -> Suit {
        let counts = suitCounts(state: state, playerIndex: playerIndex)
        let minCount = Suit.allCases.map { counts[$0, default: 0] }.min() ?? 0
        return Suit.allCases.first { counts[$0, default: 0] == minCount } ?? .hearts
    }

    private func suitCounts(state: GameState, playerIndex: Int) -> [Suit: Int] {
        var counts: [Suit: Int] = [:]
        for card in state.players[playerIndex].hand {
            if let suit = card.suit {
                counts[suit, default: 0] += 1
            }
        }
        return counts
    }

    /// Recursive DFS (mirrors `KadiValidator.canDeclareKadi`) that returns the actual ordered
    /// chain of cards that empties `hand` and ends on a `canEndGame` card, or `nil` if no
    /// such ordering exists.
    static func findWinningChain(hand: [PlayingCard], topCard: PlayingCard?, forcedSuit: Suit?) -> [PlayingCard]? {
        for (index, card) in hand.enumerated() {
            guard KadiValidator.isValidPlay(card: card, topCard: topCard, forcedSuit: forcedSuit) else { continue }

            var remaining = hand
            remaining.remove(at: index)

            if remaining.isEmpty {
                if card.canEndGame { return [card] }
                continue
            }

            if card.isQuestionCard {
                if let rest = findWinningChain(hand: remaining, topCard: card, forcedSuit: card.suit) {
                    return [card] + rest
                }
            } else if card.isAce {
                for suit in Suit.allCases {
                    if let rest = findWinningChain(hand: remaining, topCard: card, forcedSuit: suit) {
                        return [card] + rest
                    }
                }
            } else {
                if let rest = findWinningChain(hand: remaining, topCard: card, forcedSuit: nil) {
                    return [card] + rest
                }
            }
        }
        return nil
    }
}

/// Fully random among legal options. See docs/GAME_SPEC.md §I "EasyCpu" — uses all of
/// `CpuAgent`'s default (Easy) behaviors with no overrides.
public final class EasyCpu: CpuAgent {}

/// Intercepts skips if holding ≥2 Jacks. Picks `ChooseSuit`/demand suit as the most common
/// suit in hand; demands rank `6` and the least common suit in hand. Normal play prefers draw
/// cards and holds back refusal cards (Ace/Jack/King) unless they're the only legal play. See
/// docs/GAME_SPEC.md §I "MediumCpu".
public final class MediumCpu: CpuAgent {
    override public func chooseSuit(state: GameState, playerIndex: Int) -> Suit {
        mostCommonSuit(state: state, playerIndex: playerIndex)
    }

    override public func makeDemand(state: GameState, playerIndex: Int) -> (rank: Rank, suit: Suit) {
        (.six, leastCommonSuit(state: state, playerIndex: playerIndex))
    }

    override public func interceptDecision(state: GameState, playerIndex: Int) -> GameAction {
        let jacks = jacksInHand(state: state, playerIndex: playerIndex)
        guard jacks.count >= 2 else { return .declineIntercept }
        return .interceptSkip(jacks: jacks)
    }

    override public func graceInterceptDecision(state: GameState, playerIndex: Int) -> GameAction {
        interceptDecision(state: state, playerIndex: playerIndex)
    }

    override public func normalPlay(state: GameState, playerIndex: Int) -> GameAction {
        let hand = state.players[playerIndex].hand
        let valid = KadiValidator.validPlays(
            hand: hand, topCard: state.topCard, forcedSuit: state.forcedSuit, rules: state.rules
        )
        guard !valid.isEmpty else { return .pass }

        let drawCards = valid.filter { GameEngine.isRuledDrawCard($0, rules: state.rules) }
        if let card = drawCards.randomElement(using: &rng) {
            return .playCards(cards: [card])
        }

        let nonRefusal = valid.filter { !($0.isAce || $0.isSkipCard || $0.isReverseCard) }
        let pool = nonRefusal.isEmpty ? valid : nonRefusal
        let card = pool.randomElement(using: &rng) ?? valid[0]
        return .playCards(cards: [card])
    }
}

/// Maintains a played-card count for card counting. Intercepts skips if any opponent has ≤2
/// cards or it holds ≥2 Jacks (plays only 1 Jack via the grace path). Demands the rank least
/// represented in played cards and the suit most common in its own hand (ties favor hearts).
/// Question-answer prefers a non-special same-suit card. Normal play prioritizes draw/skip
/// cards if any opponent is low on cards, else prefers draw cards and holds back
/// Aces/Jacks/Kings. See docs/GAME_SPEC.md §I "HardCpu".
public final class HardCpu: CpuAgent {
    private var playedCounts: [Rank: Int] = [:]

    /// Call on every card seen (played by any player) for card counting.
    public func recordPlayed(_ card: PlayingCard) {
        playedCounts[card.rank, default: 0] += 1
    }

    override public func chooseSuit(state: GameState, playerIndex: Int) -> Suit {
        bestSuit(state: state, playerIndex: playerIndex)
    }

    override public func makeDemand(state: GameState, playerIndex: Int) -> (rank: Rank, suit: Suit) {
        let ranks = Rank.allCases.filter { $0 != .joker }
        let underTwo = ranks.filter { playedCounts[$0, default: 0] < 2 }
        let pool = underTwo.isEmpty ? ranks : underTwo
        let minCount = pool.map { playedCounts[$0, default: 0] }.min() ?? 0
        let candidates = pool.filter { playedCounts[$0, default: 0] == minCount }
        let rank = candidates.randomElement(using: &rng) ?? .six
        return (rank, bestSuit(state: state, playerIndex: playerIndex))
    }

    /// Most common suit in own hand; ties favor hearts.
    private func bestSuit(state: GameState, playerIndex: Int) -> Suit {
        mostCommonSuit(state: state, playerIndex: playerIndex)
    }

    override public func answerQuestion(state: GameState, playerIndex: Int) -> GameAction {
        let hand = state.players[playerIndex].hand
        guard let forcedSuit = state.forcedSuit else { return .pass }
        let matching = hand.filter { $0.suit == forcedSuit }
        if let nonSpecial = matching.filter({ !$0.isSpecial }).randomElement(using: &rng) {
            return .playCards(cards: [nonSpecial])
        }
        if let card = matching.randomElement(using: &rng) {
            return .playCards(cards: [card])
        }
        return .pass
    }

    override public func interceptDecision(state: GameState, playerIndex: Int) -> GameAction {
        let jacks = jacksInHand(state: state, playerIndex: playerIndex)
        guard !jacks.isEmpty,
              anyOpponentHasFewCards(state: state, playerIndex: playerIndex) || jacks.count >= 2
        else {
            return .declineIntercept
        }
        return .interceptSkip(jacks: jacks)
    }

    override public func graceInterceptDecision(state: GameState, playerIndex: Int) -> GameAction {
        let jacks = jacksInHand(state: state, playerIndex: playerIndex)
        guard let jack = jacks.first,
              anyOpponentHasFewCards(state: state, playerIndex: playerIndex) || jacks.count >= 2
        else {
            return .declineIntercept
        }
        return .interceptSkip(jacks: [jack])
    }

    override public func normalPlay(state: GameState, playerIndex: Int) -> GameAction {
        let hand = state.players[playerIndex].hand
        let valid = KadiValidator.validPlays(
            hand: hand, topCard: state.topCard, forcedSuit: state.forcedSuit, rules: state.rules
        )
        guard !valid.isEmpty else { return .pass }

        if anyOpponentHasFewCards(state: state, playerIndex: playerIndex) {
            let pressure = valid.filter { GameEngine.isRuledDrawCard($0, rules: state.rules) || $0.isSkipCard }
            if let card = pressure.randomElement(using: &rng) {
                return .playCards(cards: [card])
            }
        }

        let drawCards = valid.filter { GameEngine.isRuledDrawCard($0, rules: state.rules) }
        if let card = drawCards.randomElement(using: &rng) {
            return .playCards(cards: [card])
        }

        let nonRefusal = valid.filter { !($0.isAce || $0.isSkipCard || $0.isReverseCard) }
        let pool = nonRefusal.isEmpty ? valid : nonRefusal
        let card = pool.randomElement(using: &rng) ?? valid[0]
        return .playCards(cards: [card])
    }
}

/// Wraps Easy/Medium/Hard. Starts as Easy. After each round, every 3 rounds recomputes the
/// human player's win rate over those rounds and switches difficulty: win rate > 60% → Hard,
/// > 40% → Medium, else Easy. See docs/GAME_SPEC.md §I "AdaptiveCpu".
public final class AdaptiveCpu: CpuAgent {
    private var current: CpuAgent
    private var roundResults: [Bool] = []

    override public init(rng: AnyRNG = AnyRNG()) {
        self.current = EasyCpu(rng: rng)
        super.init(rng: rng)
    }

    /// Record whether the human player won the most recently completed round. Every 3 rounds,
    /// recomputes the win rate over those 3 rounds and switches the active difficulty.
    public func recordRoundResult(playerWon: Bool) {
        roundResults.append(playerWon)
        guard roundResults.count % 3 == 0 else { return }

        let recent = roundResults.suffix(3)
        let winRate = Double(recent.filter { $0 }.count) / Double(recent.count)

        if winRate > 0.6 {
            current = HardCpu(rng: rng)
        } else if winRate > 0.4 {
            current = MediumCpu(rng: rng)
        } else {
            current = EasyCpu(rng: rng)
        }
    }

    /// The currently-selected difficulty's agent.
    public var activeAgent: CpuAgent { current }

    override public func chooseAction(state: GameState, playerIndex: Int) -> GameAction {
        current.chooseAction(state: state, playerIndex: playerIndex)
    }
}
