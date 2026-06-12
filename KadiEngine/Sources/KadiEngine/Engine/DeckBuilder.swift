import Foundation

/// Deck construction, dealing, and starting-card selection. Pure/stateless — see
/// docs/GAME_SPEC.md §F.
public enum DeckBuilder {
    /// Thrown by `selectStartingCard` if the deck is exhausted before a valid starting card
    /// is found.
    public enum DeckError: Error, Equatable, Sendable {
        case deckExhausted
    }

    /// Build `rules.deckCount` standard 52-card decks (all 4 suits × ranks two..ace). If
    /// `rules.jokersIncluded`, add 2 Jokers per deck (Red Joker = `{joker, hearts}`, Black
    /// Joker = `{joker, clubs}`). Unshuffled.
    public static func buildDeck(rules: RuleSet) -> [PlayingCard] {
        var cards: [PlayingCard] = []
        for _ in 0..<rules.deckCount {
            for suit in Suit.allCases {
                for rank in Rank.allCases where rank != .joker {
                    cards.append(PlayingCard(rank: rank, suit: suit))
                }
            }
            if rules.jokersIncluded {
                cards.append(PlayingCard(rank: .joker, suit: .hearts))
                cards.append(PlayingCard(rank: .joker, suit: .clubs))
            }
        }
        return cards
    }

    /// Deal `rules.cardsPerPlayer` rounds, one card to each player per round, in player order,
    /// removing cards from the front of `deck`.
    public static func deal(players: [Player], deck: inout [PlayingCard], rules: RuleSet) -> [Player] {
        var dealt = players
        for _ in 0..<rules.cardsPerPlayer {
            for i in dealt.indices {
                guard !deck.isEmpty else { break }
                dealt[i].hand.append(deck.removeFirst())
            }
        }
        return dealt
    }

    /// Ranks that are valid as a *starting* card (the only ranks with `canEndGame == true`
    /// minus King).
    private static let startingRanks: Set<Rank> = [.four, .five, .six, .seven, .eight, .nine, .ten]

    /// Pop cards off the front of `deck` until one with a rank in `startingRanks` is found.
    /// If a popped card is "special" (not in `startingRanks`), push it to the back of the
    /// remaining deck; if `rules.startingCardReshuffle`, reshuffle the whole remaining deck
    /// before continuing. Throws `DeckError.deckExhausted` if no valid starting card can be
    /// found. Returns the starting card (already removed from `deck`).
    public static func selectStartingCard(
        deck: inout [PlayingCard],
        rules: RuleSet,
        using rng: inout some RandomNumberGenerator
    ) throws -> PlayingCard {
        // Safety bound: in a normal deck this resolves in a handful of iterations. Guard
        // against pathological custom rule sets (e.g. a deck with no four..ten cards) that
        // would otherwise spin forever re-shuffling the same cards.
        let maxIterations = max(deck.count * 4, 1000)
        var iterations = 0
        while true {
            iterations += 1
            if deck.isEmpty || iterations > maxIterations {
                throw DeckError.deckExhausted
            }
            let card = deck.removeFirst()
            if startingRanks.contains(card.rank) {
                return card
            }
            deck.append(card)
            if rules.startingCardReshuffle {
                deck.shuffle(using: &rng)
            }
        }
    }

    /// Build a shuffled deck, deal hands, and select a starting card. Returns the dealt
    /// players, the remaining draw pile, and the discard pile (containing only the starting
    /// card).
    public static func buildAndDeal(
        players: [Player],
        rules: RuleSet,
        using rng: inout some RandomNumberGenerator
    ) throws -> (players: [Player], drawPile: [PlayingCard], discardPile: [PlayingCard]) {
        var deck = buildDeck(rules: rules)
        deck.shuffle(using: &rng)
        let dealt = deal(players: players, deck: &deck, rules: rules)
        let startCard = try selectStartingCard(deck: &deck, rules: rules, using: &rng)
        return (dealt, deck, [startCard])
    }
}
