import XCTest
@testable import KadiEngine

final class CpuAgentTests: XCTestCase {
    private func agentRNG(_ seed: UInt64) -> AnyRNG {
        AnyRNG(SeededRNG(seed: seed))
    }

    // MARK: - findWinningChain

    func testFindWinningChainSingleCard() {
        let hand = [card(.seven, .hearts)]
        let chain = CpuAgent.findWinningChain(hand: hand, topCard: card(.seven, .clubs), forcedSuit: nil)
        XCTAssertEqual(chain, [card(.seven, .hearts)])
    }

    func testFindWinningChainNoneWhenLastCardCannotEnd() {
        let hand = [card(.jack, .hearts)]
        let chain = CpuAgent.findWinningChain(hand: hand, topCard: card(.jack, .clubs), forcedSuit: nil)
        XCTAssertNil(chain)
    }

    func testFindWinningChainThroughQuestionCard() {
        let hand = [card(.eight, .hearts), card(.seven, .hearts)]
        let chain = CpuAgent.findWinningChain(hand: hand, topCard: card(.eight, .clubs), forcedSuit: nil)
        XCTAssertEqual(chain, [card(.eight, .hearts), card(.seven, .hearts)])
    }

    // MARK: - EasyCpu

    func testEasyCpuChooseSuitReturnsSomeSuit() {
        let cpu = EasyCpu(rng: agentRNG(1))
        let state = makeState(players: [makePlayer("a", hand: []), makePlayer("b", hand: [])], discardPile: [card(.ace, .spades)], phase: .suitChoice)
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        guard case .chooseSuit = action else {
            return XCTFail("Expected chooseSuit, got \(action)")
        }
    }

    func testEasyCpuRespondToDemandPlaysExactCard() {
        let cpu = EasyCpu(rng: agentRNG(2))
        let demanded = card(.six, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [demanded, card(.two, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.six, .hearts)],
            demandedCard: demanded,
            phase: .cardDemand
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .respondToDemand(card: demanded))
    }

