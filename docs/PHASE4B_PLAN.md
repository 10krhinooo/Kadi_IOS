# Phase 4b: LAN Lobby + Multiplayer Game Screen

## Context

Phase 4a delivered a complete solo (vs CPU) game screen using only `KadiEngine`. Phase 4b
is the next item on the roadmap: wire up the already-complete `KadiNetworking` package
(host-authoritative LAN multiplayer over TCP/NDJSON with Bonjour/UDP-beacon discovery,
CPU takeover on disconnect, reconnect-by-uid, and host migration) into the SwiftUI app —
a LAN setup/lobby flow and a multiplayer game screen that mirrors the Phase 4a solo
screen's structure and theme.

User-confirmed scope decisions:
1. **Full disconnect/migration UI**: CPU-takeover banners and the complete host-migration
   flow (promote-to-host / reconnect-to-new-host) are in scope, not deferred.
2. **Avatar picker**: add a simple SF-Symbol-based avatar grid; `Player.avatarIndex`
   already exists in `KadiEngine` (default 0) but has no UI yet.
3. **Name & UID**: prompt for a display name in the LAN setup screen, persisted in
   `UserDefaults`; generate+persist a random UUID as the device's LAN `uid`.
4. **New parallel views**: do not modify `SoloGameView`/`SoloGameViewModel`/`ActionBar`.
   Build `LANGameView`/`LANGameViewModel`/`LANActionBar` mirroring the same conventions.

## Grounding facts (verified against source)

- `GamePhase` has no `.lobby` case — pre-game is "no `GameState` yet" (`LANGameHost`'s
  `gameStateUpdates()`/`currentGameState` are nil/empty until `startGame()`; client has
  no state until `.gameStart`/`.gameStateFull`). "Game started" = first non-nil emission.
- `LANGameHost`/`LANGameClient` are both `public actor`s.
- `GameState`: `players: [Player]`, `currentPlayerIndex: Int`, `currentPlayer: Player`,
  `topCard: PlayingCard?`, `demandedCard: PlayingCard?`, `forcedSuit: Suit?`,
  `pendingDrawCount: Int`, `isDrawStackActive: Bool`, `direction`, `drawPile`, `phase`.
- `Player.cardCount: Int { hand.count }`, `Player.avatarIndex: Int` (default 0).
- `PlayingCard.isAce`, `.isSkipCard` (rank == .jack) exist.
- `KadiValidator.validPlays(hand:topCard:forcedSuit:rules:)`,
  `.canDeclareKadi(hand:topCard:forcedSuit:rules:)` — signatures match plan usage.
- `GameAction` cases used: `.playCards(cards:)`, `.pass`, `.drawStack`,
  `.declareKadi(cards:)`, `.chooseSuit(suit:)`, `.makeDemand(rank:suit:)`,
  `.respondToDemand(card:)`, `.interceptSkip(jacks:)`, `.declineIntercept` — all exist.
- `LANGameHost` currently exposes no lobby roster stream and no disconnect/CPU-takeover
  event stream for its own UI. `LANGameClient.rosterUpdates()` exists but doesn't expose
  per-index disconnect/reconnect events. Both need small additive APIs (below).

## 1. KadiNetworking additions (additive, non-breaking)

New file `KadiNetworking/Sources/KadiNetworking/Session/LANConnectionEvent.swift`:

```swift
public enum LANConnectionEvent: Equatable, Sendable {
    case playerDisconnected(playerIndex: Int)
    case playerReconnected(playerIndex: Int)
}
```

**`LANGameHost.swift`**:
- `public func lobbyUpdates() -> AsyncStream<[Player]>` — yields current roster
  immediately then on every roster change. Add `lobbyContinuations` array; call
  `publishLobby()` at the end of `processJoin` (both join and reconnect branches) and at
  the end of `startGame()`.
- `public func connectionEvents() -> AsyncStream<LANConnectionEvent>` — add
  `connectionEventContinuations`; call `publishConnectionEvent(.playerDisconnected(...))`
  in `handleDisconnect(uid:)` after setting `isCPUControlled = true`, and
  `.playerReconnected(...)` in `processJoin`'s reconnect branch after clearing it.

