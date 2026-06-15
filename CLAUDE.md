# Kadi (Swift port)

Native Swift/SwiftUI rebuild of the Flutter "Kadi" card game, aiming for full feature
parity with the original (game engine, LAN + online multiplayer, Firebase, AI opponent,
admin panel, Cloud Functions). The full rules and wire-format contract are documented in
`docs/GAME_SPEC.md` (sections A–L) — that file is the canonical reference for every phase.

## Status

- **Phase 1 (done)**: `KadiEngine` Swift package — pure game engine (models, rules, deck
  building, turn-resolution engine, Kadi-validity DFS, CPU agents) plus a full unit-test
  suite, wired into the `kadi` Xcode app target.
- **Phase 2 (done)**: `KadiNetworking` Swift package — TCP/NDJSON protocol
  (`Network.framework`), Bonjour (`_kadi._tcp`) + UDP-beacon discovery, and a
  host-authoritative `LANGameHost`/`LANGameClient` session layer (CPU takeover for
  disconnected players, reconnect-by-uid, lowest-index host migration), plus a full
  unit/integration-test suite, wired into the `kadi` Xcode app target. See
  `docs/PHASE2_PLAN.md`.
- **Phase 3a (done)**: `KadiOnline` Swift package — Firebase setup (`FirebaseBootstrap`,
  prod + emulator configs), `AuthService`/`FirebaseAuthService` (Email/Password +
  Google Sign-In), `ProfileService` (`/users/{uid}` upsert), and the `/rooms`
  host-authoritative game-sync data model (`RoomService`, `RoomHost`, `RoomClient`)
  mirroring `LANGameHost`'s validate/apply/broadcast pattern over Firestore listeners,
  plus `firestore.rules`/`firestore.test.rules`/`firebase.json` and Xcode/SPM wiring
  (Firebase iOS SDK + GoogleSignIn-iOS) into the `kadi` app target. See
  `docs/PHASE3A_PLAN.md`. `kadi/GoogleService-Info.plist` (project `kadi-ios`) was added
  in Phase 4c.
- **Phase 3b (done)**: `KadiOnline` — the Firestore-only subset of the §L social
  surface deferred from 3a: `FriendsService` (`/users/{uid}/friends`,
  `/friendRequests`, `/blocks`), `ConversationService` (`/conversations` DM chat),
  `GameInviteService` (`/gameInvites`), `ReportService` (`/reports`),
  `LeaderboardService` (`/users` ordered by `points`), and `RuleSetService`
  (`/users/{uid}/ruleSets`), plus matching `firestore.rules` and a full
  emulator-backed test suite.
- **Phase 3c (done)**: `KadiOnline` — RTDB presence (`PresenceService`,
  `/presence/{uid}`, with an `onDisconnect()` handler) and quickChat
  (`QuickChatService`, `/quickChat/{roomId}/{uid}`), plus the new `FirebaseDatabase`
  SPM dependency, RTDB emulator wiring (`FirebaseBootstrap`, `firebase.json`,
  `database.test.rules.json`/`database.rules.json`), and a full emulator-backed test
  suite. FCM token registration/delivery remains deferred to Phase 6 (see Roadmap).
- **Phase 4a (done)**: First slice of the SwiftUI app — app shell, shared theme
  (`Theme/KadiTheme.swift`: dark "felt table" colors, typography, layout constants),
  reusable components (`Shared/Components/`: `PlayingCardView`, `PrimaryButtonStyle`/
  `SecondaryButtonStyle`, `PillBadge`, `PlayerHandView`, `OpponentSlotView`), a Home
  screen (`Features/Home/`) with a "Solo Play" entry point (LAN/Online/Profile stubbed,
  disabled), and a full Solo (vs CPU) game screen (`Features/Game/`:
  `SoloGameViewModel` driving `GameEngine`/`CpuAgent`, `SoloGameView` + phase overlays
  covering suit choice, demand entry, card demand, question-answer, skip-intercept, and
  game-over). Uses only `KadiEngine` — no networking/Firebase. See
  `docs/PHASE4A_PLAN.md`.
- **Phase 4b (done)**: LAN lobby + multiplayer game screen, wiring up
  `KadiNetworking`. `KadiNetworking` additions: `LANConnectionEvent`
  (`.playerDisconnected`/`.playerReconnected`), `LANGameHost.lobbyUpdates()`/
  `connectionEvents()`, `LANGameClient.connectionEvents()`. App additions:
  `Shared/Persistence/PlayerIdentityStore` (UserDefaults-backed uid/name/avatarIndex),
  `Shared/Components/AvatarPickerView` (`AvatarCatalog`/`AvatarView`/
  `AvatarPickerView`) and `LobbyPlayerRowView`, `OpponentSlotView` extended with
  `avatarIndex`/`isCPUControlled`, and a new `Features/LAN/` flow: `LANSetupView` →
  `LANHostLobbyView`/`LANJoinBrowserView` → `LANGuestLobbyView` → `LANGameView`, driven
  by `LANGameViewModel` (via the `LANGameSession` protocol unifying `LANGameHost`/
  `LANGameClient`) and `LANActionBar`/`ConnectionStatusBanner`, covering CPU takeover
  and full host-migration UI. `SoloGameView`/`SoloGameViewModel`/`ActionBar`/
  `KadiEngine` were not modified. See `docs/PHASE4B_PLAN.md`.
