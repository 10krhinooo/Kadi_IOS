# Phase 4c: Auth + Online Lobby + Game Screen (`KadiOnline` rooms)

## Context

Phases 1–3 built `KadiEngine` (pure game logic), `KadiNetworking` (LAN
multiplayer), and `KadiOnline` (Firebase: Auth, `/rooms` host-authoritative
sync, social/presence — mostly unused by the app so far). Phase 4a/4b built
the SwiftUI app shell, Solo (vs CPU), and LAN multiplayer
(`Features/LAN/`). Phase 4c is the Internet equivalent of the LAN flow, using
`RoomService`/`RoomHost`/`RoomClient` instead of
`LANGameHost`/`LANGameClient`, gated behind Firebase email/password auth
(`AuthService`/`FirebaseAuthService`).

`kadiApp.swift` previously had `import KadiOnline` and
`FirebaseBootstrap.configure()` commented out because
`kadi/GoogleService-Info.plist` didn't exist. This phase re-enables both —
the plist (project `kadi-ios`) was added as part of this phase.

Scope decisions:
- Email/Password auth only (no Google Sign-In — avoids extra Xcode
  URL-scheme setup; can be added later).
- Room joining is by 6-char room code (`RoomIdGenerator`), via a
  create-or-join screen (no host discovery, unlike LAN's Bonjour browser).

The `Features/Online/` flow mirrors `Features/LAN/`'s structure
(setup → host/guest lobby → unified game screen) wherever the underlying
APIs line up, reusing the same theme, identity store, avatar picker, and
game-view overlays.

## 1. `kadiApp.swift` — re-enable KadiOnline/Firebase

- Uncommented `import KadiOnline` and `FirebaseBootstrap.configure()` in
  `kadi/kadiApp.swift`.
- `kadi/GoogleService-Info.plist` added (project `kadi-ios`); since `kadi/`
  is a `PBXFileSystemSynchronizedRootGroup`, dropping the file in was
  sufficient — no `project.pbxproj` edits needed (it's auto-copied into
  the app bundle's `Resources`).
- The app's bundle identifier was also changed to `com.victorkimanga.kadi`
  (both Debug and Release configs in `kadi.xcodeproj/project.pbxproj`) to
  match the plist's `BUNDLE_ID`.
- The plist also includes `CLIENT_ID`/`REVERSED_CLIENT_ID` (Google Sign-In
  OAuth client). These aren't used by the email/password-only auth flow in
  this phase, but are harmless to include and let Google Sign-In be added
  later without re-downloading the plist.

## 2. `Features/Home/HomeView.swift` — enable "Online Multiplayer"

Replaced the disabled `Button("Online Multiplayer") {}` with a
`NavigationLink` to `OnlineRootView()`, matching the "LAN Multiplayer" entry.
"Profile" stays disabled (Phase 4d).

## 3. Auth layer — `Features/Online/Auth/`

### `AuthViewModel.swift`
`@MainActor final class AuthViewModel: ObservableObject`, wrapping
`AuthService` (`FirebaseAuthService()` by default):

```swift
enum AuthState: Equatable {
    case loading
    case signedOut
    case needsVerification(AuthUser)
    case signedIn(AuthUser)
}

@Published private(set) var authState: AuthState = .loading
@Published var errorMessage: String?

func start()                 // subscribes to authService.authStateChanges()
func signIn(email:password:) async
func register(email:password:displayName:) async
func resendVerification() async
func reload() async           // re-checks isEmailVerified, updates authState
func signOut()
```

`authStateChanges()` yields `AuthUser?`; `nil` → `.signedOut`, non-nil +
`!isEmailVerified` → `.needsVerification`, non-nil + verified →
`.signedIn`. Mirrors the `Task { for await ... }` + `[weak self]`
subscription pattern used in `LANHostLobbyViewModel`/
`LANGuestLobbyViewModel`.

### `AuthView.swift`
Sign In / Sign Up segmented form (email, password, display-name field shown
only for Sign Up). Uses `KadiTheme`/`PrimaryButtonStyle`/
`SecondaryButtonStyle` like `LANSetupView`.

### `VerifyEmailView.swift`
"We sent a verification link to {email}" message, "Resend email" button,
"I've Verified — Continue" button (`reload`), and "Sign out".

### `OnlineRootView.swift`
Entry point from `HomeView`. Owns `@StateObject AuthViewModel`, calls
`start()` on `.onAppear`, and switches on `authState`:
- `.loading` → spinner
- `.signedOut` → `AuthView`
- `.needsVerification` → `VerifyEmailView`
- `.signedIn(let user)` → `OnlineSetupView(authUser: user)`

## 4. `Features/Online/OnlineSetupView.swift`

Post-auth screen: name + avatar (reuse `PlayerIdentityStore` for
`name`/`avatarIndex`, persisted exactly like `LANSetupView`, but the
Firebase `authUser.uid` is used as the room player uid/profile uid, not
`identity.uid`). On appear, calls
`ProfileService().ensureProfile(uid: authUser.uid, displayName: identity.name, email: authUser.email, avatarId: identity.avatarIndex)`.

Two actions:
- **Create Room** → `RoomService().createRoom(hostUid:hostName:rules:)` →
  navigates to `OnlineHostLobbyView(roomId:, authUser:)`.
- **Join Room** → text field for a 6-char code →
  `RoomService().joinRoom(roomId:uid:name:)` → on success navigates to
  `OnlineGuestLobbyView(roomId:, localPlayerIndex:, authUser:)`; on
  `RoomServiceError` (`.roomNotFound`/`.roomFull`/`.roomAlreadyStarted`)
  shows an inline error.

Default `RuleSet()` for created rooms (custom rule-set selection via
`RuleSetService` is a Phase 4d concern, same as for LAN).

## 5. Host lobby — `OnlineHostLobbyView.swift` + `OnlineHostLobbyViewModel.swift`

Mirrors `LANHostLobbyViewModel`: observes `roomService.observeRoom(roomId)`
for the live roster, shows the room code for sharing, and on "Start Game"
creates a `RoomHost(roomId:hostUid:players:rules:)`, calls `startGame()` +
`startProcessingActions()`, and hands the running `RoomHost` to
`OnlineGameView`. On leaving before the game starts, deletes the room
(`roomService.deleteRoom`).

## 6. Guest lobby — `OnlineGuestLobbyView.swift` + `OnlineGuestLobbyViewModel.swift`

Mirrors `LANGuestLobbyViewModel`: observes `observeRoom(roomId)`; once
`status == .playing && gameState != nil`, captures `initialState` and the
caller-supplied `localPlayerIndex` (returned by `joinRoom`) and navigates to
`OnlineGameView`. If the room is deleted before the game starts (host left),
surfaces a "Room Closed" alert and pops back. On leaving before the game
starts, marks itself disconnected (`roomService.leaveRoom`).

## 7. Game screen — `OnlineGameView.swift` + `OnlineGameViewModel.swift`

Mirrors `LANGameView`/`LANGameViewModel` but **without host-migration** (no
equivalent in `KadiOnline` yet):

```swift
enum Role {
    case host(RoomHost)
    case guest(RoomClient)
}
```

`state` only ever updates from `roomService.observeRoom(roomId)`'s
`gameState` field — same "never mutate locally" convergence guarantee as
`LANGameViewModel`. `perform(_:)` validates via `GameEngine.validateAction`
for instant feedback, then submits via `host.submitHostAction(_:)` or
`client.submitAction(_:)`.

`OnlineGameView.swift` is a near-copy of `LANGameView.swift`: same
`OpponentSlotView`/`PillBadge`/`GameTableView`/`PlayerHandView`/overlay
switch (`SuitChoiceOverlay`/`DemandEntryOverlay`/`CardDemandOverlay`/
`SkipInterceptOverlay`/`QuestionAnswerBanner`/`GameOverOverlay`, all reused
unchanged from `Features/Game/Views/`), minus the `ConnectionStatusBanner`/
migration banner. `Player.avatarIndex` for opponents defaults to `0` (online
`RoomPlayer` doesn't carry an avatar — see Known Limitations).

### `Features/Online/Views/OnlineActionBar.swift`
Copy of `LANActionBar` retargeted at `OnlineGameViewModel` (same
Play/Pass/Draw Stack/Declare Kadi buttons).

## 8. Reused without changes

- `Shared/Persistence/PlayerIdentityStore`, `Shared/Components/AvatarPickerView`
  (`AvatarCatalog`/`AvatarView`/`AvatarPickerView`), `LobbyPlayerRowView`.
- `Features/Game/Views/*` overlays + `GameOverOverlay`, `GameTableView`,
  `PlayerHandView`, `OpponentSlotView`, `PillBadge`.
- `Theme/KadiTheme` (colors, typography, layout).
- `KadiOnline`: `FirebaseAuthService`, `AuthService`, `AuthUser`,
  `ProfileService`, `RoomService`, `RoomHost`, `RoomClient`, `RoomModels` —
  no `KadiOnline` package changes were needed.

## Known limitations / deferred to 4d

- **No CPU takeover / reconnect-by-uid for online** (unlike LAN's
  `LANGameHost` CPU substitution + host migration) — `RoomHost` has no
  equivalent yet. If the host disconnects mid-game, the room simply stops
  advancing; this is a pre-existing `KadiOnline` gap, not introduced here.
- **No avatar for online opponents** — `RoomPlayer` doesn't carry
  `avatarId`; `OpponentSlotView` shows the default avatar (index 0) for all
  online players. Adding `avatarId` to `RoomPlayer`/`RoomService` is a small
  follow-up if desired.
- Custom rule-set selection (`RuleSetService`), friends/invites/chat/
  leaderboard/profile/presence — all Phase 4d per the roadmap.

## Verification

- `xcodebuild -project kadi.xcodeproj -scheme kadi -destination 'platform=iOS Simulator,name=iPhone 17' build`
  succeeds with `KadiOnline` re-imported and `GoogleService-Info.plist`
  bundled.
- `cd KadiOnline && swift test` (and the emulator-backed suite) pass
  unchanged (no `KadiOnline` source changes).
- End-to-end multi-account play (two simulators/devices, create room +
  join by code through to `.finished`) is a manual follow-up once
  Email/Password sign-in is enabled for project `kadi-ios` in the Firebase
  console.
