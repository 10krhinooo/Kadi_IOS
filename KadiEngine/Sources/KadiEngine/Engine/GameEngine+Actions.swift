import Foundation

/// `applyAction` per-action transitions for everything other than `PlayCards` (handled in
/// `GameEngine+PlayCards.swift`). See docs/GAME_SPEC.md §G (numbered list).
extension GameEngine {
    // MARK: - 3. Pass

    static func applyPass(_ state: GameState, using rng: inout some RandomNumberGenerator) -> GameState {
        var newState = state
        let playerIndex = newState.currentPlayerIndex
        let wasQuestionAnswer = newState.phase == .questionAnswer

        drawCards(&newState, count: 1, playerIndex: playerIndex, using: &rng)

        if wasQuestionAnswer {
            newState.forcedSuit = nil
        }

        if newState.kadiState?.declaringPlayerIndex == playerIndex {
            newState.kadiState = nil
            if newState.rules.kadiPenalty > 0 {
                drawCards(&newState, count: newState.rules.kadiPenalty, playerIndex: playerIndex, using: &rng)
            }
        }

        advanceTurn(&newState)
        return newState
    }

    // MARK: - 4. DrawStack

    static func applyDrawStack(_ state: GameState, using rng: inout some RandomNumberGenerator) -> GameState {
        var newState = state
        let playerIndex = newState.currentPlayerIndex
        let count = newState.pendingDrawCount

        drawCards(&newState, count: count, playerIndex: playerIndex, using: &rng)
        newState.pendingDrawCount = 0

        if newState.kadiState?.declaringPlayerIndex == playerIndex {
            newState.kadiState = nil
            if newState.rules.kadiPenalty > 0 {
                drawCards(&newState, count: newState.rules.kadiPenalty, playerIndex: playerIndex, using: &rng)
            }
        }

        advanceTurn(&newState)
        return newState
    }

    // MARK: - 5. DeclareKadi

    static func applyDeclareKadi(_ state: GameState, cards: [PlayingCard], using rng: inout some RandomNumberGenerator) -> GameState {
        var newState = state

        // Out-of-turn (late) path.
        if newState.rules.lateKadiDeclaration,
           let graceIndex = newState.kadiGracePeriodPlayerIndex,
           graceIndex != newState.currentPlayerIndex,
           cards.isEmpty {
            newState.kadiState = KadiState(declaringPlayerIndex: graceIndex)
            newState.kadiGracePeriodPlayerIndex = nil
            return newState
        }

        // In-turn path.
        let playerIndex = newState.currentPlayerIndex
        newState.kadiState = KadiState(declaringPlayerIndex: playerIndex)

        if cards.isEmpty {
            advanceTurn(&newState)
            return newState
        }

        return applyPlayCardsCore(newState, cards: cards, isDeclaring: true, using: &rng)
    }

    // MARK: - 6. ChooseSuit

    static func applyChooseSuit(_ state: GameState, suit: Suit) -> GameState {
        var newState = state
        let restoredPhase = newState.preSuitChoicePhase ?? .playing
        newState.forcedSuit = suit
        newState.preSuitChoicePhase = nil
        // `advanceTurn` unconditionally resets `phase = .playing`, so set the restored phase
        // afterwards to make it stick (mirrors the `MakeDemand` workaround above).
        advanceTurn(&newState)
        newState.phase = restoredPhase
        return newState
    }

    // MARK: - 1. MakeDemand

    static func applyMakeDemand(_ state: GameState, rank: Rank, suit: Suit) -> GameState {
        var newState = state
        newState.demandedCard = PlayingCard(rank: rank, suit: suit)
        // `advanceTurn` unconditionally resets `phase = .playing`, so set the demand phase
        // afterwards to make it stick for the next player.
        advanceTurn(&newState)
        newState.phase = .cardDemand
        return newState
    }

    // MARK: - 7. RespondToDemand

    static func applyRespondToDemand(_ state: GameState, card: PlayingCard?, using rng: inout some RandomNumberGenerator) -> GameState {
        var newState = state
        let playerIndex = newState.currentPlayerIndex

        guard let card else {
            drawCards(&newState, count: 1, playerIndex: playerIndex, using: &rng)
            newState.demandedCard = nil
            newState.phase = .playing
            if newState.kadiState?.declaringPlayerIndex == playerIndex {
                newState.kadiState = nil
                if newState.rules.kadiPenalty > 0 {
                    drawCards(&newState, count: newState.rules.kadiPenalty, playerIndex: playerIndex, using: &rng)
                }
            }
            advanceTurn(&newState)
            return newState
        }

        newState.phase = .playing
        newState.demandedCard = nil
        return applyPlayCardsCore(newState, cards: [card], isDeclaring: false, using: &rng)
    }

