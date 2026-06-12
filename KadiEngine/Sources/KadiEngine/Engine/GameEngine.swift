import Foundation

/// Thrown by `GameEngine.applyAction` when `validateAction` returns a non-nil error message.
public struct InvalidActionError: Error, Equatable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
}

/// Pure, stateless game engine. All state is immutable; every action produces a new
/// `GameState`. See docs/GAME_SPEC.md §G.
public enum GameEngine {
    // MARK: - Game creation

    /// Build a new game: shuffled deck, dealt hands, starting card. `currentPlayerIndex = 0`,
    /// `direction = .clockwise`, `phase = .playing`.
    public static func createGame(players: [Player], rules: RuleSet = RuleSet()) throws -> GameState {
        var rng = SystemRandomNumberGenerator()
        return try createGame(players: players, rules: rules, using: &rng)
    }

    public static func createGame(
        players: [Player],
        rules: RuleSet,
        using rng: inout some RandomNumberGenerator
    ) throws -> GameState {
        let (dealt, drawPile, discardPile) = try DeckBuilder.buildAndDeal(players: players, rules: rules, using: &rng)
        return GameState(
            players: dealt,
            drawPile: drawPile,
            discardPile: discardPile,
            currentPlayerIndex: 0,
            rules: rules,
            direction: .clockwise,
            pendingDrawCount: 0,
            phase: .playing
        )
    }

    // MARK: - Validation

    /// Returns an error message if `action` is not legal in `state`, or `nil` if it is legal.
    public static func validateAction(_ state: GameState, _ action: GameAction) -> String? {
        switch action {
        case .playCards(let cards):
            return validatePlayCards(state, cards: cards)
        case .pass:
            return validatePass(state)
        case .drawStack:
            return validateDrawStack(state)
        case .declareKadi(let cards):
            return validateDeclareKadi(state, cards: cards)
        case .chooseSuit:
            return validateChooseSuit(state)
        case .makeDemand(let rank, _):
            return validateMakeDemand(state, rank: rank)
        case .respondToDemand(let card):
            return validateRespondToDemand(state, card: card)
        case .refuseDraw(let ace):
            return validateRefuseDraw(state, ace: ace)
        case .refuseSkip(let jack):
            return validateRefuseSkip(state, jack: jack)
        case .refuseReverse(let king):
            return validateRefuseReverse(state, king: king)
        case .interceptSkip(let jacks):
            return validateInterceptSkip(state, jacks: jacks)
        case .declineIntercept:
            return validateDeclineIntercept(state)
        case .jumpDraw(let jack):
            return validateJumpDraw(state, jack: jack)
        }
    }

    // MARK: - Apply

    /// Validate then apply `action` to `state`, returning the resulting `GameState`. Throws
    /// `InvalidActionError` if `validateAction` returns a non-nil error message.
    public static func applyAction(_ state: GameState, _ action: GameAction) throws -> GameState {
        var rng = SystemRandomNumberGenerator()
        return try applyAction(state, action, using: &rng)
    }

    public static func applyAction(
        _ state: GameState,
        _ action: GameAction,
        using rng: inout some RandomNumberGenerator
    ) throws -> GameState {
        if let error = validateAction(state, action) {
            throw InvalidActionError(error)
        }

        var newState = state

        // Always clear the late-Kadi grace window unless this action is DeclareKadi.
        if newState.rules.lateKadiDeclaration {
            if case .declareKadi = action {
                // Handled by applyDeclareKadi itself.
            } else {
                newState.kadiGracePeriodPlayerIndex = nil
            }
        }

        // Always clear the skip-intercept grace window unless this action is InterceptSkip.
        if case .interceptSkip = action {
            // Handled by applyInterceptSkip itself.
        } else {
            newState.skipInterceptGracePeriodPlayerIndex = nil
        }

        switch action {
        case .playCards(let cards):
            return applyPlayCardsCore(newState, cards: cards, isDeclaring: false, using: &rng)
        case .pass:
            return applyPass(newState, using: &rng)
        case .drawStack:
            return applyDrawStack(newState, using: &rng)
        case .declareKadi(let cards):
            return applyDeclareKadi(newState, cards: cards, using: &rng)
        case .chooseSuit(let suit):
            return applyChooseSuit(newState, suit: suit)
        case .makeDemand(let rank, let suit):
            return applyMakeDemand(newState, rank: rank, suit: suit)
        case .respondToDemand(let card):
            return applyRespondToDemand(newState, card: card, using: &rng)
        case .refuseDraw(let ace):
            return applyRefuseDraw(newState, ace: ace)
        case .refuseSkip(let jack):
            return applyRefuseSkip(newState, jack: jack)
        case .refuseReverse(let king):
            return applyRefuseReverse(newState, king: king)
        case .interceptSkip(let jacks):
            return applyInterceptSkip(newState, jacks: jacks)
        case .declineIntercept:
            return applyDeclineIntercept(newState)
        case .jumpDraw(let jack):
            return applyJumpDraw(newState, jack: jack)
        }
    }

