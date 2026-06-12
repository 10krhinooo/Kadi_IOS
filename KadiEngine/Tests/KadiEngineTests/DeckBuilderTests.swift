import XCTest
@testable import KadiEngine

final class DeckBuilderTests: XCTestCase {
    func testBuildDeckWithoutJokers() {
        var rules = RuleSet()
        rules.jokersIncluded = false
        let deck = DeckBuilder.buildDeck(rules: rules)
        XCTAssertEqual(deck.count, 52)
        XCTAssertFalse(deck.contains { $0.isJoker })
    }

    func testBuildDeckWithJokers() {
        let rules = RuleSet()
        let deck = DeckBuilder.buildDeck(rules: rules)
        XCTAssertEqual(deck.count, 54)
        let jokers = deck.filter { $0.isJoker }
        XCTAssertEqual(jokers.count, 2)
        XCTAssertTrue(jokers.contains(PlayingCard(rank: .joker, suit: .hearts)))
        XCTAssertTrue(jokers.contains(PlayingCard(rank: .joker, suit: .clubs)))
    }

    func testBuildDeckMultipleDecks() {
        var rules = RuleSet()
        rules.deckCount = 2
        let deck = DeckBuilder.buildDeck(rules: rules)
        XCTAssertEqual(deck.count, 108)
    }

    func testDealRoundRobin() {
        let rules = RuleSet()
        var deck = DeckBuilder.buildDeck(rules: rules)
        let players = [makePlayer("a", hand: []), makePlayer("b", hand: [])]
        let dealt = DeckBuilder.deal(players: players, deck: &deck, rules: rules)
        XCTAssertEqual(dealt[0].hand.count, rules.cardsPerPlayer)
        XCTAssertEqual(dealt[1].hand.count, rules.cardsPerPlayer)
        XCTAssertEqual(deck.count, 54 - 2 * rules.cardsPerPlayer)
    }

    func testSelectStartingCardFindsValidRank() throws {
        var rng = SeededRNG(seed: 1)
        // Deck with a special card first, then a valid starting card.
        var deck: [PlayingCard] = [card(.ace, .hearts), card(.seven, .spades), card(.two, .clubs)]
        let rules = RuleSet()
        let start = try DeckBuilder.selectStartingCard(deck: &deck, rules: rules, using: &rng)
        XCTAssertEqual(start, card(.seven, .spades))
        // The special card popped before it should be pushed to the back.
        XCTAssertTrue(deck.contains(card(.ace, .hearts)))
        XCTAssertTrue(deck.contains(card(.two, .clubs)))
        XCTAssertFalse(deck.contains(card(.seven, .spades)))
    }

    func testSelectStartingCardThrowsWhenExhausted() {
        var rng = SeededRNG(seed: 2)
        var deck: [PlayingCard] = [card(.ace, .hearts), card(.king, .clubs), card(.joker, .hearts)]
        let rules = RuleSet()
        XCTAssertThrowsError(try DeckBuilder.selectStartingCard(deck: &deck, rules: rules, using: &rng)) { error in
            XCTAssertEqual(error as? DeckBuilder.DeckError, .deckExhausted)
        }
    }

    func testBuildAndDeal() throws {
        var rng = SeededRNG(seed: 42)
        let rules = RuleSet()
        let players = [makePlayer("a", hand: []), makePlayer("b", hand: [])]
        let (dealt, drawPile, discardPile) = try DeckBuilder.buildAndDeal(players: players, rules: rules, using: &rng)
        XCTAssertEqual(dealt[0].hand.count, rules.cardsPerPlayer)
        XCTAssertEqual(dealt[1].hand.count, rules.cardsPerPlayer)
        XCTAssertEqual(discardPile.count, 1)
        XCTAssertEqual(drawPile.count + dealt[0].hand.count + dealt[1].hand.count + discardPile.count, 54)
    }
}
