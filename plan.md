# Kadi (Swift port)

Native Swift/SwiftUI rebuild of the Flutter "Kadi" card game, aiming for full feature
parity with the original (game engine, LAN + online multiplayer, Firebase, AI opponent,
admin panel, Cloud Functions). The full rules and wire-format contract are documented in
`docs/GAME_SPEC.md` (sections A–L) — that file is the canonical reference for every phase.

For the detailed plans that produced Phases 1–3a, see `docs/PHASE1_PLAN.md`,
`docs/PHASE2_PLAN.md`, and `docs/PHASE3A_PLAN.md`.

## Status

- **Phase 1 (done)**: `KadiEngine` Swift package — pure game engine (models, rules, deck
  building, turn-resolution engine, Kadi-validity DFS, CPU agents) plus a full unit-test
  suite, wired into the `kadi` Xcode app target.
- **Phase 2 (done)**: `KadiNetworking` Swift package — TCP/NDJSON protocol, Bonjour +
  UDP-beacon LAN discovery, and a host-authoritative `LANGameHost`/`LANGameClient` session
  layer (CPU takeover for disconnected players, reconnect-by-uid, lowest-index host
  migration), plus a full unit/integration-test suite, wired into the `kadi` Xcode app
  target.
- **Phase 3a (done)**: `KadiOnline` Swift package — Firebase setup (`FirebaseBootstrap`,
  prod + emulator configs), `AuthService`/`FirebaseAuthService` (Email/Password +
  Google Sign-In), `ProfileService` (`/users/{uid}` upsert), and the `/rooms`
  host-authoritative game-sync data model (`RoomService`, `RoomHost`, `RoomClient`)
  mirroring `LANGameHost`'s validate/apply/broadcast pattern over Firestore listeners,
  plus `firestore.rules`/`firestore.test.rules`/`firebase.json` and Xcode/SPM wiring
  (Firebase iOS SDK + GoogleSignIn-iOS) into the `kadi` app target. See
  `docs/PHASE3A_PLAN.md`. **Outstanding manual step**: `kadi/GoogleService-Info.plist`
  and the Google Sign-In URL scheme have not been added yet — `FirebaseApp.configure()`
  will crash at runtime until the plist is provided.
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
- **Phase 4–6 (not started)**: see Roadmap below.

## Project layout

```
kadi/                     (repo root)
├── CLAUDE.md             (architecture/instructions for Claude)
├── plan.md               (this file — status + roadmap, kept in sync with CLAUDE.md)
├── docs/
│   ├── GAME_SPEC.md       (canonical rules + wire-format reference, sections A–L)
│   ├── PHASE1_PLAN.md     (approved plan for Phase 1, preserved for history)
│   ├── PHASE2_PLAN.md     (approved plan for Phase 2, preserved for history)
│   └── PHASE3A_PLAN.md    (approved plan for Phase 3a, preserved for history)
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
├── firebase.json          (Firebase Local Emulator Suite config — Firestore + Auth + RTDB)
├── firestore.rules        (production Firestore security rules)
├── firestore.test.rules   (relaxed rules for emulator-driven tests)
├── database.rules.json    (production Realtime Database security rules)
├── database.test.rules.json (relaxed RTDB rules for emulator-driven tests)
├── kadi/                  (SwiftUI app target — depends on KadiEngine/KadiNetworking/KadiOnline + Firebase/GoogleSignIn SPM deps)
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
Swift package product (see `kadi.xcodeproj/project.pbxproj`).

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
- **Phase 4 — SwiftUI app**: feature modules mirroring the Flutter `lib/features/` tree
  (game, solo, online, multiplayer/LAN, lobby, friends, chat, profile, leaderboard,
  settings, onboarding, presence, auth, home, end), shared theme matching the Flutter app's
  documented palette/typography (Poppins, dark theme, exact hex colors/text styles).
- **Phase 5 — Admin app**: separate SwiftUI (macOS/iPadOS) project for campaign management,
  sharing the same Firebase project (`kadi-254`).
- **Phase 6 — Cloud Functions**: remain TypeScript (region `europe-west1`), same
  triggers — `onGameInviteCreated`, `onFriendRequestCreated`, `onDmMessageCreated`,
  `onCampaignCreated`/`processCampaigns` — plus FCM push token registration/delivery
  (deferred from Phase 3c), since token registration is only useful once these triggers
  exist to consume it.

### Open questions for later phases

- Audio/vibration/notifications and any Shorebird-equivalent (Shorebird is Flutter-specific
  for code-push updates; the Swift/iOS analog would be TestFlight or App Store
  Connect-based releases — no direct drop-in replacement). Defer to Phase 4+ and confirm
  with the user before picking an approach.