    // MARK: - Shared helpers (docs/GAME_SPEC.md §G)

    /// `two` → `rules.twosEnabled`, `three` → `rules.threesEnabled`, else `card.isDrawCard`
    /// (covers Jokers).
    static func isRuledDrawCard(_ card: PlayingCard, rules: RuleSet) -> Bool {
        switch card.rank {
        case .two: return rules.twosEnabled
        case .three: return rules.threesEnabled
        default: return card.isDrawCard
        }
    }

    static func isValidPlay(_ card: PlayingCard, state: GameState) -> Bool {
        KadiValidator.isValidPlay(card: card, topCard: state.topCard, forcedSuit: state.forcedSuit)
    }

    /// Whether `hand` contains every card in `cards` (as a multiset — duplicates require
    /// duplicate copies in `hand`).
    static func handContains(_ hand: [PlayingCard], _ cards: [PlayingCard]) -> Bool {
        var remaining = hand
        for card in cards {
            guard let idx = remaining.firstIndex(of: card) else { return false }
            remaining.remove(at: idx)
        }
        return true
    }

    /// Draw `n` cards into `players[playerIndex]`'s hand. If `drawPile` runs out, shuffle the
    /// discard pile (minus its top card) into the draw pile and continue.
    static func drawCards(_ state: inout GameState, count n: Int, playerIndex: Int, using rng: inout some RandomNumberGenerator) {
        guard n > 0 else { return }
        for _ in 0..<n {
            if state.drawPile.isEmpty {
                if state.discardPile.count > 1 {
                    let top = state.discardPile.removeLast()
                    var rest = state.discardPile
                    rest.shuffle(using: &rng)
                    state.drawPile = rest
                    state.discardPile = [top]
                } else {
                    break
                }
            }
            guard !state.drawPile.isEmpty else { break }
            state.players[playerIndex].hand.append(state.drawPile.removeFirst())
        }
    }

    /// Move `currentPlayerIndex` by one step in `direction` (wrapping), reset `phase =
    /// .playing`. If `lateKadiDeclaration`, open a grace window for the player whose turn
    /// just ended.
    static func advanceTurn(_ state: inout GameState) {
        let n = state.players.count
        let endingPlayer = state.currentPlayerIndex
        let step = state.direction.step
        state.currentPlayerIndex = ((state.currentPlayerIndex + step) % n + n) % n
        state.phase = .playing
        if state.rules.lateKadiDeclaration {
            state.kadiGracePeriodPlayerIndex = endingPlayer
        }
    }

    /// Scan `discardPile` backwards for the first draw card (per `isRuledDrawCard`) — the
    /// card that triggered the current draw stack (used by `JumpDraw`).
    static func findTriggeringDrawCard(_ state: GameState) -> PlayingCard? {
        for card in state.discardPile.reversed() where isRuledDrawCard(card, rules: state.rules) {
            return card
        }
        return nil
    }

    /// Rebuild the skip-intercept queue from `playerIndex`'s seat, skipping `count` players
    /// and excluding anyone already in `skipInterceptedBy` (docs/GAME_SPEC.md §G.11).
    static func buildSkipInterceptQueue(_ state: GameState, from playerIndex: Int, skipping count: Int) -> [Int] {
        let n = state.players.count
        guard n > 0 else { return [] }
        let step = state.direction.step
        var queue: [Int] = []
        var seat = playerIndex
        for _ in 0..<count {
            seat = ((seat + step) % n + n) % n
            if seat != playerIndex && !state.skipInterceptedBy.contains(seat) {
                queue.append(seat)
            }
        }
        return queue
    }

    /// Resolve a pending skip-intercept chain: advance from `skipOriginIndex` by
    /// `pendingSkipCount + 1`, clear all skip-intercept bookkeeping, `phase = .playing`.
    static func resolveSkip(_ state: inout GameState) {
        let n = state.players.count
        let step = state.direction.step
        let origin = state.skipOriginIndex ?? state.currentPlayerIndex
        state.currentPlayerIndex = ((origin + step * (state.pendingSkipCount + 1)) % n + n) % n
        state.phase = .playing
        state.skipInterceptQueue = []
        state.pendingSkipCount = 0
        state.skipOriginIndex = nil
        state.skipInterceptedBy = []
        state.skipInterceptGracePeriodPlayerIndex = nil
    }
}
