//
//  TutorialStep.swift
//  kadi
//

import KadiEngine

enum TutorialHighlight {
    case hand
    case playButton
    case drawButton
    case drawStackButton
    case kadiButton
    case discardPile
    case suitOverlay
    case none
}

enum TutorialExpectedAction {
    case selectAndPlayCard
    case drawCard
    case drawStack
    case declareKadi
    case chooseSuit
    case cpuTurn       // auto-advance after delay, no user input
    case finish
}

struct TutorialStep {
    let title: String
    let body: String
    let highlight: TutorialHighlight
    let expectedAction: TutorialExpectedAction
    /// When set, only these cards may be selected in this step.
    let expectedCards: [PlayingCard]?
    /// Shown when the player taps a card not in `expectedCards`.
    let wrongSelectionHint: String?

    init(
        title: String,
        body: String,
        highlight: TutorialHighlight,
        expectedAction: TutorialExpectedAction,
        expectedCards: [PlayingCard]? = nil,
        wrongSelectionHint: String? = nil
    ) {
        self.title = title
        self.body = body
        self.highlight = highlight
        self.expectedAction = expectedAction
        self.expectedCards = expectedCards
        self.wrongSelectionHint = wrongSelectionHint
    }
}

extension TutorialStep {
    static let script: [TutorialStep] = [
        // Step 0 — select the guided card
        TutorialStep(
            title: "Your Hand",
            body: "These are your cards. The green-bordered card matches the top card's suit — tap it to select it.",
            highlight: .hand,
            expectedAction: .selectAndPlayCard,
            expectedCards: [PlayingCard(rank: .four, suit: .clubs)],
            wrongSelectionHint: "Tap the 4 of Clubs \u{2663} — it's the matching card this turn."
        ),
        // Step 1 — confirm the play
        TutorialStep(
            title: "Play Your Card",
            body: "Great! Now tap Play to put your selected card on the discard pile.",
            highlight: .playButton,
            expectedAction: .selectAndPlayCard
        ),
        // Step 2 — CPU plays a 2
        TutorialStep(
            title: "CPU's Turn",
            body: "The CPU plays a 2 \u{2663} — a penalty card! You'll need to draw cards on your next turn.",
            highlight: .discardPile,
            expectedAction: .cpuTurn
        ),
        // Step 3 — auto-draw penalty (handled automatically)
        TutorialStep(
            title: "Penalty Cards!",
            body: "You have no counter card, so the 2 penalty cards are drawn automatically.",
            highlight: .drawStackButton,
            expectedAction: .drawStack
        ),
        // Step 4 — CPU plays an 8
        TutorialStep(
            title: "CPU's Turn Again",
            body: "The CPU plays an 8 \u{2663} — a question card! The player who plays an 8 must immediately follow it with a card of the same suit, or draw.",
            highlight: .discardPile,
            expectedAction: .cpuTurn
        ),
        // Step 5 — CPU passes in questionAnswer (no Clubs card); draws one card
        TutorialStep(
            title: "CPU Can't Answer",
            body: "The CPU has no Clubs card to play, so it draws one instead and the turn passes to you.",
            highlight: .discardPile,
            expectedAction: .cpuTurn
        ),
        // Step 6 — human plays A♣ on top of 8♣ (same suit)
        TutorialStep(
            title: "Your Turn",
            body: "You drew an Ace of Clubs \u{2663} earlier. Select it and tap Play — it matches the top card's suit (Clubs).",
            highlight: .hand,
            expectedAction: .selectAndPlayCard,
            expectedCards: [PlayingCard(rank: .ace, suit: .clubs)],
            wrongSelectionHint: "Select the Ace of Clubs \u{2663} — it's your only matching card."
        ),
        // Step 7 — choose a suit after playing the Ace
        TutorialStep(
            title: "Choose a Suit",
            body: "You played an Ace! Choose which suit the next player must follow. Pick Hearts \u{2665}.",
            highlight: .suitOverlay,
            expectedAction: .chooseSuit
        ),
        // Step 8 — CPU takes its final turn
        TutorialStep(
            title: "CPU's Turn",
            body: "The CPU has no Hearts card, so it draws and passes. Now it's your turn — and you can win!",
            highlight: .discardPile,
            expectedAction: .cpuTurn
        ),
        // Step 9 — declare KADI (select all remaining cards + tap KADI to win)
        TutorialStep(
            title: "Declaring KADI",
            body: "Your entire hand can win right now! Select all your remaining cards, then tap the glowing KADI button to declare and win!",
            highlight: .kadiButton,
            expectedAction: .declareKadi
        ),
        // Step 10 — done
        TutorialStep(
            title: "You Win!",
            body: "Congratulations — you've learned Kadi! Head back to play a real game.",
            highlight: .none,
            expectedAction: .finish
        ),
    ]
}
