//
//  SoloGameViewModel.swift
//  kadi
//

import Combine
import Foundation
import SwiftUI
import KadiEngine

enum CpuDifficulty: String, CaseIterable, Identifiable {
    case easy, medium, hard, adaptive

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    func makeAgent() -> CpuAgent {
        switch self {
        case .easy: return EasyCpu()
        case .medium: return MediumCpu()
        case .hard: return HardCpu()
        case .adaptive: return AdaptiveCpu()
        }
    }
}

/// Drives a single-player game against one or more `CpuAgent` opponents using
/// `GameEngine`. The human player is always `players[0]`.
@MainActor
final class SoloGameViewModel: ObservableObject {
    @Published private(set) var state: GameState
    @Published var selectedCardIndices: Set<Int> = []
    @Published var errorMessage: String?
    @Published var isCpuThinking: Bool = false

    let humanIndex = 0
    private let opponentCount: Int
    private let difficulty: CpuDifficulty
    private let rules: RuleSet
    private var cpuAgents: [Int: CpuAgent] = [:]
    private var rng = AnyRNG()
    private var didRecordRoundResult = false

    init(opponentCount: Int, difficulty: CpuDifficulty, rules: RuleSet = RuleSet()) {
        self.opponentCount = opponentCount
        self.difficulty = difficulty
        self.rules = rules
        var players: [Player] = [Player(id: "human", name: "You", hand: [], isHuman: true)]
        for i in 0..<opponentCount {
            players.append(Player(id: "cpu\(i)", name: "CPU \(i + 1)", hand: [], isHuman: false))
        }
        var rng = AnyRNG()
        // swiftlint:disable:next force_try
        self.state = try! GameEngine.createGame(players: players, rules: rules, using: &rng)
        self.rng = rng
        for i in 1...max(opponentCount, 1) where i <= opponentCount {
            cpuAgents[i] = difficulty.makeAgent()
        }
        scheduleCpuTurnIfNeeded()
    }

    /// Starts a fresh game with the same configuration (used by "Play Again").
    func reset() {
        selectedCardIndices = []
        errorMessage = nil
        isCpuThinking = false
        didRecordRoundResult = false

        var players: [Player] = [Player(id: "human", name: "You", hand: [], isHuman: true)]
        for i in 0..<opponentCount {
            players.append(Player(id: "cpu\(i)", name: "CPU \(i + 1)", hand: [], isHuman: false))
        }
        // swiftlint:disable:next force_try
        state = try! GameEngine.createGame(players: players, rules: rules, using: &rng)

        cpuAgents.removeAll()
        for i in 1...max(opponentCount, 1) where i <= opponentCount {
            cpuAgents[i] = difficulty.makeAgent()
        }
        scheduleCpuTurnIfNeeded()
    }

    // MARK: - Derived state

    var humanPlayer: Player { state.players[humanIndex] }

    var playableCards: [PlayingCard] {
        KadiValidator.validPlays(
            hand: humanPlayer.hand,
            topCard: state.topCard,
            forcedSuit: state.forcedSuit,
            rules: state.rules
        )
    }

    var playableIndices: Set<Int> {
        let playable = playableCards
        var result: Set<Int> = []
        for (index, card) in humanPlayer.hand.enumerated() where playable.contains(card) {
            result.insert(index)
        }
        return result
    }

    var canDeclareKadi: Bool {
        KadiValidator.canDeclareKadi(
            hand: humanPlayer.hand,
            topCard: state.topCard,
            forcedSuit: state.forcedSuit,
            rules: state.rules
        )
    }

    var isHumanTurn: Bool {
        state.currentPlayerIndex == humanIndex
    }

    var winner: Player? {
        guard state.phase == .finished else { return nil }
        return state.players.first { $0.hand.isEmpty }
    }

    // MARK: - Human actions

    func toggleSelection(at index: Int) {
        if selectedCardIndices.contains(index) {
            selectedCardIndices.remove(index)
        } else {
            selectedCardIndices.insert(index)
        }
    }

    func confirmPlaySelected() {
        perform(.playCards(cards: selectedCards()))
    }

    func pass() {
        perform(.pass)
    }

    func drawStack() {
        perform(.drawStack)
    }

    func declareKadi() {
        perform(.declareKadi(cards: selectedCards()))
    }