    // MARK: - 8. RefuseDraw

    static func applyRefuseDraw(_ state: GameState, ace: PlayingCard) -> GameState {
        var newState = state
        let playerIndex = newState.currentPlayerIndex
        if let idx = newState.players[playerIndex].hand.firstIndex(of: ace) {
            newState.players[playerIndex].hand.remove(at: idx)
        }
        newState.discardPile.append(ace)
        newState.pendingDrawCount = 0

        if ace.isAceOfSpades {
            newState.phase = .suitChoice
            newState.preSuitChoicePhase = .playing
        } else {
            advanceTurn(&newState)
        }
        return newState
    }

    // MARK: - 9. RefuseSkip
    //
    // The skip is cancelled and instead lands on the next player — i.e. the skip target is
    // shifted one seat further than it would otherwise have landed. We model this as: move
    // the Jack to discard, then shift `currentPlayerIndex` forward by one extra step before
    // the normal turn advance.

    static func applyRefuseSkip(_ state: GameState, jack: PlayingCard) -> GameState {
        var newState = state
        let playerIndex = newState.currentPlayerIndex
        if let idx = newState.players[playerIndex].hand.firstIndex(of: jack) {
            newState.players[playerIndex].hand.remove(at: idx)
        }
        newState.discardPile.append(jack)

        let n = newState.players.count
        let step = newState.direction.step
        newState.currentPlayerIndex = ((newState.currentPlayerIndex + step) % n + n) % n
        advanceTurn(&newState)
        return newState
    }

    // MARK: - 10. RefuseReverse

    static func applyRefuseReverse(_ state: GameState, king: PlayingCard) -> GameState {
        var newState = state
        let playerIndex = newState.currentPlayerIndex
        if let idx = newState.players[playerIndex].hand.firstIndex(of: king) {
            newState.players[playerIndex].hand.remove(at: idx)
        }
        newState.discardPile.append(king)
        // Direction stays unchanged (reversal cancelled).
        advanceTurn(&newState)
        return newState
    }

    // MARK: - 11. InterceptSkip

    static func applyInterceptSkip(_ state: GameState, jacks: [PlayingCard]) -> GameState {
        var newState = state

        // Non-blocking grace window.
        if let graceIndex = newState.skipInterceptGracePeriodPlayerIndex {
            for jack in jacks {
                if let idx = newState.players[graceIndex].hand.firstIndex(of: jack) {
                    newState.players[graceIndex].hand.remove(at: idx)
                }
            }
            newState.discardPile.append(contentsOf: jacks)
            newState.skipInterceptGracePeriodPlayerIndex = nil

            let newSkipCount = jacks.count
            let n = newState.players.count
            let step = newState.direction.step
            newState.currentPlayerIndex = ((graceIndex + step * (newSkipCount + 1)) % n + n) % n
            newState.phase = .playing
            return newState
        }

        // Blocking (`phase == .skipIntercept`).
        let playerIndex = newState.currentPlayerIndex
        for jack in jacks {
            if let idx = newState.players[playerIndex].hand.firstIndex(of: jack) {
                newState.players[playerIndex].hand.remove(at: idx)
            }
        }
        newState.discardPile.append(contentsOf: jacks)
        newState.skipInterceptedBy.insert(playerIndex)

        let newSkipCount = jacks.count
        let queue = buildSkipInterceptQueue(newState, from: playerIndex, skipping: newSkipCount)
        newState.skipInterceptQueue = queue

        if let next = queue.first {
            newState.phase = .skipIntercept
            newState.currentPlayerIndex = next
        } else {
            resolveSkip(&newState)
        }
        return newState
    }

    // MARK: - 12. DeclineIntercept

    static func applyDeclineIntercept(_ state: GameState) -> GameState {
        var newState = state

        if newState.skipInterceptGracePeriodPlayerIndex != nil {
            newState.skipInterceptGracePeriodPlayerIndex = nil
            return newState
        }

        if !newState.skipInterceptQueue.isEmpty {
            newState.skipInterceptQueue.removeFirst()
        }
        if let next = newState.skipInterceptQueue.first {
            newState.currentPlayerIndex = next
            newState.phase = .skipIntercept
        } else {
            resolveSkip(&newState)
        }
        return newState
    }

    // MARK: - 13. JumpDraw

    static func applyJumpDraw(_ state: GameState, jack: PlayingCard) -> GameState {
        var newState = state
        let playerIndex = newState.currentPlayerIndex
        if let idx = newState.players[playerIndex].hand.firstIndex(of: jack) {
            newState.players[playerIndex].hand.remove(at: idx)
        }
        newState.discardPile.append(jack)
        // pendingDrawCount unchanged — the draw obligation passes to the next player.
        advanceTurn(&newState)
        return newState
    }
}
