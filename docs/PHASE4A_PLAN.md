# Phase 4a: App shell, theme, Home screen, Solo (vs CPU) game screen

## Context

Phases 1–3c built three pure/backend Swift packages (`KadiEngine`, `KadiNetworking`,
`KadiOnline`) with no UI. Phase 4 builds the actual SwiftUI app, mirroring the original
Flutter feature tree (game, solo, online, LAN, lobby, friends, chat, profile, leaderboard,
settings, onboarding, presence, auth, home, end). That's too large for one slice, so it's
split into 4a–4d:

- **4a (this plan)**: App shell + shared theme + Home screen + Solo (single-player vs CPU)
  game screen, using only `KadiEngine`. Establishes the `Theme/`, `Shared/Components/`,
  `Features/` structure that 4b–4d will extend.
- 4b: LAN lobby + multiplayer game screen (`KadiNetworking`)
- 4c: Auth + online lobby + game screen (`KadiOnline` rooms)
- 4d: Social features (friends/chat/invites/leaderboard/profile/settings/presence)

There is no documented visual design from the original Flutter app (no Flutter source
available, `docs/GAME_SPEC.md` covers only rules/wire-format/data-model, not UI). The user
asked Claude to design the theme: dark "felt table" look, gold accent, red/black suit
colors, system/SF Pro typography. Exact values are specified below so no further design
decisions are needed mid-implementation.

The `kadi` Xcode target uses a `PBXFileSystemSynchronizedRootGroup` (Xcode 16+ synchronized
folders) for the `kadi/` directory — any new `.swift` files/folders created on disk under
`kadi/` are automatically part of the target's Sources. **No `project.pbxproj` edits are
needed** for this plan.

## Directory structure to create under `kadi/`

```
kadi/
  kadiApp.swift                     (modified)
  ContentView.swift                 (deleted)
  Theme/
    KadiTheme.swift                 (colors, fonts, layout constants, Color(hex:) helper)
  Shared/
    Components/
      PlayingCardView.swift
      PrimaryButton.swift           (PrimaryButtonStyle, SecondaryButtonStyle)
      PillBadge.swift
      PlayerHandView.swift
      OpponentSlotView.swift
  Features/
    Home/
      HomeView.swift
      SoloSetupView.swift
    Game/
      SoloGameView.swift
      SoloGameViewModel.swift
      Views/
        GameTableView.swift
        SuitChoiceOverlay.swift
        DemandEntryOverlay.swift
        CardDemandOverlay.swift
        SkipInterceptOverlay.swift
        QuestionAnswerBanner.swift
        GameOverOverlay.swift
        ActionBar.swift
```

## 1. Theme — `Theme/KadiTheme.swift`

```swift
import SwiftUI

enum KadiTheme {
    enum Colors {
        static let background    = Color(hex: 0x0B1F17)
        static let tableFelt      = Color(hex: 0x14533B)
        static let tableFeltDark  = Color(hex: 0x0E3A28)
        static let surface         = Color(hex: 0x1B2B24)
        static let surfaceElevated = Color(hex: 0x24372F)

        static let accent      = Color(hex: 0xD4AF37)
        static let accentMuted = Color(hex: 0x9C842B)

        static let suitRed   = Color(hex: 0xE0473F)
        static let suitBlack = Color(hex: 0x1A1A1A)

        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.65)
        static let textDisabled  = Color.white.opacity(0.35)

        static let success = Color(hex: 0x4CAF50)
        static let danger  = Color(hex: 0xE0473F)
        static let warning = Color(hex: 0xE0A93F)

        static let cardFace   = Color(hex: 0xFAF7F0)
        static let cardBack   = Color(hex: 0x1F4A3A)
        static let cardBorder = Color.black.opacity(0.15)
    }

    enum Typography {
        static let largeTitle   = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title        = Font.system(size: 26, weight: .bold, design: .rounded)
        static let headline     = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let body         = Font.system(size: 16, weight: .regular)
        static let callout      = Font.system(size: 14, weight: .medium)
        static let caption      = Font.system(size: 12, weight: .regular)
        static let cardRank     = Font.system(size: 20, weight: .bold, design: .rounded)
        static let cardRankSmall = Font.system(size: 13, weight: .bold, design: .rounded)
        static let buttonLabel  = Font.system(size: 17, weight: .semibold, design: .rounded)
    }

    enum Layout {
        static let cornerRadius: CGFloat = 14
        static let cardCornerRadius: CGFloat = 8
        static let cardWidth: CGFloat = 64
        static let cardHeight: CGFloat = 92
        static let cardWidthSmall: CGFloat = 44
        static let cardHeightSmall: CGFloat = 64
        static let spacingS: CGFloat = 8
        static let spacingM: CGFloat = 16
        static let spacingL: CGFloat = 24
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [Colors.background, Colors.tableFeltDark],
                        startPoint: .top, endPoint: .bottom)
    }
    static var tableFeltGradient: RadialGradient {
        RadialGradient(colors: [Colors.tableFelt, Colors.tableFeltDark],
                        center: .center, startRadius: 10, endRadius: 400)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
```