    func testEasyCpuRespondToDemandCountersWithAce() {
        let cpu = EasyCpu(rng: agentRNG(3))
        let state = makeState(
            players: [makePlayer("a", hand: [card(.ace, .clubs), card(.two, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.six, .hearts)],
            demandedCard: card(.six, .hearts),
            phase: .cardDemand
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .respondToDemand(card: card(.ace, .clubs)))
    }

    func testEasyCpuRespondToDemandDrawsWhenNoOptions() {
        let cpu = EasyCpu(rng: agentRNG(4))
        let state = makeState(
            players: [makePlayer("a", hand: [card(.two, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.six, .hearts)],
            demandedCard: card(.six, .hearts),
            phase: .cardDemand
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .respondToDemand(card: nil))
    }

    func testEasyCpuDrawStackResponseRefusesWithAce() {
        let cpu = EasyCpu(rng: agentRNG(5))
        let ace = card(.ace, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [ace, card(.four, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .spades)],
            pendingDrawCount: 2
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .refuseDraw(ace: ace))
    }

    func testEasyCpuDrawStackResponseAcceptsWhenNoOptions() {
        let cpu = EasyCpu(rng: agentRNG(6))
        let state = makeState(
            players: [makePlayer("a", hand: [card(.four, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .spades)],
            pendingDrawCount: 2
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .drawStack)
    }

    func testEasyCpuDeclaresKadiWhenWinningChainExists() {
        let cpu = EasyCpu(rng: agentRNG(7))
        let hand = [card(.seven, .hearts)]
        let state = makeState(
            players: [makePlayer("a", hand: hand), makePlayer("b", hand: [])],
            discardPile: [card(.seven, .clubs)]
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .declareKadi(cards: hand))
    }

    func testEasyCpuPassesWhenNoValidPlay() {
        let cpu = EasyCpu(rng: agentRNG(8))
        let state = makeState(
            players: [makePlayer("a", hand: [card(.nine, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.five, .hearts)]
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .pass)
    }

    func testEasyCpuDeclinesIntercept() {
        let cpu = EasyCpu(rng: agentRNG(9))
        let state = makeState(
            players: [makePlayer("a", hand: [card(.jack, .hearts)]), makePlayer("b", hand: [])],
            discardPile: [card(.jack, .clubs)],
            phase: .skipIntercept
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .declineIntercept)
    }

    // MARK: - MediumCpu

    func testMediumCpuInterceptsWithTwoJacks() {
        let cpu = MediumCpu(rng: agentRNG(10))
        let jacks = [card(.jack, .hearts), card(.jack, .clubs)]
        let state = makeState(
            players: [makePlayer("a", hand: jacks), makePlayer("b", hand: [])],
            discardPile: [card(.jack, .spades)],
            phase: .skipIntercept
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .interceptSkip(jacks: jacks))
    }

    func testMediumCpuDeclinesInterceptWithOneJack() {
        let cpu = MediumCpu(rng: agentRNG(11))
        let state = makeState(
            players: [makePlayer("a", hand: [card(.jack, .hearts)]), makePlayer("b", hand: [])],
            discardPile: [card(.jack, .spades)],
            phase: .skipIntercept
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .declineIntercept)
    }

    func testMediumCpuMakeDemandReturnsRankSix() {
        let cpu = MediumCpu(rng: agentRNG(12))
        let state = makeState(
            players: [makePlayer("a", hand: [card(.ace, .spades)]), makePlayer("b", hand: [])],
            discardPile: [card(.ace, .spades)],
            phase: .demandEntry
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        guard case .makeDemand(let rank, _) = action else {
            return XCTFail("Expected makeDemand, got \(action)")
        }
        XCTAssertEqual(rank, .six)
    }

    func testMediumCpuNormalPlayPrefersDrawCard() {
        let cpu = MediumCpu(rng: agentRNG(13))
        let two = card(.two, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [two, card(.nine, .clubs)]), makePlayer("b", hand: [])],
            discardPile: [card(.two, .clubs)]
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .playCards(cards: [two]))
    }

    // MARK: - HardCpu

    func testHardCpuRecordPlayedAffectsDemand() {
        let cpu = HardCpu(rng: agentRNG(14))
        // Record several sixes as already played so demand should avoid rank six.
        for _ in 0..<3 {
            cpu.recordPlayed(card(.six, .hearts))
        }
        let state = makeState(
            players: [makePlayer("a", hand: [card(.ace, .spades)]), makePlayer("b", hand: [])],
            discardPile: [card(.ace, .spades)],
            phase: .demandEntry
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        guard case .makeDemand(let rank, _) = action else {
            return XCTFail("Expected makeDemand, got \(action)")
        }
        XCTAssertNotEqual(rank, .six)
    }

    func testHardCpuInterceptsWhenOpponentLow() {
        let cpu = HardCpu(rng: agentRNG(15))
        let jack = card(.jack, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [jack]), makePlayer("b", hand: [card(.two, .clubs)])],
            discardPile: [card(.jack, .spades)],
            phase: .skipIntercept
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .interceptSkip(jacks: [jack]))
    }

    func testHardCpuAnswerQuestionPrefersNonSpecial() {
        let cpu = HardCpu(rng: agentRNG(16))
        let nonSpecial = card(.five, .hearts)
        let special = card(.ace, .hearts)
        let state = makeState(
            players: [makePlayer("a", hand: [nonSpecial, special]), makePlayer("b", hand: [])],
            discardPile: [card(.eight, .hearts)],
            forcedSuit: .hearts,
            phase: .questionAnswer
        )
        let action = cpu.chooseAction(state: state, playerIndex: 0)
        XCTAssertEqual(action, .playCards(cards: [nonSpecial]))
    }

    // MARK: - AdaptiveCpu

    func testAdaptiveCpuStartsAsEasy() {
        let cpu = AdaptiveCpu(rng: agentRNG(17))
        XCTAssertTrue(cpu.activeAgent is EasyCpu)
    }

    func testAdaptiveCpuSwitchesToHardOnHighWinRate() {
        let cpu = AdaptiveCpu(rng: agentRNG(18))
        cpu.recordRoundResult(playerWon: true)
        cpu.recordRoundResult(playerWon: true)
        cpu.recordRoundResult(playerWon: true)
        XCTAssertTrue(cpu.activeAgent is HardCpu)
    }

    func testAdaptiveCpuStaysEasyAtOneThirdWinRate() {
        // 1/3 ≈ 0.33 is not > 0.4, so it stays Easy (Medium is unreachable from a
        // 3-round window: possible rates are 0, 1/3, 2/3, 1).
        let cpu = AdaptiveCpu(rng: agentRNG(19))
        cpu.recordRoundResult(playerWon: true)
        cpu.recordRoundResult(playerWon: false)
        cpu.recordRoundResult(playerWon: false)
        XCTAssertTrue(cpu.activeAgent is EasyCpu)
    }

    func testAdaptiveCpuSwitchesToEasyOnLowWinRate() {
        let cpu = AdaptiveCpu(rng: agentRNG(20))
        cpu.recordRoundResult(playerWon: true)
        cpu.recordRoundResult(playerWon: true)
        cpu.recordRoundResult(playerWon: true)
        XCTAssertTrue(cpu.activeAgent is HardCpu)
        cpu.recordRoundResult(playerWon: false)
        cpu.recordRoundResult(playerWon: false)
        cpu.recordRoundResult(playerWon: false)
        XCTAssertTrue(cpu.activeAgent is EasyCpu)
    }

    func testAdaptiveCpuDoesNotSwitchBeforeThreeRounds() {
        let cpu = AdaptiveCpu(rng: agentRNG(21))
        cpu.recordRoundResult(playerWon: true)
        cpu.recordRoundResult(playerWon: true)
        XCTAssertTrue(cpu.activeAgent is EasyCpu)
    }
}
