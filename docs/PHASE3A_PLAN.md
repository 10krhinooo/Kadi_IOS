# Phase 3a — Firebase Setup, Auth, and `/rooms` Online Sync

## Context

Phase 1 (`KadiEngine`) and Phase 2 (`KadiNetworking`) are complete: pure game-engine
package + a host-authoritative TCP/NDJSON LAN session layer (`LANGameHost`/
`LANGameClient`). Phase 3 (per `CLAUDE.md`/`plan.md` roadmap) brings online multiplayer
via Firebase, per `docs/GAME_SPEC.md` §L. That spec covers a huge surface (auth,
rooms/game sync, friends, chat, presence, leaderboard, invites, reports). This plan
scopes **Phase 3a** to the core: Firebase setup, Auth (Email/Password + Google
Sign-In), `/users/{uid}` profile upsert, and the `/rooms` host-authoritative game-sync
data model — mirroring `LANGameHost`'s validate/apply/broadcast pattern but backed by
Firestore listeners instead of TCP.

**Explicitly deferred to Phase 3b**: `/users/{uid}/friends`, `/friendRequests`,
`/blocks`, `/conversations` + DM chat, `/gameInvites`, `/reports`, RTDB presence
(`/presence/{uid}`, `/quickChat`), leaderboard queries, saved ruleSets, FCM push.

**Decisions confirmed with user:**
- Reuse the **existing `kadi-254` Firebase project** (same backend as the Flutter app —
  matches the pinned Google Sign-In web client ID in §L, enables shared
  accounts/cross-play data from day one).
- Enable **Realtime Database now** (console-only step) even though no RTDB code ships
  until 3b.
- No `GoogleService-Info.plist` exists yet — manual console/Xcode steps below are
  prerequisites the user will do; code-skeleton work proceeds in parallel against the
  Firebase Local Emulator Suite (using a `demo-kadi` placeholder project ID, which
  needs no real credentials).

## Reference material

- `docs/GAME_SPEC.md` §L — `/rooms/{roomId}` shape (roomId = 6-char A-Z/2-9 excluding
  0/1/I/O), `actions`/`events`/`messages` subcollections, `/users/{uid}` shape +
  `ProfileService.ensureProfile()` semantics, Auth methods (Email/Password w/ mandatory
  verification, Google Sign-In w/ pinned web client ID
  `652988490285-d66ufeirui0qbhcoht8is7rn2b4utivc.apps.googleusercontent.com`).
- `docs/GAME_SPEC.md` §C/D/E/K — `GameState`/`Player`/`GameAction`/`RuleSet` Codable
  models (already wire-compatible with Dart; reused as-is, embedded in `Room.gameState`).
- `KadiEngine/Sources/KadiEngine/Engine/GameEngine.swift` —
  `validateAction(_:_:) -> String?`, `applyAction(_:_:using:) throws -> GameState`:
  the pure functions `RoomHost` calls, same as `LANGameHost`.
- `KadiNetworking/Sources/KadiNetworking/Session/LANGameHost.swift` — structural
  template for `RoomHost`'s validate/apply/write loop and turn-authorization checks
  (`isAuthorized`).
- `docs/PHASE2_PLAN.md` — style/structure template for this plan and for the
  `project.pbxproj` wiring pattern (4 edit points already used for `KadiNetworking`).
- `kadi.xcodeproj/project.pbxproj` — wiring target; `kadi/` is a
  `PBXFileSystemSynchronizedRootGroup` (files dropped in `kadi/` are auto-included).

## Manual prerequisites (user, outside Claude)

Can happen in parallel with code work (emulator-based dev needs no real project):

1. Confirm/obtain access to the existing **`kadi-254`** Firebase project (shared with
   the Flutter app).
2. Confirm **Firestore** is enabled (Native mode) — already true if Flutter app uses it.
3. Confirm **Auth providers** Email/Password + Google Sign-In are enabled, and that the
   pinned web client ID matches this project.
4. **Enable Realtime Database** now (per decision above), even if unused until 3b.
5. **Register an iOS app** in `kadi-254` (bundle ID must match `kadi.xcodeproj`'s
   `PRODUCT_BUNDLE_IDENTIFIER`).