## 2. Reusable components (`Shared/Components/`)

- **`PlayingCardView.swift`**: renders a `KadiEngine.PlayingCard?` (nil/`isFaceUp: false` =
  card back). Uses `card.rankLabel`/`card.suitSymbol`/`card.isJoker`/`card.isRed` for face
  content, `KadiTheme.Colors.cardFace`/`cardBack`, rounded rect + border, `isSelected`
  (gold border + lift) and `isHighlighted` (green border, "playable") states.
- **`PrimaryButton.swift`**: `PrimaryButtonStyle` (gold fill, dark text) and
  `SecondaryButtonStyle` (surfaceElevated fill, white text, subtle border), per the
  snippets already designed in exploration.
- **`PillBadge.swift`**: small capsule label (e.g. card-count badges, "Your Turn",
  "CPU thinking…", "Draw +N", "Kadi!").
- **`PlayerHandView.swift`**: horizontal scroll of `PlayingCardView`s for the human's hand.
  Signature: `cards: [PlayingCard]`, `playableIndices: Set<Int>`, `selectedIndices: Set<Int>`,
  `onTap: (Int) -> Void` — **index-based**, not `Set<PlayingCard>`, because `PlayingCard`
  equality/hashing on (rank, suit) means duplicate cards (jokers, multi-deck) would collide
  in a Set.
- **`OpponentSlotView.swift`**: avatar (SF Symbol `person.crop.circle.fill`), name, a small
  fan of face-down `PlayingCardView`s (size `cardWidthSmall`/`cardHeightSmall`), and a
  `PillBadge` with `cardCount`. Always show counts in Solo mode (the `showOpponentCardCounts`
  rule flag is about human-vs-human fairness, not relevant solo).

## 3. Home screen (`Features/Home/`)

`HomeView.swift`: `NavigationStack` over `KadiTheme.backgroundGradient`, title "KADI",
subtitle, then a `NavigationLink` to `SoloSetupView` styled with `PrimaryButtonStyle`
("Solo Play"), plus three disabled/dimmed `SecondaryButtonStyle` buttons ("LAN Multiplayer",
"Online Multiplayer", "Profile") as stubs for 4b–4d.

`SoloSetupView.swift`: pickers for CPU opponent count (1–3, default 1) and
`CpuDifficulty` (easy/medium/hard/adaptive, default medium), then a `NavigationLink`
pushing `SoloGameView(opponentCount:, difficulty:)`.

## 4. Solo game — `Features/Game/`

### `SoloGameViewModel.swift`