**`LANGameClient.swift`**:
- `public func connectionEvents() -> AsyncStream<LANConnectionEvent>` — add
  `connectionEventContinuations`; in the message-handling switch, yield
  `.playerDisconnected(playerIndex:)` on `.playerDisconnected` (after updating
  `disconnectedPlayerIndices`), and `.playerReconnected(playerIndex:)` on `.playerJoined`
  when that index was previously in `disconnectedPlayerIndices`.

Both host and client now expose the same `connectionEvents()` shape, used to unify
CPU-takeover/reconnect UI regardless of role.

## 2. Shared utilities

**`kadi/Shared/Persistence/PlayerIdentityStore.swift`** (new): `UserDefaults`-backed
struct with `uid` (lazily generated `UUID` on first access, persisted forever), `name`
(get/set), `avatarIndex` (get/set), `hasCompletedSetup`.

**`kadi/Shared/Components/AvatarPickerView.swift`** (new):
- `AvatarCatalog`: static array of 8 `(symbol: String, tint: Color)` entries (SF Symbols
  like `person.crop.circle.fill`, `star.circle.fill`, `moon.stars.circle.fill`,
  `bolt.circle.fill`, `flame.circle.fill`, tinted with `KadiTheme.Colors.*`). **Index 0
  must render identically to today's hardcoded `OpponentSlotView` avatar** (same symbol +
  tint) so existing Phase 4a screens are visually unchanged.
- `AvatarView(avatarIndex:size:isHighlighted:)`: renders one avatar glyph.
- `AvatarPickerView(selectedAvatarIndex: Binding<Int>)`: 4-column grid of selectable
  avatars with accent-ring highlight on selection.

**`kadi/Shared/Components/LobbyPlayerRowView.swift`** (new): `LobbyPlayerRowView(name:,
avatarIndex:, isHost:, isYou:)` — avatar + name + "You"/"Host" `PillBadge`s, for lobby
rosters.

**`kadi/Shared/Components/OpponentSlotView.swift`** (edit): add `avatarIndex: Int = 0`
and `isCPUControlled: Bool = false` params (both defaulted so all Phase 4a call sites in
`SoloGameView` compile unchanged); render the avatar via `AvatarView` instead of the
hardcoded `Image(systemName:)`; show a small "CPU" `PillBadge` when `isCPUControlled`.

## 3. Navigation flow — new `kadi/Features/LAN/` folder

```
kadi/Features/LAN/
  LANSetupView.swift
  LANGameSession.swift
  LANHostLobbyView.swift + LANHostLobbyViewModel.swift
  LANJoinBrowserView.swift + LANJoinBrowserViewModel.swift
  LANGuestLobbyView.swift + LANGuestLobbyViewModel.swift
  LANGameView.swift + LANGameViewModel.swift
  Views/
    LANActionBar.swift
    ConnectionStatusBanner.swift
```

**`HomeView.swift`** (edit): replace the disabled `Button("LAN Multiplayer") {}` with
`NavigationLink { LANSetupView() } label: { Text("LAN Multiplayer") }
.buttonStyle(SecondaryButtonStyle())`.

**`LANSetupView`**: mirrors `SoloSetupView`'s layout. `TextField` for display name +
`AvatarPickerView`, both backed by/persisted to `PlayerIdentityStore()` (read `uid` once,
write `name`/`avatarIndex` live or on confirm). Two `NavigationLink`s: "Host Game" →
`LANHostLobbyView`, "Join Game" → `LANJoinBrowserView`, both disabled while name is empty.

**`LANHostLobbyViewModel`** (`@MainActor ObservableObject`): owns a
`LANGameHost(hostName:hostUid:hostAvatarIndex:rules:maxPlayers:)`. `start()` calls
`host.start(gameName:)`, subscribes to `lobbyUpdates()` → `@Published players: [Player]`,
and to `gameStateUpdates()` — first emission sets `didStartGame = true`. Exposes
`canStartGame` (`players.count >= 2`) and `startGame()` → `host.startGame()`.

**`LANHostLobbyView`**: shows lobby roster via `LobbyPlayerRowView`, host-only "Start
Game" button (`PrimaryButtonStyle`, disabled until `canStartGame`),
`.navigationDestination(isPresented: $viewModel.didStartGame)` → `LANGameView(role:
.host(viewModel.host), localPlayerIndex: 0, ...)`.

