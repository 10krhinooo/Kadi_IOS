# Phase 4d-1: Profile/Settings + Shared Auth/Presence

## Context

Phase 4c added `Features/Online/` (Internet multiplayer) gated behind a
local, feature-owned `Features/Online/Auth/AuthViewModel`. `HomeView`'s
"Profile" entry was still disabled. Phase 4d (per the roadmap) covers all
remaining `docs/GAME_SPEC.md` §L social features — friends, DM chat, game
invites, leaderboard, profile, settings, presence. This first slice
(4d-1) covers the foundational pieces — the "Profile" tab itself
(Profile + Settings screens), making the auth session shared across
features, and wiring up RTDB presence — while the social-graph features
(friends/chat/invites/leaderboard) are deferred to 4d-2.

Scope decisions:
- Promote `AuthViewModel` from a `Features/Online/`-local view model to an
  app-wide `@EnvironmentObject` (owned by `kadiApp.swift`), since "Profile"
  needs the exact same signed-in session as "Online Multiplayer" and
  shouldn't force a second sign-in.
- `SocialHubView` lists all of §L's "Profile tab" destinations up front
  (Profile, Settings, Friends, Messages, Game Invites, Leaderboard) but only
  wires up Profile/Settings in this slice — the rest are visibly disabled
  placeholders so the nav structure doesn't change again in 4d-2.
- Presence (`PresenceService`, RTDB `/presence/{uid}`) is wired at app scope
  via a new `PresenceCoordinator`, not per-feature, since "online" status
  should reflect the whole app's foreground/signed-in state, not just one
  screen.

## 1. `Shared/Auth/AuthViewModel.swift` — promote to app scope

- Moved `Features/Online/Auth/AuthViewModel.swift` → `Shared/Auth/AuthViewModel.swift`
  (no behavioral changes — same `AuthState`/`start`/`stop`/`signIn`/
  `register`/`signInWithGoogle`/`resendVerification`/`reload`/`signOut` surface).
- `kadiApp.swift`: added `@StateObject private var authViewModel = AuthViewModel()`,
  injected via `.environmentObject(authViewModel)` on the root `HomeView`,
  and calls `authViewModel.start()` in a `.task`.
- `Features/Online/Auth/AuthView.swift`/`VerifyEmailView.swift` stay in
  `Features/Online/Auth/` (reused by both `OnlineRootView` and the new
  `SocialRootView` — no need to move them, they're stateless views taking
  `AuthViewModel`/`AuthUser` as parameters).
- `OnlineRootView` switched from owning its own `@StateObject AuthViewModel`
  to `@EnvironmentObject private var viewModel: AuthViewModel`.

## 2. `Features/Home/HomeView.swift` — enable "Profile"

Replaced the disabled `Button("Profile") {}` with a `NavigationLink` to
`SocialRootView()`, matching "Online Multiplayer"'s `NavigationLink` to
`OnlineRootView()`.

## 3. `Features/Social/SocialRootView.swift`

Entry point from `HomeView`. `@EnvironmentObject private var viewModel:
AuthViewModel`, switches on `authState` exactly like `OnlineRootView`:
- `.loading` → spinner
- `.signedOut` → `AuthView(viewModel:)`
- `.needsVerification` → `VerifyEmailView(viewModel:user:)`
- `.signedIn(let user)` → `SocialHubView(authUser: user)`

## 4. `Features/Social/SocialHubView.swift`

Links to `ProfileView`/`SettingsView` via `NavigationLink`. "Friends",
"Messages", "Game Invites", "Leaderboard" are `Button`s with
`.disabled(true)` + `.opacity(0.4)`, matching the existing disabled-button
convention from `HomeView` pre-4c — deferred to Phase 4d-2.

## 5. `Features/Social/Profile/` — `ProfileView.swift` + `ProfileViewModel.swift`

