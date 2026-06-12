import Foundation

/// Rule-specific legality checks independent of the engine's turn-application logic — used
/// by CPUs and UI to check "can I declare/win right now?" (see docs/GAME_SPEC.md §H).
public enum KadiValidator {
    /// Whether `card` may legally be played on top of `topCard`, given an optional
    /// `forcedSuit` constraint. Shared by `GameEngine` and `KadiValidator` (see
    /// docs/GAME_SPEC.md §G "isValidPlay").
    ///
    /// - Joker → always true.
    /// - Ace → always true.
    /// - Else if `forcedSuit != nil` → `card.suit == forcedSuit`.
    /// - Else if `topCard.isJoker` → `card.isRed == topCard.isRed`.
    /// - Else → `card.suit == topCard.suit || card.rank == topCard.rank`.
    public static func isValidPlay(card: PlayingCard, topCard: PlayingCard?, forcedSuit: Suit?) -> Bool {
        if card.isJoker { return true }
        if card.isAce { return true }
        if let forcedSuit {
            return card.suit == forcedSuit
        }
        guard let topCard else { return true }
        if topCard.isJoker {
            return card.isRed == topCard.isRed
        }
        return card.suit == topCard.suit || card.rank == topCard.rank
    }

    /// All cards in `hand` that are individually `isValidPlay` against `topCard`/`forcedSuit`.
    public static func validPlays(
        hand: [PlayingCard],
        topCard: PlayingCard?,
        forcedSuit: Suit?,
        rules: RuleSet
    ) -> [PlayingCard] {
        hand.filter { isValidPlay(card: $0, topCard: topCard, forcedSuit: forcedSuit) }
    }

    /// Whether the entire `hand` can be played as one legal chain ending on a card with
    /// `canEndGame == true`, via recursive DFS over all orderings (see docs/GAME_SPEC.md §H).
    public static func canDeclareKadi(
        hand: [PlayingCard],
        topCard: PlayingCard?,
        forcedSuit: Suit?,
        rules: RuleSet
    ) -> Bool {
        if hand.isEmpty { return false }
        return canPlayAll(hand: hand, topCard: topCard, forcedSuit: forcedSuit)
    }

    /// Returns true iff some ordering of `hand` plays every card as a legal chain (starting
    /// against `topCard`/`forcedSuit`) such that the last card played has `canEndGame ==
    /// true`.
    private static func canPlayAll(hand: [PlayingCard], topCard: PlayingCard?, forcedSuit: Suit?) -> Bool {
        for (index, card) in hand.enumerated() {
            guard isValidPlay(card: card, topCard: topCard, forcedSuit: forcedSuit) else { continue }

            var remaining = hand
            remaining.remove(at: index)

            if remaining.isEmpty {
                if card.canEndGame {
                    return true
                }
                continue
            }

            if card.isQuestionCard {
                if canPlayAll(hand: remaining, topCard: card, forcedSuit: card.suit) {
                    return true
                }
            } else if card.isAce {
                for suit in Suit.allCases {
                    if canPlayAll(hand: remaining, topCard: card, forcedSuit: suit) {
                        return true
                    }
                }
            } else {
                if canPlayAll(hand: remaining, topCard: card, forcedSuit: nil) {
                    return true
                }
            }
        }
        return false
    }
}
