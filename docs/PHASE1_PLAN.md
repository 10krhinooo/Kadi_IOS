# Kadi Swift Port — Phase 1: Core Game Engine + Project Scaffold

> **Status: COMPLETE.** Preserved verbatim as the approved plan that produced the current
> `KadiEngine` package, its test suite, the `kadi.xcodeproj` wiring, this `docs/GAME_SPEC.md`,
> and the root `plan.md`. See `plan.md` for current status and the Phase 2–6
> roadmap.

## Context

The user wants to rebuild the Flutter "Kadi" card game natively in Swift, with full feature
parity (game engine, LAN + online multiplayer, Firebase, AI, admin panel, Cloud Functions).
That's a multi-phase effort. This phase focuses on:

1. A complete Xcode project scaffold (Swift Package for the engine + thin SwiftUI app target,
   already exists as a fresh Xcode 26 project at `/Users/collinswachira/Desktop/kadi`).
2. A bit-for-bit faithful port of the **pure game engine** (`lib/core/` in the Dart repo) —
   models, RuleSet, GameAction, DeckBuilder, GameEngine, KadiValidator, CpuAgent — with
   Codable conformances matching the Dart JSON wire format exactly (Section K of the spec),
   since this engine must interoperate with the existing Flutter LAN peers / Firestore data
   in later phases.
3. Unit tests covering deck construction, full turn-resolution logic (draw stacking, jack
   skip/intercept, king double-reverse, ace/demand flow, Kadi declarations, false-Kadi
   penalty, late-Kadi grace), and JSON round-trips against the documented wire format.
4. A new, Swift-specific `plan.md` at the repo root that documents the new architecture,
   build/test commands, wire-format fidelity requirements, and a roadmap for the remaining
   phases (LAN networking, Firebase/online multiplayer, SwiftUI UI, separate admin app,
   Cloud Functions — kept as-is in TS).
5. A preserved copy of the full Dart-derived spec (the "Swift Port Reference" section,
   sections A–L) as a standing reference doc for future phases.

Existing repo state: a brand-new Xcode project (`kadi.xcodeproj`, app target `kadi`,
`PBXFileSystemSynchronizedRootGroup` — files dropped into `kadi/` are auto-included), with
only the default `kadiApp.swift` + `ContentView.swift`. No engine code exists yet.

## Repo structure after this phase

```
kadi/                             (repo root)
├── plan.md                       (new — Swift project guide, see below)
├── docs/
│   └── GAME_SPEC.md              (preserved sections A–L from the Dart reference, verbatim)
├── KadiEngine/                   (new local Swift Package — pure logic, no UIKit/SwiftUI/Firebase deps)
│   ├── Package.swift             (iOS 17 / macOS 14 platforms, library product "KadiEngine")
│   ├── Sources/KadiEngine/
│   │   ├── Models/
│   │   │   ├── Card.swift            (Rank, Suit, PlayingCard + derived properties)
│   │   │   ├── RuleSet.swift         (RuleSet struct, HintLevel enum)
│   │   │   ├── Player.swift          (Player struct)
│   │   │   └── GameState.swift       (GameState, GamePhase, Direction, KadiState)
│   │   ├── Actions/
│   │   │   └── GameAction.swift      (enum w/ associated values + custom Codable for "type" tag)
│   │   ├── Engine/
│   │   │   ├── DeckBuilder.swift     (deck construction, dealing, starting card selection)
│   │   │   ├── GameEngine.swift      (createGame / validateAction / applyAction — all 13 PlayCards branches + other actions)
│   │   │   └── KadiValidator.swift   (validPlays, canDeclareKadi recursive DFS)
│   │   └── CPU/
│   │       └── CpuAgent.swift        (CpuAgent protocol + Easy/Medium/Hard/Adaptive implementations)
│   └── Tests/KadiEngineTests/
│       ├── DeckBuilderTests.swift
│       ├── GameEngineTests.swift     (one suite per action/branch family)
│       ├── KadiValidatorTests.swift
│       ├── CpuAgentTests.swift
│       └── CodecTests.swift          (JSON round-trip vs documented wire shapes)
├── kadi/                          (existing SwiftUI app target — unchanged except package dependency)
│   ├── kadiApp.swift
│   ├── ContentView.swift
│   └── Assets.xcassets/
└── kadi.xcodeproj/                (add local package reference + link KadiEngine to "kadi" target)
```

> Note: in the actual implementation, `GameEngineTests.swift` was split into
> `GameEngineCreateGameTests.swift`, `GameEnginePlayCardsTests.swift`, and
> `GameEngineActionsTests.swift`, plus a shared `TestHelpers.swift`. The engine itself is
> split across `GameEngine.swift`, `GameEngine+Validation.swift`,
> `GameEngine+PlayCards.swift`, and `GameEngine+Actions.swift`.

