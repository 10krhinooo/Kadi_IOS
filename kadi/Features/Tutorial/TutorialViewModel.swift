//
//  TutorialViewModel.swift
//  kadi
//

import Combine
import Foundation
import SwiftUI
import KadiEngine

@MainActor
final class TutorialViewModel: ObservableObject {
    @Published private(set) var state: GameState
    @Published var selectedCardIndices: Set<Int> = []
    @Published var stepIndex: Int = 0
    @Published var isActionLocked: Bool = false
    @Published var hintMessage: String? = nil
    @Published var isComplete: Bool = false
    @Published var errorMessage: String? = nil

    private var rng = AnyRNG()
    private var cpuScript: [GameAction]
    private var cpuScriptIndex = 0

    let humanIndex = 0

    var currentStep: TutorialStep {
        TutorialStep.script[min(stepIndex, TutorialStep.script.count - 1)]
    }

    var humanPlayer: Player { state.players[humanIndex] }

    var playableIndices: Set<Int> {
        let playable = KadiValidator.validPlays(
            hand: humanPlayer.hand,
            topCard: state.topCard,
            forcedSuit: state.forcedSuit,
            rules: state.rules
        )
        var result: Set<Int> = []
        for (i, card) in humanPlayer.hand.enumerated() where playable.contains(card) {
            result.insert(i)
        }
        return result
    }

    var isHumanTurn: Bool { state.currentPlayerIndex == humanIndex }

    var canDeclareKadi: Bool {
        guard state.phase == .playing && !state.isDrawStackActive else { return false }
        return KadiValidator.canDeclareKadi(
            hand: humanPlayer.hand,
            topCard: state.topCard,
            forcedSuit: state.forcedSuit,
            rules: state.rules
        )
    }

    init() {
        // Top card: 9♣ — human's 4♣ matches by suit, then CPU can play 2♣.
        let topDiscard = PlayingCard(rank: .nine, suit: .clubs)

        // Human has no counter cards (no Ace/2/3/Joker) so the CPU's 2♣ penalty
        // auto-draws. Draw pile front has A♣ so human picks it up during the penalty
        // and can use it to answer the CPU's 8♣ question card.
        let humanHand: [PlayingCard] = [
            PlayingCard(rank: .four, suit: .clubs),
            PlayingCard(rank: .king, suit: .hearts),
            PlayingCard(rank: .six, suit: .hearts),
        ]
        let cpuHand: [PlayingCard] = [
            PlayingCard(rank: .two, suit: .clubs),
            PlayingCard(rank: .eight, suit: .clubs),
            PlayingCard(rank: .five, suit: .diamonds),
        ]

        // removeFirst() draws from index 0: A♣ and 9♥ are the two penalty cards.
        // Index 2 is drawn by the CPU when it passes in questionAnswer (must be non-hearts
        // so the CPU can't answer the hearts forced suit in a later step).
        let drawPile: [PlayingCard] = [
            PlayingCard(rank: .ace, suit: .clubs),
            PlayingCard(rank: .nine, suit: .hearts),
            PlayingCard(rank: .five, suit: .spades),
            PlayingCard(rank: .six, suit: .diamonds),
            PlayingCard(rank: .nine, suit: .diamonds),
            PlayingCard(rank: .ten, suit: .clubs),
            PlayingCard(rank: .four, suit: .spades),
        ]

        let human = Player(id: "human", name: "You", hand: humanHand, isHuman: true)
        let cpu = Player(id: "cpu", name: "CPU", hand: cpuHand, isHuman: false)

        self.state = GameState(
            players: [human, cpu],
            drawPile: drawPile,
            discardPile: [topDiscard],
            currentPlayerIndex: 0,
            rules: RuleSet(),
            direction: .clockwise,
            pendingDrawCount: 0,
            phase: .playing
        )

        // Step 2: CPU plays 2♣ on 4♣ (same suit ♣)
        // Step 4: CPU plays 8♣ on 2♣ (same suit ♣) → questionAnswer phase; CPU stays current player
        // Step 5 (new): CPU passes in questionAnswer (no Clubs card left); draws draw pile[2] = 5♠
        // Step 8: CPU passes (no Hearts card after human chooses Hearts via Ace)
        self.cpuScript = [
            .playCards(cards: [PlayingCard(rank: .two, suit: .clubs)]),
            .playCards(cards: [PlayingCard(rank: .eight, suit: .clubs)]),
            .pass,
            .pass,
        ]

        Task { await self.beginStep() }
    }