**`LANJoinBrowserViewModel`**: owns a `LANBrowser`, `discoveredHosts()` →
`@Published hosts: [DiscoveredHost]`. `join(_:)` calls
`LANGameClient.connect(to:name:uid:avatarIndex:)` → `@Published connectedClient:
LANGameClient?`.

**`LANJoinBrowserView`**: `List` of discovered hosts, tap to join,
`.navigationDestination(item: $viewModel.connectedClient)` → `LANGuestLobbyView(client:)`.

**`LANGuestLobbyViewModel`**: subscribes to `client.rosterUpdates()` →
`@Published players`, `client.gameStateUpdates()` (first emission → `didStartGame =
true`), `client.hostLostUpdates()` → `hostLost` (pre-game host loss = no
`GameState` to migrate from, so just alert + dismiss back to browser).

**`LANGuestLobbyView`**: roster display, "Waiting for host…",
`.navigationDestination(isPresented: $viewModel.didStartGame)` → `LANGameView(role:
.guest(viewModel.client), localPlayerIndex: ..., ...)`.

## 4. `LANGameSession` protocol — unify host/guest

**`kadi/Features/LAN/LANGameSession.swift`** (new):

```swift
protocol LANGameSession: Actor {
    func submitAction(_ action: GameAction) async throws
    func gameStateUpdates() -> AsyncStream<GameState>
    func connectionEvents() -> AsyncStream<LANConnectionEvent>
    var currentGameState: GameState? { get async }
}

extension LANGameHost: LANGameSession {
    func submitAction(_ action: GameAction) async throws { try await submitHostAction(action) }
}
extension LANGameClient: LANGameSession {
    func submitAction(_ action: GameAction) async throws { try await sendAction(action) }
}
```

`LANGameViewModel` holds `private var session: any LANGameSession` plus `isHostRole:
Bool` and `localPlayerIndex: Int`.

## 5. `LANGameViewModel`

**`kadi/Features/LAN/LANGameViewModel.swift`** (new), `@MainActor final class ...
ObservableObject`, mirroring `SoloGameViewModel`'s shape:

- `enum Role { case host(LANGameHost); case guest(LANGameClient) }`
- `enum MigrationState: Equatable { case none, hostLostPromoting, hostLostReconnecting, reconnectFailed }`
- `@Published private(set) var state: GameState`, `@Published var
  selectedCardIndices: Set<Int>`, `@Published var errorMessage: String?`,
  `@Published var disconnectedPlayerIndices: Set<Int>`, `@Published var migrationState`,
  `@Published var migrationMessage: String?`.
- Init takes `role`, `localPlayerIndex`, `initialState: GameState`, `rules: RuleSet`,
  `gameName: String` (needed for re-advertising during migration), and the local
  player's `identity` (uid/name/avatarIndex, for migration's `promoteToHost`/`reconnect`).
- `subscribe()`: one task pumps `session.gameStateUpdates()` into `state` (clearing
  `selectedCardIndices` on each update); another pumps `session.connectionEvents()` into
  `disconnectedPlayerIndices`; if guest, a third pumps `client.hostLostUpdates()` →
  `handleHostLost`.
- **Derived state** (mirrors `SoloGameViewModel`): `localPlayer`, `playableCards`,
  `playableIndices`, `canDeclareKadi`, `isLocalPlayerTurn`, `winner`.
- **Action methods** mirror `SoloGameViewModel`'s full surface (`toggleSelection`,
  `confirmPlaySelected`, `pass`, `drawStack`, `declareKadi`, `chooseSuit`, `makeDemand`,
  `respondToDemand`, `interceptSkip`, `declineIntercept`), all delegating to `private func
  perform(_ action: GameAction)`.
- **`perform(_:)`**: run `GameEngine.validateAction` locally for instant "Invalid Move"
  feedback (sets `errorMessage`, returns early on failure) but **does not mutate
  `state`**. On success, clear selection and `Task { try await session.submitAction(action) }`
  — `state` only updates from the next `gameStateUpdates()` broadcast (`stateDelta`/
  `gameStateFull`), for both host and guest. **No optimistic UI.** Rationale: guarantees
  host and guest always converge on the exact same broadcast `GameState`; the host's own
  `submitHostAction` → broadcast → `gameStateUpdates()` round trip is in-process (no real
  network hop), so the host sees near-instant updates while guests get LAN-latency
  updates (sub-10ms typically).
