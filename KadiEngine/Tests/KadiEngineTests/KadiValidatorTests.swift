import XCTest
@testable import KadiEngine

final class KadiValidatorTests: XCTestCase {
    func testIsValidPlayJokerAlwaysTrue() {
        XCTAssertTrue(KadiValidator.isValidPlay(card: card(.joker, .hearts), topCard: card(.king, .clubs), forcedSuit: nil))
    }

    func testIsValidPlayAceAlwaysTrue() {
        XCTAssertTrue(KadiValidator.isValidPlay(card: card(.ace, .spades), topCard: card(.king, .clubs), forcedSuit: .hearts))
    }

    func testIsValidPlayForcedSuit() {
        XCTAssertTrue(KadiValidator.isValidPlay(card: card(.five, .hearts), topCard: card(.king, .clubs), forcedSuit: .hearts))
        XCTAssertFalse(KadiValidator.isValidPlay(card: card(.five, .clubs), topCard: card(.king, .clubs), forcedSuit: .hearts))
    }

    func testIsValidPlayAgainstJokerTopCard() {
        let redJoker = card(.joker, .hearts)
        XCTAssertTrue(KadiValidator.isValidPlay(card: card(.five, .diamonds), topCard: redJoker, forcedSuit: nil))
        XCTAssertFalse(KadiValidator.isValidPlay(card: card(.five, .clubs), topCard: redJoker, forcedSuit: nil))
    }

    func testIsValidPlaySuitOrRankMatch() {
        let top = card(.five, .hearts)
        XCTAssertTrue(KadiValidator.isValidPlay(card: card(.five, .clubs), topCard: top, forcedSuit: nil))
        XCTAssertTrue(KadiValidator.isValidPlay(card: card(.nine, .hearts), topCard: top, forcedSuit: nil))
        XCTAssertFalse(KadiValidator.isValidPlay(card: card(.nine, .clubs), topCard: top, forcedSuit: nil))
    }

    func testIsValidPlayNilTopCard() {
        XCTAssertTrue(KadiValidator.isValidPlay(card: card(.five, .clubs), topCard: nil, forcedSuit: nil))
    }

    func testValidPlaysFiltersHand() {
        let hand = [card(.five, .hearts), card(.nine, .clubs), card(.ace, .spades)]
        let top = card(.five, .clubs)
        let valid = KadiValidator.validPlays(hand: hand, topCard: top, forcedSuit: nil, rules: RuleSet())
        // five-hearts matches rank, nine-clubs matches suit, ace-spades is always playable.
        XCTAssertEqual(Set(valid), Set([card(.five, .hearts), card(.nine, .clubs), card(.ace, .spades)]))
    }

    func testCanDeclareKadiEmptyHandFalse() {
        XCTAssertFalse(KadiValidator.canDeclareKadi(hand: [], topCard: card(.five, .hearts), forcedSuit: nil, rules: RuleSet()))
    }

    func testCanDeclareKadiSingleEndingCard() {
        let hand = [card(.seven, .hearts)]
        let top = card(.seven, .clubs)
        XCTAssertTrue(KadiValidator.canDeclareKadi(hand: hand, topCard: top, forcedSuit: nil, rules: RuleSet()))
    }

    func testCanDeclareKadiFalseIfLastCardCannotEndGame() {
        // Single Jack can't end the game (canEndGame == false for jack).
        let hand = [card(.jack, .hearts)]
        let top = card(.jack, .clubs)
        XCTAssertFalse(KadiValidator.canDeclareKadi(hand: hand, topCard: top, forcedSuit: nil, rules: RuleSet()))
    }

    func testCanDeclareKadiChainThroughQuestionCard() {
        // 8 of hearts forces next suit = hearts; 7 of hearts ends the chain (canEndGame == true).
        let hand = [card(.eight, .hearts), card(.seven, .hearts)]
        let top = card(.eight, .clubs)
        XCTAssertTrue(KadiValidator.canDeclareKadi(hand: hand, topCard: top, forcedSuit: nil, rules: RuleSet()))
    }

    func testCanDeclareKadiChainThroughAce() {
        // Ace of spades is playable on anything; then forces suit choice; nine of diamonds ends on diamonds.
        let hand = [card(.ace, .spades), card(.nine, .diamonds)]
        let top = card(.king, .clubs)
        XCTAssertTrue(KadiValidator.canDeclareKadi(hand: hand, topCard: top, forcedSuit: nil, rules: RuleSet()))
    }
}
