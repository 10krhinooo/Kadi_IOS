import XCTest
@testable import KadiEngine

/// Covers `applyAction`/`validateAction` for everything other than `.playCards`
/// (docs/GAME_SPEC.md §G, numbered list).
final class GameEngineActionsTests: XCTestCase {
    private func apply(_ state: GameState, _ action: GameAction, seed: UInt64 = 1) throws -> GameState {
        var rng = SeededRNG(seed: seed)
        return try GameEngine.applyAction(state, action, using: &rng)
    }

    // MARK: - 3. Pass

    func testPassDrawsAndAdvancesTurn() throws {
        let state = makeState(
            players: [makePlayer("a", hand: [card(.five, .hearts)]), makePlayer("b", hand: [])],
            drawPile: [card(.two, .hearts)],
            discardPile: [card(.nine, .clubs)]
        )
        let result = try apply(state, .pass)

        XCTAssertEqual(result.players[0].hand, [card(.five, .hearts), card(.two, .hearts)])
        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testPassDuringQuestionAnswerClearsForcedSuit() throws {
        let state = makeState(
            players: [makePlayer("a", hand: [card(.nine, .clubs)]), makePlayer("b", hand: [])],
            drawPile: [card(.two, .hearts)],
            discardPile: [card(.eight, .hearts)],
            forcedSuit: .hearts,
            phase: .questionAnswer
        )
        let result = try apply(state, .pass)

        XCTAssertNil(result.forcedSuit)
        XCTAssertEqual(result.phase, .playing)
    }

    func testPassCancelsActiveDeclarationWithPenalty() throws {
        var rules = RuleSet()
        rules.kadiPenalty = 1
        let state = makeState(
            players: [makePlayer("a", hand: [card(.five, .hearts)]), makePlayer("b", hand: [])],
            drawPile: [card(.two, .hearts), card(.three, .hearts)],
            discardPile: [card(.nine, .clubs)],
            rules: rules,
            kadiState: KadiState(declaringPlayerIndex: 0)
        )
        let result = try apply(state, .pass)

        XCTAssertNil(result.kadiState)
        XCTAssertEqual(result.players[0].hand.count, 3)
    }

    func testPassInvalidWhenDrawStackActive() {
        let state = makeState(
            players: [makePlayer("a", hand: [card(.five, .hearts)]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .clubs)],
            pendingDrawCount: 2
        )
        XCTAssertEqual(GameEngine.validateAction(state, .pass), "You must respond to the draw stack.")
    }

    func testPassInvalidWhenPassNotAllowedAndValidPlayExists() {
        var rules = RuleSet()
        rules.passAllowed = false
        let state = makeState(
            players: [makePlayer("a", hand: [card(.five, .hearts)]), makePlayer("b", hand: [])],
            discardPile: [card(.five, .clubs)],
            rules: rules
        )
        XCTAssertEqual(GameEngine.validateAction(state, .pass), "You must play a card.")
    }

    // MARK: - 4. DrawStack

    func testDrawStackDrawsPendingCountAndAdvances() throws {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            drawPile: [card(.two, .hearts), card(.three, .hearts), card(.four, .clubs)],
            discardPile: [card(.two, .clubs)],
            pendingDrawCount: 3
        )
        let result = try apply(state, .drawStack)

        XCTAssertEqual(result.players[0].hand.count, 3)
        XCTAssertEqual(result.pendingDrawCount, 0)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testDrawStackCancelsActiveDeclarationWithPenalty() throws {
        var rules = RuleSet()
        rules.kadiPenalty = 1
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            drawPile: [card(.two, .hearts), card(.three, .hearts)],
            discardPile: [card(.two, .clubs)],
            rules: rules,
            pendingDrawCount: 1,
            kadiState: KadiState(declaringPlayerIndex: 0)
        )
        let result = try apply(state, .drawStack)

        XCTAssertNil(result.kadiState)
        // 1 from the stack + 1 kadi penalty.
        XCTAssertEqual(result.players[0].hand.count, 2)
    }

