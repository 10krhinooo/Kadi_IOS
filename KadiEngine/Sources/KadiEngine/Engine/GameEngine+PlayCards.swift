import Foundation

/// `_applyPlayCards` — shared by `PlayCards`, `DeclareKadi` (with cards), and
/// `RespondToDemand` (with a card). See docs/GAME_SPEC.md §G.2 (numbered steps 1-13).
extension GameEngine {
    static func applyPlayCardsCore(
        _ state: GameState,
        cards: [PlayingCard],
        isDeclaring: Bool,
        using rng: inout some RandomNumberGenerator
    ) -> GameState {
        var newState = state
        let playerIndex = newState.currentPlayerIndex
        let lastCard = cards[cards.count - 1]

        // Step 1: remove cards from hand, append to discard. Clear forcedSuit/demandedCard.
        for card in cards {
            if let idx = newState.players[playerIndex].hand.firstIndex(of: card) {
                newState.players[playerIndex].hand.remove(at: idx)
            }
        }
        newState.discardPile.append(contentsOf: cards)
        newState.forcedSuit = nil
        newState.demandedCard = nil

        // Step 2: hand now empty -> win check.
        if newState.players[playerIndex].hand.isEmpty {
            let hasActiveDeclaration = newState.kadiState?.declaringPlayerIndex == playerIndex
            if isDeclaring || hasActiveDeclaration {
                newState.phase = .finished
                newState.pendingDrawCount = 0
                newState.winningCards = cards
                return newState
            } else {
                // False-Kadi penalty: draw 2 (hardcoded regardless of rules.kadiPenalty).
                drawCards(&newState, count: 2, playerIndex: playerIndex, using: &rng)
                advanceTurn(&newState)
                return newState
            }
        }

        // Step 3: cancel an active declaration for this player (hand non-empty).
        if newState.kadiState?.declaringPlayerIndex == playerIndex {
            newState.kadiState = nil
            if newState.rules.kadiPenalty > 0 {
                drawCards(&newState, count: newState.rules.kadiPenalty, playerIndex: playerIndex, using: &rng)
            }
        }

        // Step 4: last played card is a ruled draw card.
        if isRuledDrawCard(lastCard, rules: newState.rules) {
            if newState.isDrawStackActive {
                newState.pendingDrawCount += lastCard.drawValue
            } else {
                newState.pendingDrawCount = cards
                    .filter { isRuledDrawCard($0, rules: newState.rules) }
                    .reduce(0) { $0 + $1.drawValue }
            }
            if newState.rules.drawStackCap > 0 {
                newState.pendingDrawCount = min(newState.pendingDrawCount, newState.rules.drawStackCap)
            }
            advanceTurn(&newState)
            return newState
        }

        // Step 5: last card is a question card (8 or Q).
        if lastCard.isQuestionCard {
            newState.phase = .questionAnswer
            newState.forcedSuit = lastCard.suit
            newState.pendingDrawCount = 0
            return newState
        }

        // Step 6: phase was .cardDemand and last card is an Ace (counter play).
        if state.phase == .cardDemand && lastCard.isAce {
            newState.forcedSuit = state.demandedCard?.suit
            newState.demandedCard = nil
            newState.phase = .playing
            advanceTurn(&newState)
            return newState
        }

        // Step 7: last card is an Ace and a draw stack is active (refusing via the chain).
        if lastCard.isAce && state.isDrawStackActive {
            newState.pendingDrawCount = 0
            let aceCount = cards.filter(\.isAce).count
            if lastCard.isAceOfSpades || aceCount >= 2 {
                newState.phase = .suitChoice
                newState.preSuitChoicePhase = .playing
            } else {
                advanceTurn(&newState)
            }
            return newState
        }

        // Step 8: 2+ Aces played, no draw stack active.
        let aceCount = cards.filter(\.isAce).count
        if aceCount >= 2 {
            newState.phase = .demandEntry
            newState.pendingDrawCount = 0
            return newState
        }

        // Step 9: single A♠️ played and aceOfSpadesEnabled.
        if lastCard.isAceOfSpades && newState.rules.aceOfSpadesEnabled {
            newState.phase = .demandEntry
            newState.pendingDrawCount = 0
            return newState
        }

        // Step 10: any other single Ace.
        if lastCard.isAce {
            newState.phase = .suitChoice
            newState.preSuitChoicePhase = state.phase
            newState.pendingDrawCount = 0
            return newState
        }

        // Step 11: last card is a Jack (skip).
        if lastCard.isSkipCard {
            let n = newState.players.count
            let skipCount = (newState.rules.jackStackable && cards.count > 1) ? cards.count : 1
            let step = newState.direction.step
            newState.currentPlayerIndex = ((playerIndex + step * (skipCount + 1)) % n + n) % n
            newState.phase = .playing
            newState.pendingDrawCount = 0
            if newState.rules.jumpInterceptAllowed {
                newState.skipInterceptGracePeriodPlayerIndex = ((playerIndex + step) % n + n) % n
                newState.skipOriginIndex = playerIndex
                newState.pendingSkipCount = skipCount
            }
            if newState.rules.lateKadiDeclaration {
                newState.kadiGracePeriodPlayerIndex = playerIndex
            }
            return newState
        }

        // Step 12: last card is a King (reverse).
        if lastCard.isReverseCard {
            let kingCount = cards.filter(\.isReverseCard).count
            if newState.rules.kingStackable && kingCount == 2 {
                // Direction unchanged, same player acts again.
                newState.phase = .playing
                newState.pendingDrawCount = 0
                return newState
            } else {
                newState.direction = newState.direction.flipped
                newState.pendingDrawCount = 0
                advanceTurn(&newState)
                return newState
            }
        }

        // Step 13: plain card.
        newState.pendingDrawCount = 0
        advanceTurn(&newState)
        return newState
    }
}