- **CPU-takeover signal**: `disconnectedPlayerIndices` populated purely from
  `connectionEvents()` (works identically for host and guest roles). `LANGameView` shows
  a "CPU" badge on the corresponding `OpponentSlotView`.
- **Host migration** (`handleHostLost(client:)`, called once from `hostLostUpdates()`):
  - If `client.isLowestSurvivingPlayerIndex()`: set `migrationState = .hostLostPromoting`,
    call `client.promoteToHost(gameName:rules:)`, swap `session` to the returned
    `LANGameHost`, set `isHostRole = true`, cancel+re-run `subscribe()` for the new
    session's streams, reset `migrationState = .none`. On failure → `.reconnectFailed`.
  - Else: set `migrationState = .hostLostReconnecting`, start a fresh `LANBrowser`,
    match a discovered host whose advertised name corresponds to `gameName`, call
    `client.reconnect(to:)` (existing client actor, resyncs via `.gameStateFull`),
    `migrationState = .none` on success. A 15s timeout with no match →
    `.reconnectFailed`, surfaced with a "Retry" action (`retryReconnect()`).
- `stop()`: cancels all subscription tasks and calls `host.stop()`/`client.stop()` as
  appropriate.

## 6. `LANGameView`

**`kadi/Features/LAN/LANGameView.swift`** (new) — structurally mirrors `SoloGameView`:
`ZStack` over `KadiTheme.tableFeltGradient`, opponent row (`OpponentSlotView` per
non-local player, passing `avatarIndex` and `isCPUControlled:
disconnectedPlayerIndices.contains(offset)`), turn indicator `PillBadge`
("Your Turn" / "X's Turn"), `GameTableView`, `PlayerHandView` for `localPlayer.hand`,
conditional `QuestionAnswerBanner`/`LANActionBar`, and the same phase-based `overlay`
switch reusing `SuitChoiceOverlay`/`DemandEntryOverlay`/`CardDemandOverlay`/
`SkipInterceptOverlay`/`GameOverOverlay` (all already parameter-only, no
`SoloGameViewModel` dependency — directly reusable).

Additions over `SoloGameView`:
- A `ConnectionStatusBanner` at the top, shown when `migrationMessage != nil`
  (`.hostLostPromoting`/`.hostLostReconnecting` show a spinner; `.reconnectFailed` shows
  an error icon + "Retry" button calling `viewModel.retryReconnect()`).
- `GameOverOverlay`'s `onPlayAgain`/`onBackToHome` both `dismiss()` back toward Home for
  v1 (no rematch flow — host would need to re-open a lobby; out of scope for 4b).

**`kadi/Features/LAN/Views/ConnectionStatusBanner.swift`** (new): simple
`HStack` — spinner or warning icon, message text, optional "Retry" button.

## 7. `LANActionBar`

**`kadi/Features/LAN/Views/LANActionBar.swift`** (new): identical structure/layout to
`Features/Game/Views/ActionBar.swift` but `@ObservedObject var viewModel:
LANGameViewModel` — "Play (N)", "Pass", "Draw Stack" (if `isDrawStackActive`), "Declare
Kadi" (if `canDeclareKadi`).

## File summary

**New**:
- `KadiNetworking/Sources/KadiNetworking/Session/LANConnectionEvent.swift`
- `kadi/Shared/Persistence/PlayerIdentityStore.swift`
- `kadi/Shared/Components/AvatarPickerView.swift`
- `kadi/Shared/Components/LobbyPlayerRowView.swift`
- `kadi/Features/LAN/LANSetupView.swift`
- `kadi/Features/LAN/LANGameSession.swift`
- `kadi/Features/LAN/LANHostLobbyView.swift` + `LANHostLobbyViewModel.swift`
- `kadi/Features/LAN/LANJoinBrowserView.swift` + `LANJoinBrowserViewModel.swift`
- `kadi/Features/LAN/LANGuestLobbyView.swift` + `LANGuestLobbyViewModel.swift`
- `kadi/Features/LAN/LANGameView.swift` + `LANGameViewModel.swift`
- `kadi/Features/LAN/Views/LANActionBar.swift`
- `kadi/Features/LAN/Views/ConnectionStatusBanner.swift`