    func testDrawStackInvalidWhenNoStackActive() {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            discardPile: [card(.two, .clubs)]
        )
        XCTAssertEqual(GameEngine.validateAction(state, .drawStack), "There is no draw stack to accept.")
    }

    // MARK: - 5. DeclareKadi

    func testDeclareKadiOutOfTurnLatePath() throws {
        var rules = RuleSet()
        rules.lateKadiDeclaration = true
        let state = makeState(
            players: [makePlayer("a", hand: [card(.five, .hearts)]), makePlayer("b", hand: [card(.nine, .clubs)])],
            discardPile: [card(.king, .clubs)],
            currentPlayerIndex: 0,
            rules: rules,
            kadiGracePeriodPlayerIndex: 1
        )
        let result = try apply(state, .declareKadi(cards: []))

        XCTAssertEqual(result.kadiState, KadiState(declaringPlayerIndex: 1))
        XCTAssertNil(result.kadiGracePeriodPlayerIndex)
        XCTAssertEqual(result.currentPlayerIndex, 0)
    }

    func testDeclareKadiInTurnEmptyCardsAdvancesTurn() throws {
        let state = makeState(
            players: [makePlayer("a", hand: [card(.five, .hearts)]), makePlayer("b", hand: [])],
            discardPile: [card(.king, .clubs)]
        )
        let result = try apply(state, .declareKadi(cards: []))

        XCTAssertEqual(result.kadiState, KadiState(declaringPlayerIndex: 0))
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testDeclareKadiWithWinningCardsFinishesGame() throws {
        let played = card(.seven, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [played]), makePlayer("b", hand: [])],
            discardPile: [card(.seven, .clubs)]
        )
        let result = try apply(state, .declareKadi(cards: [played]))

        XCTAssertEqual(result.phase, .finished)
        XCTAssertEqual(result.winningCards, [played])
    }

    func testDeclareKadiCancelledWhenHandNotEmptyAfterPlay() throws {
        var rules = RuleSet()
        rules.kadiPenalty = 1
        let played = card(.seven, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [played, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            drawPile: [card(.two, .hearts)],
            discardPile: [card(.seven, .clubs)],
            rules: rules
        )
        let result = try apply(state, .declareKadi(cards: [played]))

        XCTAssertNil(result.kadiState)
        XCTAssertEqual(result.players[0].hand.count, 2)
        XCTAssertTrue(result.players[0].hand.contains(card(.two, .hearts)))
    }

    // MARK: - 6. ChooseSuit

    func testChooseSuitSetsForcedSuitAndAdvances() throws {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            discardPile: [card(.ace, .hearts)],
            phase: .suitChoice,
            preSuitChoicePhase: .playing
        )
        let result = try apply(state, .chooseSuit(suit: .diamonds))

        XCTAssertEqual(result.forcedSuit, .diamonds)
        XCTAssertNil(result.preSuitChoicePhase)
        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testChooseSuitInvalidOutsideSuitChoicePhase() {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            discardPile: [card(.ace, .hearts)]
        )
        XCTAssertEqual(GameEngine.validateAction(state, .chooseSuit(suit: .hearts)), "You can't choose a suit right now.")
    }

    // MARK: - 1./7. MakeDemand + RespondToDemand

    func testMakeDemandSetsCardDemandPhaseForNextPlayer() throws {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            discardPile: [card(.ace, .spades)],
            phase: .demandEntry
        )
        let result = try apply(state, .makeDemand(rank: .king, suit: .hearts))

        XCTAssertEqual(result.demandedCard, card(.king, .hearts))
        XCTAssertEqual(result.phase, .cardDemand)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testMakeDemandInvalidOutsideDemandEntry() {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            discardPile: [card(.ace, .spades)]
        )
        XCTAssertEqual(GameEngine.validateAction(state, .makeDemand(rank: .six, suit: .hearts)), "You can't make a demand right now.")
    }

    func testMakeDemandInvalidForJokerRank() {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            discardPile: [card(.ace, .spades)],
            phase: .demandEntry
        )
        XCTAssertEqual(GameEngine.validateAction(state, .makeDemand(rank: .joker, suit: .hearts)), "You can't demand a Joker.")
    }

    func testRespondToDemandWithCardPlaysIt() throws {
        let demanded = card(.six, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [demanded, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.king, .hearts)],
            demandedCard: demanded,
            phase: .cardDemand
        )
        let result = try apply(state, .respondToDemand(card: demanded))

        XCTAssertFalse(result.players[0].hand.contains(demanded))
        XCTAssertNil(result.demandedCard)
        XCTAssertEqual(result.discardPile.last, demanded)
    }

    func testRespondToDemandWithNilDrawsAndAdvances() throws {
        let state = makeState(
            players: [makePlayer("a", hand: [card(.nine, .clubs)]), makePlayer("b", hand: [])],
            drawPile: [card(.two, .hearts)],
            discardPile: [card(.king, .hearts)],
            demandedCard: card(.six, .hearts),
            phase: .cardDemand
        )
        let result = try apply(state, .respondToDemand(card: nil))

        XCTAssertEqual(result.players[0].hand.count, 2)
        XCTAssertNil(result.demandedCard)
        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testRespondToDemandInvalidOutsideCardDemandPhase() {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            discardPile: [card(.king, .hearts)]
        )
        XCTAssertEqual(GameEngine.validateAction(state, .respondToDemand(card: nil)), "There's no demand to respond to.")
    }

    // MARK: - 8. RefuseDraw

    func testRefuseDrawNonSpadeAceAdvancesTurn() throws {
        let ace = card(.ace, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [ace]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .clubs)],
            pendingDrawCount: 2
        )
        let result = try apply(state, .refuseDraw(ace: ace))

        XCTAssertFalse(result.players[0].hand.contains(ace))
        XCTAssertEqual(result.discardPile.last, ace)
        XCTAssertEqual(result.pendingDrawCount, 0)
        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testRefuseDrawAceOfSpadesGoesToSuitChoice() throws {
        let ace = card(.ace, .spades)
        let state = makeState(
            players: [makePlayer("a", hand: [ace]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .clubs)],
            pendingDrawCount: 2
        )
        let result = try apply(state, .refuseDraw(ace: ace))

        XCTAssertEqual(result.pendingDrawCount, 0)
        XCTAssertEqual(result.phase, .suitChoice)
        XCTAssertEqual(result.preSuitChoicePhase, .playing)
        XCTAssertEqual(result.currentPlayerIndex, 0)
    }

    func testRefuseDrawInvalidWhenNoDrawStack() {
        let ace = card(.ace, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [ace]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .clubs)]
        )
        XCTAssertEqual(GameEngine.validateAction(state, .refuseDraw(ace: ace)), "There is no draw stack to refuse.")
    }

    func testRefuseDrawInvalidWhenNotAce() {
        let king = card(.king, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [king]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .clubs)],
            pendingDrawCount: 2
        )
        XCTAssertEqual(GameEngine.validateAction(state, .refuseDraw(ace: king)), "That's not an Ace.")
    }

    // MARK: - 9. RefuseSkip

    func testRefuseSkipShiftsToNextPlayer() throws {
        let jack = card(.jack, .hearts)
        let state = makeState(
            players: [
                makePlayer("a", hand: [jack]),
                makePlayer("b", hand: []),
                makePlayer("c", hand: []),
            ],
            discardPile: [card(.king, .clubs)]
        )
        let result = try apply(state, .refuseSkip(jack: jack))

        XCTAssertFalse(result.players[0].hand.contains(jack))
        XCTAssertEqual(result.discardPile.last, jack)
        // Shift by 1 (cancel skip) + 1 (advanceTurn) = 2.
        XCTAssertEqual(result.currentPlayerIndex, 2)
    }

    func testRefuseSkipInvalidWhenNotAJack() {
        let queen = card(.queen, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [queen]), makePlayer("b", hand: [])],
            discardPile: [card(.king, .clubs)]
        )
        XCTAssertEqual(GameEngine.validateAction(state, .refuseSkip(jack: queen)), "That's not a Jack.")
    }

    // MARK: - 10. RefuseReverse

    func testRefuseReverseKeepsDirectionAndAdvances() throws {
        let king = card(.king, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [king]), makePlayer("b", hand: [])],
            discardPile: [card(.queen, .clubs)]
        )
        let result = try apply(state, .refuseReverse(king: king))

        XCTAssertFalse(result.players[0].hand.contains(king))
        XCTAssertEqual(result.discardPile.last, king)
        XCTAssertEqual(result.direction, .clockwise)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testRefuseReverseInvalidWhenNotAKing() {
        let queen = card(.queen, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [queen]), makePlayer("b", hand: [])],
            discardPile: [card(.king, .clubs)]
        )
        XCTAssertEqual(GameEngine.validateAction(state, .refuseReverse(king: queen)), "That's not a King.")
    }

    // MARK: - 11./12. InterceptSkip / DeclineIntercept (grace path)

    func testInterceptSkipGracePathRedirectsLanding() throws {
        var rules = RuleSet()
        rules.jumpInterceptAllowed = true
        let jack = card(.jack, .hearts)
        let state = makeState(
            players: [
                makePlayer("a", hand: []),
                makePlayer("b", hand: [jack]),
                makePlayer("c", hand: []),
            ],
            discardPile: [card(.nine, .clubs)],
            currentPlayerIndex: 2,
            rules: rules,
            phase: .playing,
            skipInterceptGracePeriodPlayerIndex: 1
        )
        let result = try apply(state, .interceptSkip(jacks: [jack]))

        XCTAssertFalse(result.players[1].hand.contains(jack))
        XCTAssertEqual(result.discardPile.last, jack)
        XCTAssertNil(result.skipInterceptGracePeriodPlayerIndex)
        XCTAssertEqual(result.phase, .playing)
        // graceIndex(1) + step*(newSkipCount(1)+1) = (1 + 2) % 3 = 0
        XCTAssertEqual(result.currentPlayerIndex, 0)
    }

    func testDeclineInterceptGracePathClosesWindow() throws {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: []), makePlayer("c", hand: [])],
            discardPile: [card(.nine, .clubs)],
            currentPlayerIndex: 2,
            phase: .playing,
            pendingSkipCount: 1,
            skipOriginIndex: 0,
            skipInterceptGracePeriodPlayerIndex: 1
        )
        let result = try apply(state, .declineIntercept)

        XCTAssertNil(result.skipInterceptGracePeriodPlayerIndex)
        XCTAssertNil(result.skipOriginIndex)
        XCTAssertEqual(result.pendingSkipCount, 0)
        XCTAssertEqual(result.phase, .playing)
        // resolveSkip recomputes the same landing seat: origin(0) + step*(1+1) = 2.
        XCTAssertEqual(result.currentPlayerIndex, 2)
    }

    // MARK: - 11./12. InterceptSkip / DeclineIntercept (blocking path)

    func testInterceptSkipBlockingContinuesQueue() throws {
        let jack = card(.jack, .hearts)
        let state = makeState(
            players: [
                makePlayer("a", hand: []),
                makePlayer("b", hand: [jack]),
                makePlayer("c", hand: []),
                makePlayer("d", hand: []),
            ],
            discardPile: [card(.nine, .clubs)],
            currentPlayerIndex: 1,
            phase: .skipIntercept,
            skipInterceptQueue: [1, 2],
            pendingSkipCount: 1,
            skipOriginIndex: 0
        )
        let result = try apply(state, .interceptSkip(jacks: [jack]))

        XCTAssertFalse(result.players[1].hand.contains(jack))
        XCTAssertEqual(result.discardPile.last, jack)
        XCTAssertEqual(result.skipInterceptedBy, [1])
        XCTAssertEqual(result.skipInterceptQueue, [2])
        XCTAssertEqual(result.phase, .skipIntercept)
        XCTAssertEqual(result.currentPlayerIndex, 2)
    }

    func testInterceptSkipBlockingResolvesWhenQueueEmpty() throws {
        let jack = card(.jack, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [jack])],
            discardPile: [card(.nine, .clubs)],
            currentPlayerIndex: 1,
            phase: .skipIntercept,
            skipInterceptQueue: [1],
            pendingSkipCount: 1,
            skipOriginIndex: 0,
            skipInterceptedBy: [0]
        )
        let result = try apply(state, .interceptSkip(jacks: [jack]))

        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.skipInterceptQueue, [])
        XCTAssertEqual(result.pendingSkipCount, 0)
        XCTAssertNil(result.skipOriginIndex)
        XCTAssertEqual(result.skipInterceptedBy, [])
        // resolveSkip: origin(0) + step*(1+1) = 0 (mod 2).
        XCTAssertEqual(result.currentPlayerIndex, 0)
    }

    func testDeclineInterceptBlockingAdvancesQueue() throws {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            discardPile: [card(.nine, .clubs)],
            currentPlayerIndex: 1,
            phase: .skipIntercept,
            skipInterceptQueue: [1, 0],
            pendingSkipCount: 1,
            skipOriginIndex: 0
        )
        let result = try apply(state, .declineIntercept)

        XCTAssertEqual(result.skipInterceptQueue, [0])
        XCTAssertEqual(result.currentPlayerIndex, 0)
        XCTAssertEqual(result.phase, .skipIntercept)
    }

    func testDeclineInterceptBlockingResolvesWhenQueueExhausted() throws {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            discardPile: [card(.nine, .clubs)],
            currentPlayerIndex: 1,
            phase: .skipIntercept,
            skipInterceptQueue: [1],
            pendingSkipCount: 1,
            skipOriginIndex: 0
        )
        let result = try apply(state, .declineIntercept)

        XCTAssertEqual(result.phase, .playing)
        XCTAssertEqual(result.skipInterceptQueue, [])
        // resolveSkip: origin(0) + step*(1+1) = 0 (mod 2).
        XCTAssertEqual(result.currentPlayerIndex, 0)
    }

    func testInterceptSkipInvalidWhenNoJacks() {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            discardPile: [card(.nine, .clubs)],
            phase: .skipIntercept
        )
        XCTAssertEqual(GameEngine.validateAction(state, .interceptSkip(jacks: [])), "You must select at least one Jack.")
    }

    func testDeclineInterceptInvalidWhenNothingToDecline() {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            discardPile: [card(.nine, .clubs)]
        )
        XCTAssertEqual(GameEngine.validateAction(state, .declineIntercept), "There's nothing to decline.")
    }

    // MARK: - 13. JumpDraw

    func testJumpDrawRedirectsTwoOrThreeDrawStack() throws {
        var rules = RuleSet()
        rules.drawJumpAllowed = true
        let jack = card(.jack, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [jack]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .hearts)],
            rules: rules,
            pendingDrawCount: 2
        )
        let result = try apply(state, .jumpDraw(jack: jack))

        XCTAssertFalse(result.players[0].hand.contains(jack))
        XCTAssertEqual(result.discardPile.last, jack)
        XCTAssertEqual(result.pendingDrawCount, 2)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testJumpDrawRedirectsJokerDrawWithJackOfDiamonds() throws {
        var rules = RuleSet()
        rules.jokerJumpAllowed = true
        let jack = card(.jack, .diamonds)
        let state = makeState(
            players: [makePlayer("a", hand: [jack]), makePlayer("b", hand: [])],
            discardPile: [card(.joker, .hearts)],
            rules: rules,
            pendingDrawCount: 5
        )
        let result = try apply(state, .jumpDraw(jack: jack))

        XCTAssertEqual(result.pendingDrawCount, 5)
        XCTAssertEqual(result.currentPlayerIndex, 1)
    }

    func testJumpDrawInvalidWhenDrawJumpNotAllowed() {
        let jack = card(.jack, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [jack]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .hearts)],
            pendingDrawCount: 2
        )
        XCTAssertEqual(GameEngine.validateAction(state, .jumpDraw(jack: jack)), "Draw jumps aren't allowed.")
    }

    func testJumpDrawInvalidWhenSuitDoesNotMatchTrigger() {
        var rules = RuleSet()
        rules.drawJumpAllowed = true
        let jack = card(.jack, .clubs)
        let state = makeState(
            players: [makePlayer("a", hand: [jack]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .hearts)],
            rules: rules,
            pendingDrawCount: 2
        )
        XCTAssertEqual(GameEngine.validateAction(state, .jumpDraw(jack: jack)), "That Jack doesn't match the triggering card's suit.")
    }

    func testJumpDrawInvalidWhenNoDrawStack() {
        let jack = card(.jack, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [jack]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .hearts)]
        )
        XCTAssertEqual(GameEngine.validateAction(state, .jumpDraw(jack: jack)), "There is no draw stack to redirect.")
    }
}
