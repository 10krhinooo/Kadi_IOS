import XCTest
@testable import KadiEngine

/// Covers `applyPlayCardsCore`'s 13 numbered steps (docs/GAME_SPEC.md §G.2) via the
/// `.playCards` action.
final class GameEnginePlayCardsTests: XCTestCase {
    private func apply(_ state: GameState, _ action: GameAction, seed: UInt64 = 1) throws -> GameState {
        var rng = SeededRNG(seed: seed)
        return try GameEngine.applyAction(state, action, using: &rng)
    }

    // MARK: - Step 1: removal + clearing forcedSuit/demandedCard, Step 13: plain card

    func testStep1And13_PlainCardClearsForcedSuitAndAdvances() throws {
        let played = card(.five, .hearts)
        let state = makeState(
            players: [
                makePlayer("a", hand: [played, card(.nine, .clubs)]),
                makePlayer("b", hand: []),
            ],
            discardPile: [card(.five, .clubs)],
            forcedSuit: .hearts,
            demandedCard: card(.six, .hearts)
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.players[0].hand, [card(.nine, .clubs)])
        XCTAssertEqual(result.discardPile, [card(.five, .clubs), played])
        XCTAssertNil(result.forcedSuit)
        XCTAssertNil(result.demandedCard)
        XCTAssertEqual(result.pendingDrawCount, 0)
        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    // MARK: - Step 2: win check

    func testStep2_HandEmptyWithActiveDeclarationFinishesGame() throws {
        let played = card(.five, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [played]), makePlayer("b", hand: [])],
            discardPile: [card(.five, .clubs)],
            kadiState: KadiState(declaringPlayerIndex: 0)
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.phase, .finished)
        XCTAssertEqual(result.pendingDrawCount, 0)
        XCTAssertEqual(result.winningCards, [played])
        XCTAssertTrue(result.players[0].hand.isEmpty)
    }

    func testStep2_HandEmptyWithoutDeclarationAppliesFalseKadiPenalty() throws {
        let played = card(.five, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [played]), makePlayer("b", hand: [])],
            drawPile: [card(.two, .hearts), card(.three, .hearts), card(.four, .clubs)],
            discardPile: [card(.five, .clubs)]
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.players[0].hand.count, 2)
        XCTAssertEqual(result.currentPlayerIndex, 1)
        XCTAssertNil(result.kadiState)
    }

    // MARK: - Step 3: cancel active declaration on non-empty hand

    func testStep3_CancelsActiveDeclarationAndAppliesKadiPenalty() throws {
        let played = card(.five, .hearts)
        var rules = RuleSet()
        rules.kadiPenalty = 1
        let state = makeState(
            players: [makePlayer("a", hand: [played, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            drawPile: [card(.two, .hearts)],
            discardPile: [card(.five, .clubs)],
            rules: rules,
            kadiState: KadiState(declaringPlayerIndex: 0)
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertNil(result.kadiState)
        // Remaining card (nine clubs) plus 1 penalty draw.
        XCTAssertEqual(result.players[0].hand.count, 2)
        XCTAssertTrue(result.players[0].hand.contains(card(.two, .hearts)))
    }

    // MARK: - Step 4: draw-card stacking

    func testStep4_OpensNewDrawStack() throws {
        let played = card(.two, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [played, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .clubs)]
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.pendingDrawCount, 2)
        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testStep4_StacksOntoActiveDrawStack() throws {
        let played = card(.two, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [played, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .clubs)],
            pendingDrawCount: 2
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.pendingDrawCount, 4)
    }

    func testStep4_RespectsDrawStackCap() throws {
        let played = card(.two, .hearts)
        var rules = RuleSet()
        rules.drawStackCap = 3
        let state = makeState(
            players: [makePlayer("a", hand: [played, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .clubs)],
            rules: rules,
            pendingDrawCount: 2
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.pendingDrawCount, 3)
    }

    // MARK: - Step 5: question card

    func testStep5_QuestionCardOpensQuestionAnswerPhase() throws {
        let played = card(.eight, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [played, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.eight, .clubs)]
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.phase, .questionAnswer)
        XCTAssertEqual(result.forcedSuit, .hearts)
        XCTAssertEqual(result.pendingDrawCount, 0)
        // Same player acts again.
        XCTAssertEqual(result.currentPlayerIndex, 0)
    }

    // MARK: - Step 6: Ace counters a card demand

    func testStep6_AceCountersCardDemand() throws {
        let played = card(.ace, .clubs)
        let state = makeState(
            players: [makePlayer("a", hand: [played, card(.nine, .spades)]), makePlayer("b", hand: [])],
            discardPile: [card(.six, .hearts)],
            demandedCard: card(.six, .hearts),
            phase: .cardDemand
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.forcedSuit, .hearts)
        XCTAssertNil(result.demandedCard)
        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    // MARK: - Step 7: Ace refusal during an active draw stack

    func testStep7_NonSpadeAceRefusalAdvancesTurn() throws {
        let played = card(.ace, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [played, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .clubs)],
            pendingDrawCount: 2
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.pendingDrawCount, 0)
        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testStep7_AceOfSpadesRefusalGoesToSuitChoice() throws {
        let played = card(.ace, .spades)
        let state = makeState(
            players: [makePlayer("a", hand: [played, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .clubs)],
            pendingDrawCount: 2
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.pendingDrawCount, 0)
        XCTAssertEqual(result.phase, .suitChoice)
        XCTAssertEqual(result.preSuitChoicePhase, .playing)
        XCTAssertEqual(result.currentPlayerIndex, 0)
    }

    // MARK: - Step 8: 2+ Aces -> demandEntry

    func testStep8_TwoAcesGoToDemandEntry() throws {
        let cards = [card(.ace, .hearts), card(.ace, .clubs)]
        let state = makeState(
            players: [makePlayer("a", hand: cards + [card(.nine, .spades)]), makePlayer("b", hand: [])],
            discardPile: [card(.king, .clubs)]
        )
        let result = try apply(state, .playCards(cards: cards))

        XCTAssertEqual(result.phase, .demandEntry)
        XCTAssertEqual(result.pendingDrawCount, 0)
        XCTAssertEqual(result.currentPlayerIndex, 0)
    }

    // MARK: - Step 9: single A♠️ with aceOfSpadesEnabled -> demandEntry

    func testStep9_SingleAceOfSpadesGoesToDemandEntry() throws {
        let played = card(.ace, .spades)
        let state = makeState(
            players: [makePlayer("a", hand: [played, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.king, .clubs)]
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.phase, .demandEntry)
        XCTAssertEqual(result.pendingDrawCount, 0)
    }

    // MARK: - Step 10: any other single Ace -> suitChoice

    func testStep10_OtherSingleAceGoesToSuitChoice() throws {
        let played = card(.ace, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [played, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.king, .clubs)]
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.phase, .suitChoice)
        XCTAssertEqual(result.preSuitChoicePhase, .playing)
        XCTAssertEqual(result.pendingDrawCount, 0)
    }

    // MARK: - Step 11: Jack skip

    func testStep11_SingleJackSkipsOnePlayer() throws {
        let played = card(.jack, .hearts)
        let state = makeState(
            players: [
                makePlayer("a", hand: [played, card(.nine, .clubs)]),
                makePlayer("b", hand: []),
                makePlayer("c", hand: []),
            ],
            discardPile: [card(.jack, .clubs)]
        )
        let result = try apply(state, .playCards(cards: [played]))

        // n=3, step=+1, skipCount=1 -> currentPlayerIndex = (0 + 1*2) % 3 = 2
        XCTAssertEqual(result.currentPlayerIndex, 2)
        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.pendingDrawCount, 0)
        XCTAssertNil(result.skipInterceptGracePeriodPlayerIndex)
        XCTAssertNil(result.kadiGracePeriodPlayerIndex)
    }

    func testStep11_StackedJacksSkipMultiplePlayers() throws {
        let cards = [card(.jack, .hearts), card(.jack, .clubs)]
        let state = makeState(
            players: [
                makePlayer("a", hand: cards + [card(.nine, .spades)]),
                makePlayer("b", hand: []),
                makePlayer("c", hand: []),
            ],
            discardPile: [card(.jack, .spades)]
        )
        let result = try apply(state, .playCards(cards: cards))

        // n=3, step=+1, skipCount=2 -> currentPlayerIndex = (0 + 1*3) % 3 = 0
        XCTAssertEqual(result.currentPlayerIndex, 0)
    }

    func testStep11_JumpInterceptAllowedOpensGraceWindow() throws {
        let played = card(.jack, .hearts)
        var rules = RuleSet()
        rules.jumpInterceptAllowed = true
        let state = makeState(
            players: [
                makePlayer("a", hand: [played, card(.nine, .clubs)]),
                makePlayer("b", hand: []),
                makePlayer("c", hand: []),
            ],
            discardPile: [card(.jack, .clubs)],
            rules: rules
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.skipInterceptGracePeriodPlayerIndex, 1)
        XCTAssertEqual(result.skipOriginIndex, 0)
        XCTAssertEqual(result.pendingSkipCount, 1)
    }

    func testStep11_LateKadiDeclarationOpensGraceWindowForJackPlayer() throws {
        let played = card(.jack, .hearts)
        var rules = RuleSet()
        rules.lateKadiDeclaration = true
        let state = makeState(
            players: [
                makePlayer("a", hand: [played, card(.nine, .clubs)]),
                makePlayer("b", hand: []),
                makePlayer("c", hand: []),
            ],
            discardPile: [card(.jack, .clubs)],
            rules: rules
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.kadiGracePeriodPlayerIndex, 0)
    }

    // MARK: - Step 12: King reverse

    func testStep12_TwoKingsCancelReversalAndRepeatTurn() throws {
        let cards = [card(.king, .hearts), card(.king, .clubs)]
        let state = makeState(
            players: [makePlayer("a", hand: cards + [card(.nine, .spades)]), makePlayer("b", hand: [])],
            discardPile: [card(.king, .spades)]
        )
        let result = try apply(state, .playCards(cards: cards))

        XCTAssertEqual(result.direction, .clockwise)
        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.pendingDrawCount, 0)
        XCTAssertEqual(result.currentPlayerIndex, 0)
    }

    func testStep12_SingleKingFlipsDirectionAndAdvances() throws {
        let played = card(.king, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [played, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.king, .spades)]
        )
        let result = try apply(state, .playCards(cards: [played]))

        XCTAssertEqual(result.direction, .anticlockwise)
        XCTAssertEqual(result.pendingDrawCount, 0)
        // n=2, new direction step = -1 -> currentPlayerIndex = ((0 - 1) % 2 + 2) % 2 = 1
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testStep12_KingStackableFalseAlwaysFlips() throws {
        let cards = [card(.king, .hearts), card(.king, .clubs)]
        var rules = RuleSet()
        rules.kingStackable = false
        let state = makeState(
            players: [makePlayer("a", hand: cards + [card(.nine, .spades)]), makePlayer("b", hand: [])],
            discardPile: [card(.king, .spades)],
            rules: rules
        )
        let result = try apply(state, .playCards(cards: cards))

        XCTAssertEqual(result.direction, .anticlockwise)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }
}