    // MARK: - Step management

    private func beginStep() async {
        guard stepIndex < TutorialStep.script.count else {
            isComplete = true
            return
        }

        let step = currentStep
        hintMessage = nil

        if step.expectedAction == .cpuTurn {
            isActionLocked = true
            try? await Task.sleep(for: .milliseconds(800))
            await runCpuTurn()
            advanceStep()
        } else if step.expectedAction == .drawStack {
            isActionLocked = true
            try? await Task.sleep(for: .milliseconds(1500))
            applyHumanAction(.drawStack)
        } else if step.expectedAction == .finish {
            isComplete = true
        } else {
            isActionLocked = false
        }
    }

    func advanceStep() {
        stepIndex += 1
        Task { await beginStep() }
    }

    // MARK: - Human actions

    func toggleSelection(at index: Int) {
        guard !isActionLocked else { return }
        let card = humanPlayer.hand[index]
        if let expectedCards = currentStep.expectedCards, !expectedCards.contains(card) {
            hintMessage = currentStep.wrongSelectionHint ?? "Select the correct card to continue."
            return
        }
        if selectedCardIndices.contains(index) {
            selectedCardIndices.remove(index)
        } else {
            selectedCardIndices.insert(index)
        }
        // After first card selection in step 0, advance to step 1 (Play Your Card)
        if stepIndex == 0 && !selectedCardIndices.isEmpty {
            advanceStep()
        }
    }

    func confirmPlay() {
        guard !isActionLocked else { return }
        let cards = selectedCardIndices.sorted().map { humanPlayer.hand[$0] }
        guard !cards.isEmpty else {
            hintMessage = "Select a card first by tapping it."
            return
        }
        applyHumanAction(.playCards(cards: cards))
    }

    func drawCard() {
        guard !isActionLocked else { return }
        applyHumanAction(.pass)
    }

    func drawStack() {
        guard !isActionLocked else { return }
        applyHumanAction(.drawStack)
    }

    func declareKadi() {
        guard !isActionLocked else { return }
        let cards = selectedCardIndices.sorted().map { humanPlayer.hand[$0] }
        applyHumanAction(.declareKadi(cards: cards))
    }

    func chooseSuit(_ suit: Suit) {
        guard !isActionLocked else { return }
        applyHumanAction(.chooseSuit(suit: suit))
    }

    private func applyHumanAction(_ action: GameAction) {
        isActionLocked = true
        if let error = GameEngine.validateAction(state, action) {
            errorMessage = error
            isActionLocked = false
            return
        }
        guard let newState = try? GameEngine.applyAction(state, action, using: &rng) else {
            isActionLocked = false
            return
        }
        state = newState
        selectedCardIndices = []
        hintMessage = nil

        Task {
            try? await Task.sleep(for: .milliseconds(300))
            advanceStep()
        }
    }

    // MARK: - CPU turn

    private func runCpuTurn() async {
        guard cpuScriptIndex < cpuScript.count else { return }
        let action = cpuScript[cpuScriptIndex]
        cpuScriptIndex += 1

        // Apply scripted action if valid; fall back to .pass otherwise.
        let validAction: GameAction
        if GameEngine.validateAction(state, action) == nil {
            validAction = action
        } else {
            validAction = .pass
        }

        guard let newState = try? GameEngine.applyAction(state, validAction, using: &rng) else { return }
        state = newState
    }
}