    func chooseSuit(_ suit: Suit) {
        perform(.chooseSuit(suit: suit))
    }

    func makeDemand(rank: Rank, suit: Suit) {
        perform(.makeDemand(rank: rank, suit: suit))
    }

    func respondToDemand(card: PlayingCard?) {
        perform(.respondToDemand(card: card))
    }

    func interceptSkip(jacks: [PlayingCard]) {
        perform(.interceptSkip(jacks: jacks))
    }

    func declineIntercept() {
        perform(.declineIntercept)
    }

    private func selectedCards() -> [PlayingCard] {
        selectedCardIndices.sorted().map { humanPlayer.hand[$0] }
    }

    // MARK: - Action application

    private func perform(_ action: GameAction) {
        if let error = GameEngine.validateAction(state, action) {
            errorMessage = error
            return
        }
        let before = state.discardPile
        do {
            state = try GameEngine.applyAction(state, action, using: &rng)
        } catch {
            errorMessage = "\(error)"
            return
        }
        recordPlayedForHardCpus(newDiscards: Array(state.discardPile.dropFirst(before.count)))
        selectedCardIndices = []
        checkGameOver()
        scheduleCpuTurnIfNeeded()
    }

    private func recordPlayedForHardCpus(newDiscards: [PlayingCard]) {
        for agent in cpuAgents.values {
            if let hard = agent as? HardCpu {
                for card in newDiscards {
                    hard.recordPlayed(card)
                }
            }
        }
    }

    private func checkGameOver() {
        guard state.phase == .finished, !didRecordRoundResult else { return }
        didRecordRoundResult = true
        let humanWon = state.players[humanIndex].hand.isEmpty
        for agent in cpuAgents.values {
            if let adaptive = agent as? AdaptiveCpu {
                adaptive.recordRoundResult(playerWon: humanWon)
            }
        }
    }

    // MARK: - CPU turn loop

    /// Which player must act next, accounting for non-blocking grace windows. With
    /// default `RuleSet()` (`lateKadiDeclaration`/`jumpInterceptAllowed` both false),
    /// the grace-window branches never fire, but are kept for structural correctness.
    private func cpuActingPlayerIndex() -> Int? {
        if let grace = state.skipInterceptGracePeriodPlayerIndex { return grace }
        if let grace = state.kadiGracePeriodPlayerIndex, state.rules.lateKadiDeclaration { return grace }
        return state.currentPlayerIndex
    }

    private func scheduleCpuTurnIfNeeded() {
        guard state.phase != .finished else { return }
        guard let actingIndex = cpuActingPlayerIndex(), actingIndex != humanIndex else { return }
        isCpuThinking = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            await self.runCpuTurn(for: actingIndex)
        }
    }

    private func runCpuTurn(for index: Int) async {
        defer { isCpuThinking = false }
        guard let agent = cpuAgents[index] else { return }
        let action = safeAction(agent.chooseAction(state: state, playerIndex: index), playerIndex: index)
        let before = state.discardPile
        guard let newState = try? GameEngine.applyAction(state, action, using: &rng) else {
            // Could not apply even the fallback action; retry next tick rather than
            // permanently stalling the game on this player's turn.
            scheduleCpuTurnIfNeeded()
            return
        }
        state = newState
        recordPlayedForHardCpus(newDiscards: Array(state.discardPile.dropFirst(before.count)))
        checkGameOver()
        scheduleCpuTurnIfNeeded()
    }

    /// Falls back to a guaranteed-valid action if the agent's chosen action fails
    /// validation (e.g. a `.declareKadi` chain that `kadiDecision` considers valid
    /// under evolving forced-suit semantics but `validatePlayCards`'s pairwise
    /// chain check rejects), so the CPU turn loop can never stall indefinitely.
    private func safeAction(_ action: GameAction, playerIndex: Int) -> GameAction {
        guard GameEngine.validateAction(state, action) != nil else { return action }

        let hand = state.players[playerIndex].hand
        let validPlays = KadiValidator.validPlays(
            hand: hand,
            topCard: state.topCard,
            forcedSuit: state.forcedSuit,
            rules: state.rules
        )
        var candidates: [GameAction] = validPlays.map { .playCards(cards: [$0]) }
        candidates.append(.pass)
        candidates.append(.drawStack)

        return candidates.first { GameEngine.validateAction(state, $0) == nil } ?? action
    }
}