```swift
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

@MainActor
final class SoloGameViewModel: ObservableObject {
    @Published private(set) var state: GameState
    @Published var selectedCardIndices: Set<Int> = []
    @Published var errorMessage: String?
    @Published var isCpuThinking: Bool = false

    let humanIndex = 0
    private var cpuAgents: [Int: CpuAgent] = [:]
    private var rng = AnyRNG()
    private var didRecordRoundResult = false

    init(opponentCount: Int, difficulty: CpuDifficulty, rules: RuleSet = RuleSet()) {
        var players: [Player] = [Player(id: "human", name: "You", hand: [], isHuman: true)]
        for i in 0..<opponentCount {
            players.append(Player(id: "cpu\(i)", name: "CPU \(i+1)", hand: [], isHuman: false))
        }
        self.state = try! GameEngine.createGame(players: players, rules: rules, using: &rng)
        for i in 1...opponentCount {
            cpuAgents[i] = difficulty.makeAgent()
        }
        scheduleCpuTurnIfNeeded()
    }

    var humanPlayer: Player { state.players[humanIndex] }
    var playableCards: [PlayingCard] {
        KadiValidator.validPlays(hand: humanPlayer.hand, topCard: state.topCard,
                                  forcedSuit: state.forcedSuit, rules: state.rules)
    }
    var canDeclareKadi: Bool {
        KadiValidator.canDeclareKadi(hand: humanPlayer.hand, topCard: state.topCard,
                                      forcedSuit: state.forcedSuit, rules: state.rules)
    }

    func toggleSelection(at index: Int) { /* toggle membership in selectedCardIndices */ }
    func confirmPlaySelected() { perform(.playCards(cards: selectedCards())) }
    func pass() { perform(.pass) }
    func drawStack() { perform(.drawStack) }
    func declareKadi() { perform(.declareKadi(cards: selectedCards())) }
    func chooseSuit(_ suit: Suit) { perform(.chooseSuit(suit: suit)) }
    func makeDemand(rank: Rank, suit: Suit) { perform(.makeDemand(rank: rank, suit: suit)) }
    func respondToDemand(card: PlayingCard?) { perform(.respondToDemand(card: card)) }
    func interceptSkip(jacks: [PlayingCard]) { perform(.interceptSkip(jacks: jacks)) }
    func declineIntercept() { perform(.declineIntercept) }

    private func selectedCards() -> [PlayingCard] {
        selectedCardIndices.sorted().map { humanPlayer.hand[$0] }
    }

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
                for card in newDiscards { hard.recordPlayed(card) }
            }
        }
    }

    private func checkGameOver() {
        guard state.phase == .finished, !didRecordRoundResult else { return }
        didRecordRoundResult = true
        let humanWon = state.players[humanIndex].hand.isEmpty
        for agent in cpuAgents.values {
            if let adaptive = agent as? AdaptiveCpu { adaptive.recordRoundResult(playerWon: humanWon) }
        }
    }

    /// Which player must act next, accounting for non-blocking grace windows.
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
        let action = agent.chooseAction(state: state, playerIndex: index)
        guard GameEngine.validateAction(state, action) == nil else { return }
        let before = state.discardPile
        guard let newState = try? GameEngine.applyAction(state, action, using: &rng) else { return }
        state = newState
        recordPlayedForHardCpus(newDiscards: Array(state.discardPile.dropFirst(before.count)))
        checkGameOver()
        scheduleCpuTurnIfNeeded()
    }
}
```

Note: with default `RuleSet()` (`lateKadiDeclaration: false`, `jumpInterceptAllowed: false`),
the grace-window branches in `cpuActingPlayerIndex()` never fire — kept for structural
correctness so 4a doesn't need revisiting once rules become configurable. Phase 4a ships
with `RuleSet()` defaults (no custom rule configuration UI).

### Phase → UI mapping in `SoloGameView.swift`

| `state.phase` | UI shown (only when it's the human's turn to act) |
| --- | --- |
| `.playing` | Normal table + `ActionBar` (Play/Pass/Draw Stack/Declare Kadi) |
| `.suitChoice` | `SuitChoiceOverlay` — 4 suit buttons → `chooseSuit(_:)` |
| `.demandEntry` | `DemandEntryOverlay` — rank picker (excl. joker) + suit picker → `makeDemand(rank:suit:)` |
| `.cardDemand` | `CardDemandOverlay` — shows `demandedCard`; "Play it" if held → `respondToDemand(card:)`, else "Draw instead" → `respondToDemand(card: nil)` |
| `.questionAnswer` | `QuestionAnswerBanner` — shows `forcedSuit`; hand highlights matching cards; "Pass" always available |
| `.skipIntercept` | `SkipInterceptOverlay` — select ≥1 Jack → `interceptSkip(jacks:)`, or `declineIntercept()` |
| `.finished` | `GameOverOverlay` — winner name (`state.players.first { $0.hand.isEmpty }`), "Play Again" (re-create `SoloGameViewModel`) / "Back to Home" |