- **Phase 4c (done)**: Auth + online lobby + game screen, wiring up `KadiOnline`.
  Re-enabled `import KadiOnline` + `FirebaseBootstrap.configure()` in `kadiApp.swift`
  and added `kadi/GoogleService-Info.plist` (project `kadi-ios`; app bundle id changed
  to `com.victorkimanga.kadi` to match). New `Features/Online/` flow, gated behind
  Firebase email/password auth: `Auth/AuthViewModel`/`AuthView`/`VerifyEmailView` →
  `OnlineRootView` → `OnlineSetupView` (name/avatar via `PlayerIdentityStore`, "Create
  Room"/"Join Room by code") → `OnlineHostLobbyView`/`OnlineHostLobbyViewModel` or
  `OnlineGuestLobbyView`/`OnlineGuestLobbyViewModel` → `OnlineGameView`/
  `OnlineGameViewModel` (`@MainActor ObservableObject`, mirroring
  `LANGameViewModel`'s action surface over `RoomHost`/`RoomClient`) +
  `Views/OnlineActionBar`. "Online Multiplayer" on `HomeView` now navigates to
  `OnlineRootView`. No `KadiOnline` package changes were needed. See
  `docs/PHASE4C_PLAN.md`.
- **Phase 4d-1 (done)**: Profile/Settings + shared auth/presence plumbing for the
  "Profile" tab. `Features/Online/Auth/AuthViewModel` moved to `Shared/Auth/AuthViewModel`
  (an app-wide `@EnvironmentObject`, owned by `kadiApp.swift` and consumed by both
  `OnlineRootView` and the new `SocialRootView`) so the same signed-in session gates
  both "Online Multiplayer" and "Profile". New `Features/Social/` flow:
  `SocialRootView` (auth-gated like `OnlineRootView`) → `SocialHubView` (links to
  `Profile`/`Settings`, with Friends/Messages/Game Invites/Leaderboard stubbed as
  disabled "Phase 4d-2" placeholders) → `Profile/ProfileView`/`ProfileViewModel` (edit
  display name/avatar via `PlayerIdentityStore` + `ProfileService.ensureProfile`, view
  stats from `/users/{uid}`) and `Settings/SettingsView`/`SettingsViewModel` (sign out
  via `AuthViewModel`, edit custom status via `PresenceService.updatePresence`). New
  `Shared/Session/PresenceCoordinator` (owned by `kadiApp.swift`) calls
  `PresenceService.goOnline`/`goOffline` keyed off `AuthViewModel.AuthState` and
  `ScenePhase`. "Profile" on `HomeView` now navigates to `SocialRootView`. Also: new
  shared `Shared/Components/ExitGameButton` (`.exitGameButton(onExit:)` view modifier,
  a confirm-before-leaving toolbar button) applied to `SoloGameView`/`LANGameView`/
  `OnlineGameView`; SF Symbol suit icons in `SuitChoiceOverlay` (replacing emoji, which
  could render as tofu); and a `FirebaseBootstrap` fix that configures
  `GIDSignIn.sharedInstance.configuration` from the Firebase app's `clientID` (fixing
  Google Sign-In). No `KadiEngine`/`KadiNetworking` changes. See
  `docs/PHASE4D1_PLAN.md`.
- **Phase 4d-2 (done)**: Friends + Leaderboard, the two `Features/Social/` screens that
  don't need cross-feature wiring into `Features/Online/`. New
  `Features/Social/Friends/FriendsView`/`FriendsViewModel` (friend requests/friends
  list/blocks over `KadiOnline`'s `FriendsService`; friends are added by UID, no search)
  and `Features/Social/Leaderboard/LeaderboardView`/`LeaderboardViewModel`
  (`LeaderboardService.fetchTopPlayers`, current user's row highlighted).
  `ProfileView` gained a "Your ID" row (copy-to-clipboard) so users can share their UID
  to be added as a friend. `SocialHubView` now links to both screens and shows a
  `PillBadge` pending-friend-request count via new `SocialHubViewModel`. "Messages"/
  "Game Invites" remain disabled placeholders. No `KadiOnline` package changes were
  needed. See `docs/PHASE4D2_PLAN.md`.
- **Phase 4d-3 (done)**: DM chat + Game Invites, the last two `Features/Social/`
  screens. New `Features/Social/Messages/ConversationsListView`/
  `ConversationsViewModel` and `ChatView`/`ChatViewModel` over `KadiOnline`'s
  `ConversationService`, and `Features/Social/Invites/GameInvitesView`/
  `GameInvitesViewModel` over `GameInviteService` (accepting an invite calls
  `RoomService.joinRoom` and navigates to `OnlineGuestLobbyView`). New shared
  `Features/Social/Friends/FriendPickerSheet`, used by both "New Message" and a
  new "Invite Friend" button on `OnlineHostLobbyView`/`OnlineHostLobbyViewModel`
  (`GameInviteService.sendInvite`). `SocialHubView`'s "Messages"/"Game Invites" are
  now `NavigationLink`s with `PillBadge` unread/pending counts via extended
  `SocialHubViewModel`. No `KadiOnline` package changes were needed. See
  `docs/PHASE4D3_PLAN.md`.
- **Phase 6 (done)**: Cloud Functions (`functions/`, TypeScript, Node 20,
  `firebase-functions` v2, region `europe-west1`) + FCM push notifications.
  Three Firestore `onDocumentCreated` triggers — `onFriendRequestCreated`,
  `onGameInviteCreated`, `onDmMessageCreated` — call `sendPushToUser` (
  `functions/src/push.ts`), which reads `/users/{uid}.fcmTokens` and calls
  `admin.messaging().sendEachForMulticast`, removing any token FCM reports as
  `messaging/registration-token-not-registered`. `onCampaignCreated`/
  `processCampaigns` remain deferred to Phase 5 (depend on `/campaigns`).
  `KadiOnline` gained `UserProfile.fcmTokens: [String]` (decoded via
  `decodeIfPresent(...) ?? []` for backward compatibility) and
  `ProfileService.registerFCMToken`/`unregisterFCMToken`
  (`FieldValue.arrayUnion`/`arrayRemove`), plus the `FirebaseMessaging` SPM
  product. New `kadi/Shared/Push/`: `PushTokenStore` (`ObservableObject`
  bridging `MessagingDelegate` to SwiftUI), `AppDelegate`
  (`UIApplicationDelegate`/`UNUserNotificationCenterDelegate`/
  `MessagingDelegate` — requests notification authorization, registers for
  remote notifications, forwards the FCM token to `PushTokenStore`), and
  `PushNotificationCoordinator` (mirrors `PresenceCoordinator`; registers/
  unregisters the device's FCM token on `/users/{uid}` as
  `AuthViewModel.authState` changes), wired into `kadiApp.swift` via
  `@UIApplicationDelegateAdaptor`. New `kadi/kadi.entitlements`
  (`aps-environment`) + `INFOPLIST_KEY_UIBackgroundModes =
  "remote-notification"` on the `kadi` target. See `docs/PHASE6_PLAN.md` for
  the manual Firebase Console/Apple Developer/deploy steps required to
  actually receive pushes on a device.
- **Phase 5 (not started)**: see Roadmap below.

## Project layout

```
kadi/                     (repo root)
├── CLAUDE.md             (this file)
├── docs/
│   ├── GAME_SPEC.md       (canonical rules + wire-format reference, sections A–L)
│   ├── PHASE1_PLAN.md     (approved plan for Phase 1, preserved for history)
│   ├── PHASE2_PLAN.md     (approved plan for Phase 2, preserved for history)
│   ├── PHASE3A_PLAN.md    (approved plan for Phase 3a, preserved for history)
│   ├── PHASE4A_PLAN.md    (approved plan for Phase 4a, preserved for history)
│   ├── PHASE4B_PLAN.md    (approved plan for Phase 4b, preserved for history)
│   ├── PHASE4C_PLAN.md    (approved plan for Phase 4c, preserved for history)
│   ├── PHASE4D1_PLAN.md   (approved plan for Phase 4d-1, preserved for history)
│   ├── PHASE4D2_PLAN.md   (approved plan for Phase 4d-2, preserved for history)
│   ├── PHASE4D3_PLAN.md   (approved plan for Phase 4d-3, preserved for history)
│   └── PHASE6_PLAN.md     (approved plan for Phase 6, preserved for history)
├── KadiEngine/            (local Swift package — pure logic, no UIKit/SwiftUI/Firebase deps)
│   ├── Package.swift
│   ├── Sources/KadiEngine/
│   │   ├── Models/        (Card, RuleSet, Player, GameState)
│   │   ├── Actions/        (GameAction)
│   │   ├── Engine/         (DeckBuilder, GameEngine + extensions, KadiValidator)
│   │   └── CPU/            (CpuAgent + Easy/Medium/Hard/Adaptive)
│   └── Tests/KadiEngineTests/
├── KadiNetworking/        (local Swift package — TCP/NDJSON LAN multiplayer, depends on KadiEngine)
│   ├── Package.swift
│   ├── Sources/KadiNetworking/
│   │   ├── Protocol/       (NetworkMessageType, NetworkMessage)
│   │   ├── Framing/        (NDJSONFramer)
│   │   ├── Transport/       (MessageConnection, NWMessageConnection, InMemoryMessageConnection)
│   │   ├── Discovery/       (LANAdvertiser, LANBrowser, DiscoveredHost, LocalNetwork)
│   │   └── Session/         (LANGameHost, LANGameClient, ConnectedPlayer)
│   └── Tests/KadiNetworkingTests/
├── KadiOnline/            (local Swift package — Firebase-backed online multiplayer, depends on KadiEngine)
│   ├── Package.swift
│   ├── Sources/KadiOnline/
│   │   ├── Firebase/       (FirebaseBootstrap: prod + emulator configuration)
│   │   ├── Auth/           (AuthUser, AuthService protocol, FirebaseAuthService)
│   │   ├── Profile/         (UserProfile, ProfileService, SavedRuleSet, RuleSetService)
│   │   ├── Rooms/           (RoomModels, RoomIdGenerator, RoomService, RoomHost, RoomClient)
│   │   ├── Social/          (FriendModels, FriendsService — friends/friendRequests/blocks)
│   │   ├── Chat/            (ConversationModels, ConversationService — DM chat)
│   │   ├── Invites/         (GameInviteModels, GameInviteService)
│   │   ├── Reports/         (Report, ReportService)
│   │   ├── Leaderboard/     (LeaderboardService)
│   │   ├── Presence/        (PresenceModels, PresenceService — RTDB /presence/{uid})
│   │   └── QuickChat/       (QuickChatModels, QuickChatService — RTDB /quickChat/{roomId}/{uid})
│   └── Tests/KadiOnlineTests/  (incl. EmulatorTestCase + Firebase emulator-backed tests)
├── functions/             (Cloud Functions — TypeScript, Node 20, firebase-functions v2, Phase 6)
│   ├── package.json / tsconfig.json / jest.config.js
│   └── src/
│       ├── index.ts        (onFriendRequestCreated/onGameInviteCreated/onDmMessageCreated triggers)
│       └── push.ts          (sendPushToUser — FCM multicast + stale-token cleanup)
├── firebase.json          (Firebase Local Emulator Suite config — Firestore + Auth + RTDB + Functions)
├── firestore.rules        (production Firestore security rules)
├── firestore.test.rules   (relaxed rules for emulator-driven tests)
├── database.rules.json    (production Realtime Database security rules)
├── database.test.rules.json (relaxed RTDB rules for emulator-driven tests)
├── kadi/                  (SwiftUI app target — depends on KadiEngine/KadiNetworking/KadiOnline + Firebase/GoogleSignIn SPM deps)
│   ├── kadiApp.swift       (entry point; FirebaseBootstrap.configure() + HomeView)
│   ├── kadi.entitlements   (aps-environment, Phase 6)
│   ├── GoogleService-Info.plist (Firebase config for project kadi-ios)
│   ├── Theme/              (KadiTheme: colors, typography, layout constants)
│   ├── Shared/Components/  (PlayingCardView, PrimaryButton styles, PillBadge,
│   │                          PlayerHandView, OpponentSlotView, ExitGameButton)
│   ├── Shared/Persistence/ (PlayerIdentityStore)
│   ├── Shared/Auth/        (AuthViewModel — app-wide auth session, Phase 4d-1)
│   ├── Shared/Session/     (PresenceCoordinator, Phase 4d-1)
│   ├── Shared/Push/        (PushTokenStore, AppDelegate, PushNotificationCoordinator, Phase 6)
│   └── Features/
│       ├── Home/           (HomeView, SoloSetupView)
│       ├── Game/            (SoloGameView, SoloGameViewModel, Views/ phase overlays)
│       ├── LAN/             (LAN multiplayer flow, Phase 4b)
│       ├── Online/          (Online multiplayer flow, Phase 4c — Auth/, Views/)
│       └── Social/          (Profile tab, Phase 4d-1/4d-2/4d-3 — Profile/, Settings/,
│                               Friends/ (incl. FriendPickerSheet), Leaderboard/,
│                               Messages/, Invites/)
└── kadi.xcodeproj/
```

## Commands

- Engine unit tests: `cd KadiEngine && swift test`
- Networking unit/integration tests: `cd KadiNetworking && swift test`
- Online (KadiOnline) unit + emulator tests (run from repo root): `npx firebase-tools@latest emulators:exec --only firestore,auth,database 'swift test --package-path KadiOnline'`
- App build: `xcodebuild -project kadi.xcodeproj -scheme kadi -destination 'platform=iOS Simulator,name=iPhone 17' build`

## Architecture

`KadiEngine` is a pure, dependency-free Swift package: `GameState` is an immutable value
type, and `GameEngine.createGame` / `validateAction` / `applyAction` are pure
state-transition functions (RNG is injected via `inout some RandomNumberGenerator` for
determinism in tests). The `kadi` SwiftUI app target depends on `KadiEngine` as a local
Swift package product (see `kadi.xcodeproj/project.pbxproj`); as of Phase 4a it was the
only package the app's UI code consumed (`kadiApp.swift` was the sole file touching
`KadiOnline`, for `FirebaseBootstrap.configure()`) — as of Phase 4c, `Features/Online/`
also consumes `KadiOnline` directly (see below).

`KadiNetworking` is a host-authoritative LAN multiplayer layer built on `Network.framework`,
depending on `KadiEngine` as a local path dependency. `LANGameHost` is the only place
`GameEngine.applyAction` is called during a live LAN game; it broadcasts the full
`GameState` as `stateDelta` after every applied action (per `docs/GAME_SPEC.md` §J),
substitutes a `CpuAgent` for disconnected non-host players (reattaching by `uid` on
reconnect), and supports lowest-surviving-index host migration
(`LANGameHost(resumingState:roster:hostUid:rules:)` /
`LANGameClient.promoteToHost(gameName:rules:)`). Messages are framed as NDJSON
(`NDJSONFramer`/`NDJSONLineBuffer`) over `NWConnection`/`InMemoryMessageConnection`
(the latter for tests). `LANGameHost` additionally exposes `lobbyUpdates()` (roster
stream for lobby screens) and `connectionEvents()`/`LANGameClient.connectionEvents()`
(unified `LANConnectionEvent.playerDisconnected`/`.playerReconnected` stream for
CPU-takeover/reconnect UI on both host and guest). The `kadi` SwiftUI app target depends
on `KadiNetworking` as a local Swift package product and, as of Phase 4b, consumes it via
`Features/LAN/`.

The `kadi` SwiftUI app target (Phase 4a) is organized as `Theme/` (a `KadiTheme` namespace
of `Color`/`Font`/layout constants — dark "felt table" background, gold accent, red/black
suit colors, system/SF Pro typography), `Shared/Components/` (reusable views:
`PlayingCardView`, `PrimaryButtonStyle`/`SecondaryButtonStyle`, `PillBadge`,
`PlayerHandView`, `OpponentSlotView`), and `Features/<name>/` per-feature screens. The
`kadi/` directory is a `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), so new files/
folders created on disk are automatically part of the target's Sources — no
`project.pbxproj` edits needed when adding screens. `Features/Home/HomeView` is the root
view (set in `kadiApp.swift`), with "Solo Play" navigating to `SoloSetupView` →
`SoloGameView`, (as of Phase 4b) "LAN Multiplayer" navigating to `LANSetupView`, and (as
of Phase 4c) "Online Multiplayer" navigating to `OnlineRootView`; "Profile" remains
disabled until Phase 4d.
`Features/Game/SoloGameViewModel` (`@MainActor`, `ObservableObject`) owns the `GameState`
for a solo game (human always `players[0]`), drives `GameEngine.validateAction`/
`applyAction` for human actions, and runs CPU turns via `CpuAgent.chooseAction` (selected
via `CpuDifficulty` → `EasyCpu`/`MediumCpu`/`HardCpu`/`AdaptiveCpu`) on a short delay loop
that also re-checks for further CPU turns (e.g. double-King replays). `SoloGameView`
switches on `state.phase` to present phase-specific overlays
(`SuitChoiceOverlay`/`DemandEntryOverlay`/`CardDemandOverlay`/`QuestionAnswerBanner`/
`SkipInterceptOverlay`/`GameOverOverlay`) from `Features/Game/Views/`, covering the full
`docs/GAME_SPEC.md` §G phase surface. Hand-card selection is index-based
(`Set<Int>` into `humanPlayer.hand`), not `Set<PlayingCard>`, since `PlayingCard` equality
is on `(rank, suit)` and duplicate cards (jokers, multi-deck rule sets) would collide in a
Set.

`Features/LAN/` (Phase 4b) is the LAN multiplayer flow: `LANSetupView` (name +
`AvatarPickerView`, persisted via `Shared/Persistence/PlayerIdentityStore`) leads to
either `LANHostLobbyView`/`LANHostLobbyViewModel` (owns a `LANGameHost`, observes
`lobbyUpdates()`/`gameStateUpdates()`) or `LANJoinBrowserView`/`LANJoinBrowserViewModel`
(wraps `LANBrowser.discoveredHosts()`, connects via `LANGameClient.connect`) →
`LANGuestLobbyView`/`LANGuestLobbyViewModel` (observes `rosterUpdates()`/
`gameStateUpdates()`/`hostLostUpdates()`). Once a `GameState` is first emitted, both
flows navigate to `LANGameView`, which mirrors `SoloGameView`'s layout/overlay-switch
but is driven by `LANGameViewModel` (`@MainActor ObservableObject`, mirroring
`SoloGameViewModel`'s action surface) and `Features/LAN/Views/LANActionBar`.
`LANGameViewModel` holds `session: any LANGameSession` — `LANGameSession.swift` is a
small protocol unifying `LANGameHost`/`LANGameClient` (`submitAction`,
`gameStateUpdates`, `connectionEvents`, `stop`, `currentGameState`) so the view model
doesn't need to branch on host vs. guest for normal play. `perform(_:)` runs
`GameEngine.validateAction` locally for instant "Invalid Move" feedback but never
mutates `state` directly — `state` only updates from the next broadcast via
`session.gameStateUpdates()`, guaranteeing host/guest converge on identical state.
`disconnectedPlayerIndices` (driven by `connectionEvents()`) drives the "CPU" badge on
`OpponentSlotView` for any seat under CPU takeover, for both host and guest. Host
migration is handled in `LANGameViewModel.handleHostLost(client:)`, triggered by the
guest-only `client.hostLostUpdates()` stream: the lowest-surviving-index guest calls
`client.promoteToHost(gameName:rules:)` and swaps `session` to the returned
`LANGameHost` (`isHostRole` flips to `true`); other guests browse via a fresh
`LANBrowser` for a host re-advertising the same `gameName` (`"<host name>'s Game"`,
computed identically by `LANHostLobbyViewModel` and `LANGuestLobbyView`) and call
`client.reconnect(to:)`, with a 15s timeout surfaced as `.reconnectFailed` +
`retryReconnect()`. `ConnectionStatusBanner` renders `migrationMessage` for all of
these states. `SoloGameView`/`SoloGameViewModel`/`Features/Game/Views/ActionBar` and all
`KadiEngine` sources are untouched by Phase 4b.

`KadiOnline` is a Firebase-backed online multiplayer layer, depending on `KadiEngine` as
a local path dependency plus `firebase-ios-sdk` (FirebaseCore/Auth/Firestore) and
`GoogleSignIn-iOS` via remote SPM packages. `RoomHost` is the online analog of
`LANGameHost`: an actor that listens to `/rooms/{roomId}/actions` ordered by
`timestamp`, validates each action via `isAuthorized` + `GameEngine.validateAction`,
applies it via `GameEngine.applyAction`, and commits the result in a single
`WriteBatch` (updated `gameState`, an incremented `eventSeq`, a new `/events` doc, and
deletion of the processed `/actions` doc); invalid/unauthorized actions are deleted
without mutating state. `RoomClient` (guest side) and `RoomService`
(create/join/leave/observe/messages) provide the rest of the `/rooms` surface from
`docs/GAME_SPEC.md` §L. `ProfileService.ensureProfile` performs a `merge: true` upsert
of `/users/{uid}`, seeding `createdAt` and zeroed stats only on first write.
`FirebaseAuthService` wraps `FirebaseAuth` (Email/Password with mandatory verification)
and `GoogleSignIn` (iOS only, via `#if canImport(UIKit)`). `FirebaseBootstrap` configures
either the production Firebase project (via `kadi/GoogleService-Info.plist`) or the
Firebase Local Emulator Suite (`demo-kadi` placeholder project) for tests. The `kadi`
SwiftUI app target depends on `KadiOnline` as a local Swift package product and calls
`FirebaseBootstrap.configure()` from `kadiApp.swift`'s `init()`.

`Features/Online/` (Phase 4c) is the Internet equivalent of `Features/LAN/`, using
`RoomService`/`RoomHost`/`RoomClient` instead of `LANGameHost`/`LANGameClient`, gated
behind Firebase email/password auth. `Shared/Auth/AuthViewModel` (moved out of
`Features/Online/` in Phase 4d-1, see below; `@MainActor ObservableObject` wrapping
`FirebaseAuthService`, mirroring the `Task { for await ... }` + `[weak self]`
subscription pattern used by `LANHostLobbyViewModel`) exposes an `AuthState`
(`.loading`/`.signedOut`/`.needsVerification`/`.signedIn`) driving
`Features/Online/Auth/AuthView` (sign in/up)/`VerifyEmailView` (email-verification
gate)/`OnlineSetupView`, all owned by `OnlineRootView` (the "Online Multiplayer"
destination from `HomeView`). `OnlineSetupView` reuses
`PlayerIdentityStore`/`AvatarPickerView` for name/avatar (persisted as for LAN, but the
Firebase `authUser.uid` is used as the room player uid), calls
`ProfileService().ensureProfile(...)` on appear, and offers "Create Room" (
`RoomService().createRoom(hostUid:hostName:rules:)` → `OnlineHostLobbyView`) or "Join
Room" by 6-char code (`RoomService().joinRoom(roomId:uid:name:)` → `OnlineGuestLobbyView`,
with inline errors for `RoomServiceError.roomNotFound`/`.roomFull`/`.roomAlreadyStarted`;
no host-discovery browser, unlike LAN's Bonjour-based `LANJoinBrowserView`).
`OnlineHostLobbyViewModel`/`OnlineGuestLobbyViewModel` mirror their LAN counterparts,
observing `roomService.observeRoom(roomId:)` for the live roster and, once
`status == .playing`, navigating to `OnlineGameView`. `OnlineGameViewModel`
(`@MainActor ObservableObject`, mirroring `LANGameViewModel`'s action surface) holds a
`Role` (`.host(RoomHost)` or `.guest(RoomClient)`); `perform(_:)` runs
`GameEngine.validateAction` locally for instant feedback but `state` only ever updates
from `roomService.observeRoom(roomId:)`'s `gameState` field, the same "never mutate
locally" convergence guarantee as `LANGameViewModel`. `OnlineGameView` +
`Views/OnlineActionBar` are near-copies of `LANGameView`/`LANActionBar` reusing the same
`Features/Game/Views/*` overlays, minus `ConnectionStatusBanner`/host-migration UI
(`RoomHost` has no CPU-takeover/reconnect equivalent to `LANGameHost` yet — a known
gap, not introduced by Phase 4c). Online opponents always render with avatar index 0
(`RoomPlayer` doesn't carry an `avatarId`).

The remaining `docs/GAME_SPEC.md` §L social-feature services follow the same
raw-dict-write + `AsyncThrowingStream` snapshot-listener pattern as `RoomService`.
`FriendsService` manages `/users/{uid}/friends`, `/friendRequests` (with duplicate-pending
checks in both directions), and `/blocks/{uid}/blocked`; accepting a friend request
writes both sides of `/users/{uid}/friends` in one `WriteBatch`. `ConversationService`
implements DM chat at `/conversations/{convId}` (`convId` is the sorted-pair
`uidA_uidB`), where `sendMessage` batches a new `/messages` doc with a `setData(merge:
true)` update to the conversation doc that increments `unreadCounts.{recipientUid}` via
`FieldValue.increment`. `GameInviteService` writes `/gameInvites/{id}` with a
client-computed `expiresAt` `Timestamp` and filters expired invites client-side in
`observeIncomingInvites`. `ReportService.fileReport` is a write-only `addDocument` to
`/reports`. `LeaderboardService.fetchTopPlayers` queries `/users` ordered by `points`
descending (decoded via the existing `UserProfile` model). `RuleSetService` manages
`/users/{uid}/ruleSets`, encoding the embedded `RuleSet` via `Firestore.Encoder()`.
Models whose Firestore document ID is needed by callers (`FriendRequest`, `GameInvite`,
`SavedRuleSet`) use a plain `id: String?` field populated manually by the service layer
from `DocumentSnapshot.documentID` (not `@DocumentID`, to keep plain
`JSONEncoder`/`JSONDecoder` round-trips working for the wire-format codec tests).

`PresenceService` and `QuickChatService` are the `FirebaseDatabase` (RTDB) analogs of
the Firestore services above, covering the remaining `docs/GAME_SPEC.md` §L surface.
`PresenceService` manages `/presence/{uid}` (`status`/`customStatus`/`inGame`/`roomId`/
`lastSeen`): `goOnline` registers an `onDisconnectSetValue` handler (flips `status` to
`offline` if the client disconnects without calling `goOffline`) before writing
`status: "online"`; `goOffline` writes `status: "offline"` and cancels the disconnect
handler via `cancelDisconnectOperations`; `updatePresence` writes only the
non-nil fields passed in via `updateChildValues`. `QuickChatService` manages
`/quickChat/{roomId}/{uid}` (one ephemeral message slot per player): `sendQuickChat`
overwrites the player's slot via `setValue`, `clearQuickChat` removes the whole
`/quickChat/{roomId}` node (host calls this when the room closes). Both services use
`observe(.value, with:)` → `AsyncThrowingStream` (removing the observer via
`removeObserver(withHandle:)` in `onTermination`), the RTDB analog of the Firestore
`addSnapshotListener` pattern used elsewhere. RTDB's `ServerValue.timestamp()` resolves
server-side to epoch milliseconds, so `Presence.lastSeen`/`QuickChatMessage.timestamp`
are plain `Double?` (not `Date?`). `uid`/RTDB child keys are populated by the service
layer after `data(as:)` decoding, mirroring the Firestore `id: String?` convention
above.

`Shared/Auth/AuthViewModel` (Phase 4d-1) is now owned at app scope: `kadiApp.swift`
holds it as a `@StateObject` and injects it via `.environmentObject(authViewModel)` on
the root `HomeView`, so any feature can gate itself behind the same signed-in session
via `@EnvironmentObject`. `Features/Social/` (Phase 4d-1) is the "Profile" destination
from `HomeView`: `SocialRootView` switches on `AuthViewModel.authState` exactly like
`OnlineRootView` (reusing `Features/Online/Auth/AuthView`/`VerifyEmailView` for the
`.signedOut`/`.needsVerification` cases) and shows `SocialHubView` once
`.signedIn`. `SocialHubView` links to `Profile/ProfileView` (`ProfileViewModel`: loads
`/users/{uid}` via `ProfileService.fetchProfile`, edits display name/avatar via
`PlayerIdentityStore` + `AvatarPickerView`, saves via `ProfileService.ensureProfile`,
and renders the `points`/`wins`/`losses`/`gamesPlayed`/`quits` stats from
`UserProfile`) and `Settings/SettingsView` (`SettingsViewModel`: reads/writes
`customStatus` via `PresenceService.observePresence`/`updatePresence`, and a "Sign Out"
button calling `AuthViewModel.signOut()`); Friends/Messages/Game Invites/Leaderboard
were disabled placeholders in this slice (Friends/Leaderboard wired up in Phase 4d-2,
and Messages/Game Invites in Phase 4d-3, both below). `Shared/Session/PresenceCoordinator`
(Phase 4d-1, owned by `kadiApp.swift`) bridges `AuthViewModel.authState` and
`ScenePhase` to `PresenceService.goOnline`/`goOffline`: signing in (or foregrounding
while signed in) calls `goOnline`, signing out (or backgrounding) calls `goOffline`.
Also in Phase 4d-1: `Shared/Components/ExitGameButton` (`.exitGameButton(onExit:)`, a
leading toolbar button with a confirm-before-leaving alert) is applied to
`SoloGameView`/`LANGameView`/`OnlineGameView` (all of which hide the system back button
mid-game); `SuitChoiceOverlay` now renders SF Symbol suit icons
(`suit.heart/diamond/club/spade.fill`, colored via `KadiTheme.Colors.suitRed`/
`suitBlack`) instead of emoji glyphs; and `FirebaseBootstrap.configure()` now sets
`GIDSignIn.sharedInstance.configuration` from `FirebaseApp.app()?.options.clientID`,
fixing Google Sign-In (previously unconfigured).

`Features/Social/Friends/` and `Features/Social/Leaderboard/` (Phase 4d-2) round out
the "Profile" tab's self-contained screens. `FriendsViewModel` (`@MainActor
ObservableObject`, same three-stream `Task { for await ... }`/`start`/`stop` pattern as
`PresenceCoordinator`) subscribes to `FriendsService().observeFriends(uid:)`/
`observeIncomingFriendRequests(uid:)`/`observeBlockedUsers(uid:)` and drives
`FriendsView` (Add Friend by UID, incoming-request Accept/Decline, friends list with
Remove/Block context menu, blocked-users list with Unblock). Since there's no user
search, `sendFriendRequest(authUser:)` validates the target UID via
`ProfileService().fetchProfile(uid:)` before calling
`FriendsService().sendFriendRequest(fromUid:fromName:fromAvatarId:toUid:)` (using the
sender's own `PlayerIdentityStore` name/avatar) — `ProfileView` gained a "Your ID" row
(monospaced `authUser.uid` + copy-to-clipboard button) so users have something to
share. `LeaderboardViewModel`/`LeaderboardView` is a simple `LeaderboardService()
.fetchTopPlayers(limit:)` → ranked `List`, highlighting the signed-in user's row via
`.listRowBackground`. `SocialHubView` now has `NavigationLink`s to both screens plus a
new `SocialHubViewModel` that subscribes to `observeIncomingFriendRequests(uid:)` purely
to show a `PillBadge` request count next to "Friends"; "Messages"/"Game Invites" remain
disabled placeholders for Phase 4d-3.

`Features/Social/Messages/` and `Features/Social/Invites/` (Phase 4d-3) round out the
"Profile" tab. `ConversationsViewModel` subscribes to
`ConversationService().observeConversations(uid:)` and lazily resolves each
conversation's other participant via `ProfileService().fetchProfile(uid:)`, caching the
results in a `[String: UserProfile]` dictionary; `ConversationsListView` lists
conversations (avatar, name, last-message preview, unread `PillBadge`) and a "New
Message" button opens the new shared `Features/Social/Friends/FriendPickerSheet`
(wrapping `FriendsViewModel`, used for picking a friend to message or invite). Both an
existing conversation and a freshly-picked friend navigate to `ChatView` via
`navigationDestination(item:)`. `ChatViewModel` subscribes to
`ConversationService().observeMessages(convId:)` (`convId` from
`ConversationService.conversationId(for:and:)`), calls `markRead` on start, and sends
via `sendMessage` (catching `ConversationServiceError.messageTooLong`); `ChatView`
renders messages as left/right bubbles. `GameInvitesViewModel` subscribes to
`GameInviteService().observeIncomingInvites(uid:)`; `accept(_:authUser:)` calls
`RoomService().joinRoom(roomId:uid:name:)` (using `PlayerIdentityStore().name`) and sets
an `Identifiable` `joinedRoom` to drive `navigationDestination(item:)` →
`OnlineGuestLobbyView`, then deletes the invite; `decline(_:)` just deletes it via
`GameInviteService().deleteInvite(inviteId:)`. `OnlineHostLobbyViewModel` gained
`sendInvite(to: Friend)` (`GameInviteService().sendInvite(fromUid:fromName:toUid:roomId:)`
using `PlayerIdentityStore().name`), wired to a new "Invite Friend" button on
`OnlineHostLobbyView` that presents `FriendPickerSheet`. `SocialHubViewModel` gained two
more subscriptions (`observeConversations`/`observeIncomingInvites`) driving
`unreadMessageCount`/`pendingInviteCount` `PillBadge`s on "Messages"/"Game Invites",
which are now `NavigationLink`s like the other Social screens.

Phase 6 adds Cloud Functions + FCM push notifications. `UserProfile.fcmTokens:
[String]` (default `[]`, decoded via `decodeIfPresent(...) ?? []` for documents
written before this phase) and two new `ProfileService` methods,
`registerFCMToken(uid:token:)`/`unregisterFCMToken(uid:token:)`, manage
`/users/{uid}.fcmTokens` via `FieldValue.arrayUnion`/`arrayRemove`;
`ensureProfile`'s `merge: true` writes never touch this field. On the iOS side,
`kadi/Shared/Push/AppDelegate` (`UIApplicationDelegate`/
`UNUserNotificationCenterDelegate`/`MessagingDelegate`, installed via
`@UIApplicationDelegateAdaptor` in `kadiApp.swift`) requests notification
authorization, registers for remote notifications, and forwards both the APNs
device token (to `Messaging.messaging().apnsToken`) and FCM registration token
updates (to `PushTokenStore.shared.fcmToken`, an `ObservableObject` SwiftUI can
observe). `PushNotificationCoordinator` (mirroring `PresenceCoordinator`)
calls `registerFCMToken`/`unregisterFCMToken` as `AuthViewModel.authState` and
`PushTokenStore.fcmToken` change, deduplicating on the last-registered token.
`kadi/kadi.entitlements` (`aps-environment`) and
`INFOPLIST_KEY_UIBackgroundModes = "remote-notification"` on the `kadi` target
enable receiving pushes on a real device (not supported in the Simulator).

The new top-level `functions/` package (TypeScript, Node 20,
`firebase-functions`/`firebase-admin` v2, region `europe-west1`) hosts three
Firestore `onDocumentCreated` triggers — `onFriendRequestCreated`
(`/friendRequests/{id}`), `onGameInviteCreated` (`/gameInvites/{id}`), and
`onDmMessageCreated` (`/conversations/{convId}/messages/{id}`, where
`recipientUid` is derived from `convId.split('_')` and the sender's
`displayName` is looked up from `/users/{senderUid}`) — each calling
`sendPushToUser(uid, notification, data)` from `functions/src/push.ts`.
`sendPushToUser` reads `/users/{uid}.fcmTokens`, calls
`admin.messaging().sendEachForMulticast`, and removes any token FCM reports as
`messaging/registration-token-not-registered` via `FieldValue.arrayRemove`.
`onCampaignCreated`/`processCampaigns` remain deferred to Phase 5 (they depend
on the `/campaigns` collection the Admin app introduces).

## Wire-format fidelity rule

Any change to `Models/`, `Actions/GameAction.swift`, or any `Codable` conformance MUST keep
the JSON wire format byte-for-bit-compatible with the Dart `game_state_codec.dart` from the
Flutter app, since LAN peers and Firestore documents in later phases must interoperate with
it. The exact shapes (including quirks like `PlayingCard` always emitting `"suit"`, even as
`null`, and `GameState` redundantly encoding both `drawPileCount` and `drawPile`) are
documented in `docs/GAME_SPEC.md` §K. `KadiEngine/Tests/KadiEngineTests/CodecTests.swift`
contains round-trip and literal-JSON tests that pin this contract — extend it whenever the
wire format changes.

## Roadmap

- **Phase 3a — Firebase setup, Auth, `/rooms` online sync (done)**: see Status above
  and `docs/PHASE3A_PLAN.md`.
- **Phase 3b — Firestore social features (done)**: see Status above — friends/friend
  requests/blocks, DM conversations, game invites, reports, leaderboard, saved ruleSets.
- **Phase 3c — RTDB presence/quickChat (done)**: see Status above — `PresenceService`
  (`/presence/{uid}`, with `onDisconnect()`) and `QuickChatService`
  (`/quickChat/{roomId}/{uid}`), plus the `FirebaseDatabase` SPM dependency and RTDB
  emulator config.
- **Phase 4 — SwiftUI app**, split into sub-phases mirroring the Flutter `lib/features/`
  tree (game, solo, online, multiplayer/LAN, lobby, friends, chat, profile, leaderboard,
  settings, onboarding, presence, auth, home, end). There is no surviving Flutter source
  or documented visual design, so the theme (dark "felt table" palette, gold accent,
  system/SF Pro typography) was designed fresh in Phase 4a and should be reused/extended
  by later sub-phases rather than re-derived.
  - **Phase 4a (done)**: app shell, theme, Home screen, Solo (vs CPU) game screen
    (`KadiEngine` only). See Status above and `docs/PHASE4A_PLAN.md`.
  - **Phase 4b (done)**: LAN lobby + multiplayer game screen (`KadiNetworking`). See
    Status above and `docs/PHASE4B_PLAN.md`.
  - **Phase 4c (done)**: Auth + online lobby + game screen (`KadiOnline` rooms). See
    Status above and `docs/PHASE4C_PLAN.md`.
  - **Phase 4d-1 (done)**: Profile/Settings screens, shared app-wide `AuthViewModel`,
    and RTDB presence wiring (`PresenceCoordinator`). See Status above and
    `docs/PHASE4D1_PLAN.md`.
  - **Phase 4d-2 (done)**: Friends (friend requests/friends list/blocks,
    `FriendsService`) and Leaderboard (`LeaderboardService`), surfaced from
    `SocialHubView`'s previously-disabled placeholders. See Status above and
    `docs/PHASE4D2_PLAN.md`.
  - **Phase 4d-3 (done)**: DM chat (`ConversationService`, `Features/Social/Messages/`)
    and Game Invites (`GameInviteService`, `Features/Social/Invites/`), with a shared
    `FriendPickerSheet` and an "Invite Friend" button on `OnlineHostLobbyView` that
    accepts by joining the room and navigating to `OnlineGuestLobbyView`. See Status
    above and `docs/PHASE4D3_PLAN.md`.
- **Phase 5 — Admin app**: separate SwiftUI (macOS/iPadOS) project for campaign management,
  sharing the same Firebase project (`kadi-ios`). Will also add the
  `onCampaignCreated`/`processCampaigns` Cloud Functions triggers (deferred
  from Phase 6, since they depend on the `/campaigns` collection this phase
  introduces).
- **Phase 6 — Cloud Functions + FCM push (done)**: see Status above and
  `docs/PHASE6_PLAN.md`.

### Open questions for later phases

- Audio/vibration/notifications and any Shorebird-equivalent (Shorebird is Flutter-specific
  for code-push updates; the Swift/iOS analog would be TestFlight or App Store
  Connect-based releases — no direct drop-in replacement). Defer to Phase 4+ and confirm
  with the user before picking an approach.
