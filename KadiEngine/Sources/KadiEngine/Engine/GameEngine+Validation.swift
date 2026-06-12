import Foundation

/// `validateAction` rules per phase/action — see docs/GAME_SPEC.md §G (numbered list).
extension GameEngine {
    // MARK: - 2. PlayCards

    static func validatePlayCards(_ state: GameState, cards: [PlayingCard]) -> String? {
        if cards.isEmpty {
            return "No cards selected."
        }
        if state.phase == .suitChoice {
            return "Choose a suit first."
        }
        if state.phase == .demandEntry {
            return "Make a demand first."
        }

        if state.phase == .cardDemand {
            let isAceCounter = cards.count == 1 && cards[0].isAce
            let isExactDemand = state.demandedCard.map { cards == [$0] } ?? false
            if !isAceCounter && !isExactDemand {
                return "You must play the demanded card or counter with an Ace."
            }
        }

        if !handContains(state.currentPlayer.hand, cards) {
            return "You don't have those cards."
        }

        if state.phase == .questionAnswer {
            if state.forcedSuit == nil || cards.first?.suit != state.forcedSuit {
                return "You must play a card matching the forced suit, or pass."
            }
        }

        if state.isDrawStackActive {
            for card in cards {
                if !(isRuledDrawCard(card, rules: state.rules) || card.isAce) {
                    return "You must play a draw card or counter with an Ace."
                }
                if let top = state.topCard, top.isJoker, card.isDrawCard, card.isRed != top.isRed {
                    return "That card's color doesn't match the Joker."
                }
            }
        }

        if state.phase != .questionAnswer, let firstCard = cards.first {
            if !isValidPlay(firstCard, state: state) {
                return "That card can't be played on the current top card."
            }
        }

        if cards.count > 1 {
            if state.isDrawStackActive {
                let rank = cards[0].rank
                if !cards.allSatisfy({ $0.rank == rank }) {
                    return "All cards must be the same rank."
                }
            } else {
                for i in 1..<cards.count {
                    let prev = cards[i - 1]
                    let cur = cards[i]
                    if prev.suit != cur.suit && prev.rank != cur.rank {
                        return "Cards must form a valid chain by suit or rank."
                    }
                }
            }
        }

        return nil
    }

    // MARK: - 3. Pass

    static func validatePass(_ state: GameState) -> String? {
        if state.phase == .questionAnswer {
            return nil
        }
        if state.phase != .playing {
            return "You can't pass right now."
        }
        if state.isDrawStackActive {
            return "You must respond to the draw stack."
        }
        if !state.rules.passAllowed {
            let valid = KadiValidator.validPlays(
                hand: state.currentPlayer.hand,
                topCard: state.topCard,
                forcedSuit: state.forcedSuit,
                rules: state.rules
            )
            if !valid.isEmpty {
                return "You must play a card."
            }
        }
        return nil
    }

    // MARK: - 4. DrawStack

    static func validateDrawStack(_ state: GameState) -> String? {
        state.isDrawStackActive ? nil : "There is no draw stack to accept."
    }

    // MARK: - 5. DeclareKadi

    static func validateDeclareKadi(_ state: GameState, cards: [PlayingCard]) -> String? {
        // Out-of-turn (late) path.
        if state.rules.lateKadiDeclaration,
           let graceIndex = state.kadiGracePeriodPlayerIndex,
           graceIndex != state.currentPlayerIndex,
           cards.isEmpty {
            return nil
        }

        // In-turn path.
        if state.phase != .playing {
            return "You can't declare Kadi right now."
        }
        if !cards.isEmpty {
            return validatePlayCards(state, cards: cards)
        }
        return nil
    }

    // MARK: - 6. ChooseSuit

    static func validateChooseSuit(_ state: GameState) -> String? {
        state.phase == .suitChoice ? nil : "You can't choose a suit right now."
    }

    // MARK: - 1. MakeDemand

    static func validateMakeDemand(_ state: GameState, rank: Rank) -> String? {
        guard state.phase == .demandEntry else { return "You can't make a demand right now." }
        if rank == .joker { return "You can't demand a Joker." }
        return nil
    }

    // MARK: - 7. RespondToDemand

    static func validateRespondToDemand(_ state: GameState, card: PlayingCard?) -> String? {
        guard state.phase == .cardDemand else { return "There's no demand to respond to." }
        if let card, !state.currentPlayer.hand.contains(card) {
            return "You don't have that card."
        }
        return nil
    }

    // MARK: - 8. RefuseDraw

    static func validateRefuseDraw(_ state: GameState, ace: PlayingCard) -> String? {
        guard state.isDrawStackActive else { return "There is no draw stack to refuse." }
        guard state.currentPlayer.hand.contains(ace) else { return "You don't have that card." }
        guard ace.isAce else { return "That's not an Ace." }
        return nil
    }

    // MARK: - 9. RefuseSkip

    static func validateRefuseSkip(_ state: GameState, jack: PlayingCard) -> String? {
        guard state.currentPlayer.hand.contains(jack) else { return "You don't have that card." }
        guard jack.isSkipCard else { return "That's not a Jack." }
        return nil
    }

    // MARK: - 10. RefuseReverse

    static func validateRefuseReverse(_ state: GameState, king: PlayingCard) -> String? {
        guard state.currentPlayer.hand.contains(king) else { return "You don't have that card." }
        guard king.isReverseCard else { return "That's not a King." }
        return nil
    }

    // MARK: - 11. InterceptSkip

    static func validateInterceptSkip(_ state: GameState, jacks: [PlayingCard]) -> String? {
        if jacks.isEmpty { return "You must select at least one Jack." }
        guard jacks.allSatisfy({ $0.isSkipCard }) else { return "All cards must be Jacks." }

        if let graceIndex = state.skipInterceptGracePeriodPlayerIndex {
            guard handContains(state.players[graceIndex].hand, jacks) else {
                return "You don't have those cards."
            }
            return nil
        }

        if state.phase == .skipIntercept {
            guard handContains(state.currentPlayer.hand, jacks) else {
                return "You don't have those cards."
            }
            return nil
        }

        return "There's no skip to intercept."
    }

    // MARK: - 12. DeclineIntercept

    static func validateDeclineIntercept(_ state: GameState) -> String? {
        if state.phase == .skipIntercept || state.skipInterceptGracePeriodPlayerIndex != nil {
            return nil
        }
        return "There's nothing to decline."
    }

    // MARK: - 13. JumpDraw

    static func validateJumpDraw(_ state: GameState, jack: PlayingCard) -> String? {
        guard state.isDrawStackActive else { return "There is no draw stack to redirect." }
        guard state.currentPlayer.hand.contains(jack) else { return "You don't have that card." }
        guard jack.isSkipCard else { return "That's not a Jack." }

        guard let trigger = findTriggeringDrawCard(state) else {
            return "No triggering draw card found."
        }
        if trigger.isJoker {
            guard state.rules.jokerJumpAllowed else { return "Joker jumps aren't allowed." }
            guard jack.suit == .diamonds else { return "You must use the Jack of Diamonds." }
        } else {
            guard state.rules.drawJumpAllowed else { return "Draw jumps aren't allowed." }
            guard jack.suit == trigger.suit else { return "That Jack doesn't match the triggering card's suit." }
        }
        return nil
    }
}