## KadiEngine — implementation notes (mapping spec → Swift)

All types live in module `KadiEngine`, fully `Codable`/`Equatable`/`Hashable` where the Dart
models are, with `CodingKeys`/raw values chosen to match the JSON produced by
`game_state_codec.dart` **exactly** (lowercase enum names like Dart's `.name`: e.g.
`Rank.jack` → `"jack"`, `Direction.anticlockwise` → `"anticlockwise"`, `GamePhase.suitChoice`
→ `"suitChoice"`).

- **Card.swift**: `Rank: String, Codable` (two..ace, joker), `Suit: String, Codable`
  (hearts/diamonds/clubs/spades), `PlayingCard: Codable, Equatable, Hashable` with all derived
  properties from spec §A (`isJoker`, `isDrawCard`, `isQuestionCard`, `isSkipCard`,
  `isReverseCard`, `isAce`, `isAceOfSpades`, `isRed`/`isBlack`, `isSpecial`, `canEndGame`,
  `drawValue`, `rankLabel`, `suitSymbol`, `displayName`).
- **RuleSet.swift**: struct with all 16 fields from spec §B, defaults matching the table,
  `HintLevel: String, Codable` (`none|basic|advanced`).
- **Player.swift**: `id, name, hand: [PlayingCard], isHuman: Bool, avatarIndex: Int = 0`,
  computed `cardCount`.
- **GameState.swift**: all fields from spec §C including `phase: GamePhase`,
  `direction: Direction`, `kadiState: KadiState?`, all skip-intercept bookkeeping fields, plus
  derived `topCard`, `currentPlayer`, `isDrawStackActive`. Custom `Codable` to match §K
  exactly — note the wire format includes **both** `drawPileCount` (encoded) and `drawPile`
  (the actual array), which Dart's codec emits redundantly; replicate that.
- **GameAction.swift**: Swift `enum` with associated values for all 13 action types in §E.
  Custom `init(from:)`/`encode(to:)` keyed on a `"type"` discriminator string matching the
  exact type names in the table (`PlayCards`, `Pass`, `DrawStack`, `DeclareKadi`,
  `ChooseSuit`, `MakeDemand`, `RespondToDemand`, `RefuseDraw`, `RefuseSkip`, `RefuseReverse`,
  `InterceptSkip`, `DeclineIntercept`, `JumpDraw`).
- **DeckBuilder.swift**: per spec §F — build `deckCount` decks (+2 jokers per deck if
  `jokersIncluded`, Red Joker = `{joker, hearts}`, Black Joker = `{joker, clubs}`), shuffle via
  injectable RNG (protocol `RandomNumberGenerator`-based, to allow deterministic tests), deal
  round-robin, starting-card selection logic (push special cards to back, optional full
  reshuffle via `startingCardReshuffle`, throw on exhaustion).
- **GameEngine.swift**: the core of the work. Static/pure functions:
  - `createGame(players:rules:rng:) -> GameState`
  - `validateAction(_:_:) -> String?` (error message or nil)
  - `applyAction(_:_:) throws -> GameState` (throws `InvalidActionError` if validate fails)
  - Shared helpers: `isRuledDrawCard`, `isValidPlay`, `_drawCards`, `_advanceTurn`.
  - Implement **all 13 numbered cases** under §G exactly as specified, including the
    `_applyPlayCards` sub-steps 1–13 (win check, false-Kadi 2-card penalty, declared-Kadi
    cancellation + `kadiPenalty`, draw-stack open/stack/cap, question-card chaining, ace
    counter-play, ace→suitChoice/demandEntry, jack skip + jack-stackable + jump-intercept
    grace window, king double-reverse vs single reverse, plain card).
  - Faithfully port `RefuseDraw`, `RefuseSkip`, `RefuseReverse`, `InterceptSkip` (both
    grace-window and blocking `.skipIntercept` paths incl. `_buildSkipInterceptQueue` /
    `_resolveSkip`), `DeclineIntercept`, `JumpDraw` (triggering-card scan + `drawJumpAllowed`
    / `jokerJumpAllowed` checks).
- **KadiValidator.swift**: `validPlays(hand:topCard:forcedSuit:rules:) -> [PlayingCard]` and
  `canDeclareKadi(hand:topCard:forcedSuit:rules:) -> Bool` via recursive DFS exactly as in §H
  (question cards force next suit, Aces tried against all 4 suits, success iff some full
  ordering ends on a `canEndGame` card).
- **CpuAgent.swift**: `CpuAgent` protocol with `chooseAction(state:playerIndex:) -> GameAction`
  plus the decision-point methods enumerated in §I. Implement `EasyCpu`, `MediumCpu`
  (`_mostCommonSuit`/`_leastCommonSuit`), `HardCpu` (`recordPlayed`, `_playedCards`,
  `_bestSuit`), `AdaptiveCpu` (wraps the three, `recordRoundResult`, win-rate-based
  difficulty switching every 3 rounds).