6. **Download `GoogleService-Info.plist`** → place at `kadi/GoogleService-Info.plist`
   (auto-included via the synchronized group). Decide commit-vs-gitignore (default:
   commit, since it's not a security boundary — flag for confirmation).
7. **Add URL scheme** for Google Sign-In: `REVERSED_CLIENT_ID` from the plist as a
   `CFBundleURLTypes` entry (Xcode target Info settings) — manual GUI step once the
   plist exists.
8. **Author + deploy Firestore security rules** (drafted by Claude as `firestore.rules`
   + `firebase.json`; deployment via `firebase deploy --only firestore:rules` requires
   `firebase login`, done by user).
9. Install **`firebase-tools`** (Node/npm) locally for `firebase emulators:exec` (test
   workflow below).

## New package: `KadiOnline`

Sibling to `KadiEngine`/`KadiNetworking`; depends on `KadiEngine` (path dep) +
`firebase-ios-sdk` + `GoogleSignIn-iOS` (remote SPM deps).

```
KadiOnline/
├── Package.swift
├── Sources/KadiOnline/
│   ├── Firebase/
│   │   └── FirebaseBootstrap.swift     # FirebaseApp.configure() (prod, needs plist)
│   │                                    # + configureForTesting() (emulator, demo-kadi)
│   ├── Auth/
│   │   ├── AuthUser.swift              # uid, email, displayName, isEmailVerified, photoURL?, providerId
│   │   ├── AuthService.swift           # protocol: authStateChanges(), signIn, register,
│   │   │                                #   sendEmailVerification, reload, signInWithGoogle, signOut
│   │   └── FirebaseAuthService.swift   # concrete impl wrapping FirebaseAuth + GoogleSignIn
│   ├── Profile/
│   │   ├── UserProfile.swift           # Codable mirror of /users/{uid}
│   │   └── ProfileService.swift        # ensureProfile(): merge:true upsert, createdAt
│   │                                    #   + zeroed stats only on first write, never
│   │                                    #   touches points/wins/losses/gamesPlayed/quits after
│   ├── Rooms/
│   │   ├── RoomModels.swift            # Room, RoomPlayer, RoomStatus, RoomAction,
│   │   │                                #   RoomEvent, RoomMessage (Codable, embeds GameState/RuleSet)
│   │   ├── RoomIdGenerator.swift       # 6-char codes, alphabet "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
│   │   ├── RoomService.swift           # createRoom (collision-retry), joinRoom (transactional),
│   │   │                                #   leaveRoom, observeRoom/observeEvents/observeMessages,
│   │   │                                #   sendMessage, deleteRoom
│   │   ├── RoomHost.swift              # actor: snapshot-listens /actions ordered by timestamp,
│   │   │                                #   validateAction/applyAction, batched write
│   │   │                                #   (gameState + events[seq] + delete action),
│   │   │                                #   isAuthorized check (port from LANGameHost)
│   │   └── RoomClient.swift            # guest: submitAction() writes to /actions w/
│   │                                    #   serverTimestamp; observe* delegates to RoomService
│   └── Util/
│       └── FirestoreCodable.swift      # Encoder/Decoder config, Timestamp wrapper handling
└── Tests/KadiOnlineTests/
    ├── RoomIdGeneratorTests.swift      # charset, length, no 0/1/I/O, seeded RNG
    ├── RoomModelCodecTests.swift       # Room/RoomAction/RoomEvent/RoomMessage round trips,
    │                                    #   confirms embedded GameState still matches §K
    ├── ProfileServiceTests.swift       # emulator: createdAt+zeros only on first write,
    │                                    #   stats never overwritten after
    ├── RoomServiceTests.swift          # emulator: createRoom id validity+collision retry,
    │                                    #   joinRoom transactional append, full/started rejection
    ├── RoomHostSyncTests.swift         # emulator: seed room+state, write action doc as
    │                                    #   "guest", start RoomHost, assert gameState/events/
    │                                    #   action-deletion, ordering across multiple actions
    └── AuthServiceTests.swift          # Auth emulator: register+verification gating,
                                         #   sign-in, ensureProfile wiring (Google Sign-In
                                         #   itself not emulator-testable — stub/manual)
```

### `Package.swift` sketch

```swift
// swift-tools-version: 5.10
let package = Package(
    name: "KadiOnline",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "KadiOnline", targets: ["KadiOnline"])],
    dependencies: [
        .package(path: "../KadiEngine"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "8.0.0"),
    ],
    targets: [
        .target(name: "KadiOnline", dependencies: [
            "KadiEngine",
            .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
            .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
            .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
            .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS"),
        ]),
        .testTarget(name: "KadiOnlineTests", dependencies: ["KadiOnline"]),
    ]
)
```

**First task**: validate `swift package resolve` + a trivial `swift test` with just
`FirebaseFirestore`/`FirebaseCore` added before building real code — `GoogleSignIn-iOS`
may not resolve cleanly for plain macOS (`swift test`); if so, gate it behind
`#if os(iOS)` or split into an iOS-only target, and fall back to
`xcodebuild test -destination 'platform=iOS Simulator,...'` for that portion.

## Key implementation notes

1. **RoomId generation**: alphabet `"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"` (32 chars,
   power-of-two for unbiased sampling), 6 chars. `createRoom` generates a candidate,
   checks non-existence, retries on collision (cap ~10 attempts).

2. **Action processing order**: guests write `/rooms/{roomId}/actions/{autoId}` with
   `timestamp: FieldValue.serverTimestamp()`. `RoomHost` listens with
   `.order(by: "timestamp")`; pending (un-acked) writes from other clients aren't
   visible to the host's listener until committed, so ordering is reliable. Process
   docs one at a time: `validateAction` → if valid, `applyAction`, then one
   `WriteBatch`: update room doc's `gameState`, increment `eventSeq` field, add
   `/events/{autoId}` with that `seq`, delete the `/actions/{id}` doc. If invalid,
   still delete the action doc (don't reprocess) without touching `gameState`/`events`.

3. **Host authority / turn check**: port `LANGameHost.isAuthorized`-equivalent logic —
   verify `action.playerUid` maps (via `room.players`) to the player index `GameEngine`
   expects for that action, before calling `validateAction`.

4. **`gameState` as a nested map field**: full `GameState` JSON is well under
   Firestore's 1 MiB doc limit — store inline on the room doc per §L, no chunking.

5. **`/events` seq**: dedicated `eventSeq: Int` counter field on the room doc,
   incremented via `FieldValue.increment(1)` in the same batch as each events write.

6. **Room chat included in 3a**: `/rooms/{roomId}/messages` is a room subcollection per
   §L (not the deferred `/conversations` DM feature) and is trivial
   (`{senderUid, senderName, text, timestamp}`, append + `.order(by: timestamp)
   .limit(toLast: 200)`). Include `RoomService.sendMessage`/`observeMessages` now —
   no UI (Phase 4).

7. **`ProfileService.ensureProfile`**: `getDocument` → if `!exists`, include
   `createdAt: serverTimestamp()` + zeroed `points/wins/losses/gamesPlayed/quits` in
   the write; always include `displayName`, `displayNameLower` (lowercased),
   `email?`, `avatarId`, `lastSeen: serverTimestamp()`; `setData(merge: true)` — stat
   fields are never included on subsequent calls, so `merge:true` leaves them intact.

8. **Auth — verification gating**: `register()` calls `sendEmailVerification()`
   immediately. `AuthUser.isEmailVerified` is exposed via `authStateChanges()` /
   `reload()` so the app (Phase 4) can gate `/rooms` access behind a verify-email
   screen. Google accounts are pre-verified.

9. **Google Sign-In**: `signInWithGoogle(presentingViewController:)` takes a VC param
   (Phase 4 supplies it via SwiftUI bridge) — service-layer contract only in 3a, no UI.

10. **Firestore security rules** (`firestore.rules` + minimal `firebase.json`, drafted
    now, deployed by user later):
    - `/users/{uid}`: read if authed; write only by owner. Note stat fields are
      client-writable for now — flag as a Phase 6 (Cloud Functions) tightening item.
    - `/rooms/{roomId}`: read if authed; create only by `hostUid`; update by host or
      any `playerUids` member; delete only by host.
    - `/rooms/{roomId}/actions`: create only by the authenticated player for their own
      `playerUid`, must be in `playerUids`; read/delete only by host.
    - `/rooms/{roomId}/events`: read if authed; create only by host.
    - `/rooms/{roomId}/messages`: create by sender for own `senderUid`, `text` ≤ 500
      chars; read if authed; delete only by host.
    - Note as a known gap: rules don't yet restrict *which fields* of the room doc a
      non-host can update (e.g. a non-host could in principle write `gameState`) —
      field-level `affectedKeys()` restrictions are a follow-up hardening item before
      production traffic, not a 3a blocker for emulator-driven dev.

## Testing strategy — Firebase Local Emulator Suite

- `firebase emulators:exec --only firestore,auth 'swift test'` from `KadiOnline/` —
  requires `firebase-tools` + a `firebase.json` with emulator port config.
- `FirebaseBootstrap.configureForTesting()` uses `FirebaseOptions` with a `demo-kadi`
  placeholder project ID (no real credentials needed) + `useEmulator(withHost:port:)`
  for Firestore/Auth.
- Tests check `ProcessInfo.processInfo.environment["FIRESTORE_EMULATOR_HOST"]`; if
  unset, `throw XCTSkip(...)` rather than failing — so plain `swift test` (no emulator)
  doesn't hard-fail, while `RoomIdGeneratorTests`/`RoomModelCodecTests` (pure, no
  Firebase calls) always run.
- Google Sign-In is not emulator-testable — `AuthServiceTests` covers Email/Password +
  `ensureProfile` wiring only; Google path is manual/device-tested.
- No CI currently exists in this repo — emulator tests are local-only for now.

## Xcode project wiring

Mirror Phase 2's pbxproj edit pattern:

- **Local package `KadiOnline`**: add `XCLocalSwiftPackageReference` (relativePath
  `KadiOnline`), `XCSwiftPackageProductDependency` for product `KadiOnline`, plus
  `PBXBuildFile`/`packageReferences`/`packageProductDependencies`/Frameworks-phase
  entries — same 4 edit points as `KadiNetworking`.
- **Remote packages `firebase-ios-sdk`, `GoogleSignIn-iOS`**: new
  `XCRemoteSwiftPackageReference` entries (`upToNextMajorVersion` from `11.0.0` /
  `8.0.0`). Link `FirebaseCore` + `GoogleSignIn`/`GoogleSignInSwift` directly into the
  `kadi` app target (needed for `FirebaseApp.configure()` in `kadiApp.swift` and the
  presenting-VC sign-in flow); `FirebaseAuth`/`FirebaseFirestore` only need to be
  linked into `KadiOnline`. Flag: Firebase ships some products as binary XCFrameworks
  via SPM which may need explicit "Frameworks, Libraries, and Embedded Content" entries
  on the app target — verify by opening Xcode and checking for missing-symbol link
  errors after first build attempt.
- **`GoogleService-Info.plist`**: once provided, drop into `kadi/` — auto-included via
  the synchronized group, no pbxproj edit needed.
- **URL scheme / Info.plist**: manual Xcode-GUI step once the plist exists (the `kadi`
  target currently has no standalone `Info.plist`, likely uses
  `INFOPLIST_KEY_*` build settings) — document as a checklist item, not a blind edit.

## Implementation sequence

1. `KadiOnline/Package.swift` skeleton + `swift package resolve`/`swift test` risk
   check (Firebase + GoogleSignIn on macOS).
2. Pure models: `RoomModels`, `RoomIdGenerator`, `UserProfile` + codec/generator tests
   (no Firebase needed).
3. `FirebaseBootstrap` (prod + testing configs).
4. `ProfileService` + emulator tests.
5. `RoomService` (create/join/leave/observe/messages) + emulator tests.
6. `RoomHost`/`RoomClient` sync flow + `RoomHostSyncTests` (core deliverable).
7. `AuthService`/`FirebaseAuthService` (Email/Password fully tested; Google stubbed).
8. `firestore.rules` + `firebase.json` draft.
9. Xcode wiring (`KadiOnline` + Firebase + GoogleSignIn SPM deps); app-target
   `FirebaseApp.configure()` call in `kadiApp.swift` init.
10. Update `CLAUDE.md`/`plan.md`: mark 3a done, document emulator test command
    (`firebase emulators:exec ...`), carry forward the explicit Phase 3b deferred-items
    list (friends, friendRequests, blocks, conversations/DMs, gameInvites, reports,
    RTDB presence/quickChat, leaderboard, saved ruleSets, FCM).

## Verification

- `cd KadiOnline && firebase emulators:exec --only firestore,auth 'swift test'` — full
  suite incl. `RoomHostSyncTests` end-to-end flow.
- Plain `cd KadiOnline && swift test` — pure model/codec/generator tests pass via
  `XCTSkip` for emulator-dependent ones.
- `xcodebuild -project kadi.xcodeproj -scheme kadi -destination 'platform=iOS Simulator,name=iPhone 17' build`
  — confirms `KadiOnline` + Firebase + GoogleSignIn SPM resolve/link.
- Manual (post-`GoogleService-Info.plist`): launch app, confirm `FirebaseApp.configure()`
  doesn't crash; register an account, confirm verification email sent; create a room,
  confirm Firestore Console shows the §L shape exactly.