For phases where it's a CPU's turn, hide overlays and show a `PillBadge("CPU thinking…")`
via `isCpuThinking`.

### `SoloGameView.swift` layout

```
ZStack {
    KadiTheme.tableFeltGradient.ignoresSafeArea()
    VStack(spacing: 0) {
        HStack { ForEach over opponents -> OpponentSlotView }   // top row
        Spacer()
        GameTableView(topCard:, drawCount:, direction:, pendingDrawCount:, forcedSuit:)
        Spacer()
        VStack {
            PlayerHandView(cards: humanPlayer.hand, playableIndices:, selectedIndices:, onTap:)
            ActionBar(viewModel:)
        }
    }
    // phase overlays per table above, gated on `state.currentPlayerIndex == humanIndex`
}
.alert("Invalid Move", isPresented: .constant(viewModel.errorMessage != nil)) {
    Button("OK") { viewModel.errorMessage = nil }
} message: { Text(viewModel.errorMessage ?? "") }
```

`GameTableView`: large `PlayingCardView` for `topCard` (discard), face-down
`PlayingCardView` + count badge for draw pile, a direction arrow icon
(`arrow.clockwise`/`arrow.counterclockwise` per `state.direction`), a `PillBadge("Draw +N")`
in `warning` color when `pendingDrawCount > 0`, and a suit badge when `forcedSuit != nil`.

`ActionBar` buttons (visible/enabled only when `state.currentPlayerIndex == humanIndex &&
state.phase == .playing`):
- **Play (N)**: enabled iff `selectedCardIndices` non-empty → `confirmPlaySelected()`
- **Pass**: → `pass()` (validity is checked by `perform`/`validateAction`; disabled when
  `state.isDrawStackActive`)
- **Draw Stack**: shown only when `state.isDrawStackActive` → `drawStack()`
- **Declare Kadi**: shown when `canDeclareKadi` → `declareKadi()`

## 5. App wiring

- **Delete** `kadi/ContentView.swift` (placeholder "Hello, world" — synchronized group
  picks up the deletion automatically, no pbxproj cleanup needed).
- **Modify** `kadi/kadiApp.swift`: keep `import KadiOnline` and
  `FirebaseBootstrap.configure()` in `init()` (needed for 4c later), but change
  `WindowGroup` content from `ContentView()` to `HomeView()`. `HomeView`/`SoloGameView`/
  `SoloGameViewModel` import only `KadiEngine` (+ SwiftUI/Foundation) — `kadiApp.swift`
  remains the only file touching `KadiOnline`.

## 6. Verification

- Build incrementally after each chunk (Theme+components, then Home, then Solo VM, then
  Solo View):
  ```
  xcodebuild -project /Users/collinswachira/Desktop/kadi/kadi.xcodeproj \
    -scheme kadi -destination 'platform=iOS Simulator,name=iPhone 17' build
  ```
- Before relying on `try!` in `SoloGameViewModel.init`, confirm `GameEngine.createGame`/
  `DeckBuilder` don't throw for `opponentCount` 1–3 with `RuleSet()` defaults (read
  `KadiEngine/Sources/KadiEngine/Engine/DeckBuilder.swift` if needed); constrain
  `SoloSetupView`'s picker range accordingly.
- Use the `/run` skill to launch the app in the iOS Simulator and manually play through a
  full game:
  1. Home screen renders with dark/gold theme; only "Solo Play" is enabled.
  2. Solo setup → table layout (opponents top, piles center, hand+action bar bottom).
  3. Tap playable cards, "Play" → discard updates, CPU auto-plays after a short delay.
  4. Trigger a 2/3/Joker → `pendingDrawCount` badge + "Draw Stack" button appear.
  5. Play a non-A♠️ Ace → `SuitChoiceOverlay` appears and resolves on tap.
  6. Play 2 Aces or A♠️ → `DemandEntryOverlay`, then `CardDemandOverlay` on the responder's turn.
  7. Play an 8/Q → `QuestionAnswerBanner` + forced-suit highlighting on the hand.
  8. Play to a win (or let a CPU win) → `GameOverOverlay` with "Play Again"/"Back to Home".