## plan.md (new, repo root)

Replace/author a Swift-focused `plan.md` containing:
- Project overview: native Swift/SwiftUI rebuild of Kadi; current phase status (engine done,
  networking/Firebase/UI/admin pending) and pointer to `docs/GAME_SPEC.md` for the full
  rules/wire-format contract.
- Commands: `cd KadiEngine && swift test` (engine unit tests), `xcodebuild -scheme kadi
  -destination 'platform=iOS Simulator,name=iPhone 16' build` (app build).
- Architecture section mirroring the Dart layout but Swift-native: `KadiEngine` package
  (pure logic, no Flutter/Firebase deps — testable standalone) + `kadi/` SwiftUI app target.
- **Wire-format fidelity rule**: any change to Models/Actions/Codec must keep JSON
  byte-for-bit-compatible with `lib/network/sync/game_state_codec.dart` so future LAN/Firestore
  interop with the Flutter app works — link to `docs/GAME_SPEC.md` §K.
- Roadmap (future phases, not yet implemented):
  - **Phase 2 — LAN multiplayer**: TCP/NDJSON protocol via `Network.framework`, Bonjour
    (`NWBrowser`/`NWListener`) for `_kadi._tcp` discovery + UDP beacon fallback on port 4499,
    matching `NetworkMessageType` set from §J.
  - **Phase 3 — Online multiplayer / Firebase**: Firebase iOS SDK (Firestore, RTDB, Auth,
    FCM), data model exactly per §L (`/rooms`, `/users`, `/friendRequests`, `/conversations`,
    `/gameInvites`, presence in RTDB, etc.), host-authoritative action processing.
  - **Phase 4 — SwiftUI app**: feature modules mirroring `lib/features/` (game, solo, online,
    multiplayer/LAN, lobby, friends, chat, profile, leaderboard, settings, onboarding,
    presence, auth, home, end), shared theme matching the documented palette/typography
    (Poppins, dark theme, exact hex colors/text styles from the Dart project documentation).
  - **Phase 5 — Admin app**: separate SwiftUI (macOS/iPadOS) project for campaign management,
    sharing the same Firebase project (`kadi-254`).
  - **Phase 6 — Cloud Functions**: unchanged, remain TypeScript in `functions/` (or a sibling
    repo/dir), region `europe-west1`, same triggers (`onGameInviteCreated`,
    `onFriendRequestCreated`, `onDmMessageCreated`, `onCampaignCreated`/`processCampaigns`).
- Audio/vibration/notifications/Shorebird-equivalent considerations deferred to Phase 4+,
  noted as open questions (Shorebird is Flutter-specific — Swift equivalent would be
  App Store TestFlight / no direct analog; flag for user decision later).

## docs/GAME_SPEC.md

Copy the "Swift Port Reference" section (A–L) from the user's message verbatim into this
file so it remains the canonical rules/wire-format reference for all future phases without
re-deriving it from the Dart source.

## Xcode project wiring

- Add `KadiEngine` as a local Swift Package dependency (`XCLocalSwiftPackageReference` +
  `packageProductDependencies` on the `kadi` app target) in `kadi.xcodeproj/project.pbxproj`,
  so `import KadiEngine` works from `ContentView.swift`/`kadiApp.swift`. No UI changes in this
  phase — app target stays as the default Hello World, just gains the dependency so it
  continues to build cleanly.

## Verification

- `cd KadiEngine && swift test` — all engine unit tests pass.
- `xcodebuild -project kadi.xcodeproj -scheme kadi -destination 'generic/platform=iOS' build`
  (or simulator) — app target builds successfully with the new package dependency linked.
- Spot-check a few JSON encode/decode round trips against literal JSON strings matching the
  documented Dart wire format (Card, RuleSet, GameAction variants, GameState) in
  `CodecTests.swift`.

## Outcome

- All 124 unit tests across `DeckBuilderTests`, `KadiValidatorTests`, `CodecTests`,
  `CpuAgentTests`, `GameEngineCreateGameTests`, `GameEnginePlayCardsTests`, and
  `GameEngineActionsTests` pass via `swift test`.
- `kadi.xcodeproj` builds successfully with `KadiEngine` linked as a local Swift package
  product dependency on the `kadi` app target (`import KadiEngine` resolves).
- Two real bugs were found and fixed during test-writing:
  - `applyMakeDemand` was clobbering `.cardDemand` phase via `advanceTurn`'s unconditional
    `phase = .playing` reset — fixed by reordering.
  - `PlayingCard`'s synthesized `Codable` omitted `"suit"` when `nil` instead of encoding
    `null`, breaking wire-format fidelity — fixed with a custom `Codable` conformance.