`ProfileViewModel` (`@MainActor ObservableObject`):
- `load(authUser:)`: seeds `displayName`/`avatarIndex` from
  `PlayerIdentityStore` if `hasCompletedSetup`, then
  `ProfileService.fetchProfile(uid:)` for `UserProfile` (stats + canonical
  name/avatar if local identity hasn't been set up yet).
- `save(authUser:)`: writes `identity.name`/`identity.avatarIndex`, then
  `ProfileService.ensureProfile(uid:displayName:email:avatarId:)` (merge
  upsert) and re-fetches.

`ProfileView`: `AvatarView` + editable display-name `TextField` +
`AvatarPickerView` (reusing `Shared/Components/AvatarPickerView` from Phase
4b), a stats section (`points`/`wins`/`losses`/`gamesPlayed`/`quits` from
`UserProfile`, shown once loaded), and a "Save" button.

## 6. `Features/Social/Settings/` — `SettingsView.swift` + `SettingsViewModel.swift`

`SettingsViewModel` (`@MainActor ObservableObject`):
- `load(uid:)`: takes the first emission of
  `PresenceService.observePresence(uid:)` to seed `customStatus`.
- `saveCustomStatus(uid:)`: `PresenceService.updatePresence(uid:customStatus:)`.

`SettingsView`: shows `authUser.email`, a "Sign Out" button
(`@EnvironmentObject AuthViewModel.signOut()`), and a "Status" section
(`TextField` + "Save Status" button).

## 7. `Shared/Session/PresenceCoordinator.swift`

`@MainActor final class PresenceCoordinator`, owned by `kadiApp.swift`:
- `handle(authState:)`: on `.signedIn`, calls
  `PresenceService.goOnline(uid:)` (idempotent — tracks `currentUid` to
  avoid redundant calls); on `.loading`/`.signedOut`/`.needsVerification`,
  calls `goOffline(uid:)` if previously online.
- `handleScenePhase(_:)`: `.active` → `goOnline`, `.background` → `goOffline`
  for the current `uid` (no-op if signed out).

`kadiApp.swift` wires both via `.onChange(of: authViewModel.authState)` and
`.onChange(of: scenePhase)`.

## 8. Incidental fixes bundled into this slice

- `Shared/Components/ExitGameButton.swift`: new `ViewModifier` +
  `.exitGameButton(onExit:)` — a leading toolbar `xmark.circle.fill` button
  with a confirm-before-leaving `.alert`. Applied to `SoloGameView`,
  `LANGameView`, and `OnlineGameView` (all three hide the system back button
  while `phase != .finished`, so this was previously the only way to leave
  a game early — now there's an explicit exit).
- `Features/Game/Views/SuitChoiceOverlay.swift`: replaced `Suit.symbol`
  emoji glyphs with SF Symbols (`suit.heart/diamond/club/spade.fill`, tinted
  via `KadiTheme.Colors.suitRed`/`suitBlack`) — emoji rendered as "?" tofu
  at the overlay's size on some simulators/devices.
- `KadiOnline/Sources/KadiOnline/Firebase/FirebaseBootstrap.swift`:
  `configure()` now also sets `GIDSignIn.sharedInstance.configuration =
  GIDConfiguration(clientID:)` from `FirebaseApp.app()?.options.clientID`
  (`#if canImport(UIKit)`) — Google Sign-In was previously left
  unconfigured, so `AuthViewModel.signInWithGoogle` would have failed at
  runtime. Also corrected stale `kadi-254` → `kadi-ios` project-name
  references in doc comments.

## Known limitations / deferred to 4d-2

- Friends/friend requests, blocks (`FriendsService`).
- DM chat (`ConversationService`).
- Game invites (`GameInviteService`).
- Leaderboard (`LeaderboardService`).
- Custom rule-set selection (`RuleSetService`) — still deferred from 4c/4d-1.
- QuickChat (`QuickChatService`) — in-game ephemeral chat, not part of the
  "Profile" tab; revisit when planning in-game UI additions.

## Verification

- `xcodebuild -project kadi.xcodeproj -scheme kadi -destination 'platform=iOS Simulator,name=iPhone 17' build`
  succeeds with the new `Features/Social/`, `Shared/Auth/`, and
  `Shared/Session/` sources picked up automatically (synchronized group).
- `cd KadiOnline && swift test` (and the emulator-backed suite) pass
  unchanged (no `KadiOnline` source changes beyond `FirebaseBootstrap`,
  which `FirebaseBootstrapTests.swift` already covers).
- Manual: sign in via "Online Multiplayer", then navigate to "Profile" and
  confirm no second sign-in is required (shared `AuthViewModel`); edit
  display name/avatar, save, and confirm it persists across app restarts
  (`/users/{uid}` + `PlayerIdentityStore`).