**Edited**:
- `KadiNetworking/Sources/KadiNetworking/Session/LANGameHost.swift` — add
  `lobbyUpdates()`, `connectionEvents()`.
- `KadiNetworking/Sources/KadiNetworking/Session/LANGameClient.swift` — add
  `connectionEvents()`.
- `kadi/Shared/Components/OpponentSlotView.swift` — add `avatarIndex`/`isCPUControlled`
  params (defaulted, backward compatible).
- `kadi/Features/Home/HomeView.swift` — wire "LAN Multiplayer" button.

**Not touched**: `SoloGameView.swift`, `SoloGameViewModel.swift`,
`Features/Game/Views/ActionBar.swift`, all `KadiEngine` sources.

## Implementation order

1. KadiNetworking additions (`LANConnectionEvent`, `lobbyUpdates()`, `connectionEvents()`
   on both host and client) + unit tests using the existing in-memory-connection-pair
   pattern.
2. `PlayerIdentityStore`, `AvatarPickerView`/`AvatarCatalog`/`AvatarView`,
   `OpponentSlotView` edit, `LobbyPlayerRowView` — pure UI/persistence.
3. `LANSetupView` + `HomeView` edit (navigation entry point).
4. `LANGameSession` protocol + `LANGameViewModel` (core logic), with logic tests.
5. Lobby flows: `LANHostLobbyView`/VM, `LANJoinBrowserView`/VM, `LANGuestLobbyView`/VM.
6. `LANGameView` + `LANActionBar` + `ConnectionStatusBanner`.
7. Manual two-device verification (step 9 below).

## Verification

**Automated**:
- New `KadiNetworking` tests (`LobbyUpdatesTests.swift`, `ConnectionEventsTests.swift`)
  using `InMemoryMessageConnection.pair()`, same pattern as
  `LANGameHostClientTests`/`DisconnectAndCPUTakeoverTests`/`HostMigrationTests`: assert
  `lobbyUpdates()` grows as clients join, `connectionEvents()` fires
  `.playerDisconnected`/`.playerReconnected` on disconnect/reconnect for both host and
  client roles.
- `LANGameViewModelTests` (new test target if none exists for the `kadi` app, else add to
  existing): host-role and guest-role round trips (action → state update via broadcast),
  CPU-takeover signal via `connectionEvents()`, and the promotion branch of host
  migration (assert `migrationState` transitions and `session` swaps to the promoted
  `LANGameHost`). The reconnect-to-new-host branch depends on real
  Bonjour/UDP (`LANBrowser`) and is covered manually instead.
- Run `cd KadiNetworking && swift test` and the new app-level tests after each step.

**Manual** (two physical devices on the same Wi-Fi — iOS Simulators are unreliable for
Bonjour/UDP across instances):
1. Host flow: enter name/avatar on Device A, "Host Game" — verify persistence across
   relaunch.
2. Join flow: Device B discovers Device A's game, joins — verify live roster sync on
   both lobby screens.
3. "Start Game" navigates both devices to `LANGameView` with correct hands/avatars.
4. Play several turns alternating devices; verify state converges within ~1s; verify
   each phase overlay (suit choice, demand, card demand, skip intercept, game over)
   appears only for the acting player.
5. Force-quit/disconnect a guest mid-game — verify "CPU" badge appears on host within
   ~6s and CPU plays that seat; relaunch guest and rejoin — verify CPU badge clears and
   guest regains its seat via `gameStateFull` resync.
6. With a 3rd device joined, force-quit the host — verify the lowest-index surviving
   guest shows "Taking over as host…" then resumes normally as host, and the other
   guest shows "Searching for new host…" then reconnects via `gameStateFull`.
7. Simulate a failed reconnect (disable Wi-Fi during migration) — verify
   `.reconnectFailed` + "Retry" appears after ~15s and retry works once connectivity is
   restored.
