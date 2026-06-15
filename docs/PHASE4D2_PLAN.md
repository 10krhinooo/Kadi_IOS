# Phase 4d-2: Friends + Leaderboard

## Context

Phase 4d-1 built the "Profile" tab shell (`Features/Social/SocialHubView`)
with Profile/Settings wired up and Friends/Messages/Game Invites/Leaderboard
as disabled placeholders. This phase wires up **Friends** (friend requests,
friends list, blocks) and **Leaderboard**, the two pieces that are
self-contained within `Features/Social/` and don't require cross-feature
wiring into `Features/Online/`. DM chat and Game Invites (which need a
friend-picker and hooks into `OnlineHostLobbyView`) are deferred to Phase
4d-3.

All backend services already existed and are fully tested in `KadiOnline`
(`FriendsService`, `LeaderboardService`, `ProfileService`) — no `KadiOnline`
package changes were needed.

Since there's no user-search feature, friends are added by UID —
`ProfileView` gets a "Your ID" row (with a copy button) so users can share
their UID, mirroring the existing "share room code" pattern from
`Features/Online/` (no-discovery, code/UID-based).

## 1. `Features/Social/Friends/FriendsViewModel.swift`

`@MainActor final class FriendsViewModel: ObservableObject`, mirroring the
`Task { for await ... }` + `[weak self]` subscription pattern used by
`AuthViewModel`/`LANHostLobbyViewModel`. Subscribes to
`FriendsService().observeFriends(uid:)` /
`observeIncomingFriendRequests(uid:)` / `observeBlockedUsers(uid:)` via three
independent tasks (`start(authUser:)`/`stop()`).

Actions: `respond(to:accept:)`, `removeFriend(_:authUser:)`,
`block(_:authUser:)` (removes the friendship then blocks),
`unblock(_:authUser:)`, and `sendFriendRequest(authUser:)` — which trims
`addFriendUid`, rejects the user's own UID, calls
`ProfileService().fetchProfile(uid:)` to validate the target exists and grab
their `displayName`/`avatarId`, then
`FriendsService().sendFriendRequest(fromUid:fromName:fromAvatarId:toUid:)`
using the *sender's* own `PlayerIdentityStore` name/avatar. Catches
`FriendsServiceError.requestAlreadyPending` and "no such user" into
`errorMessage`.

## 2. `Features/Social/Friends/FriendsView.swift`

Sections (same `KadiTheme.backgroundGradient` + `ZStack` shell as
`ProfileView`/`SettingsView`):
- **Add Friend**: `TextField` for a UID + "Send Request" button.
- **Requests** (shown only if non-empty): avatar + name + Accept/Decline.
- **Friends**: avatar + name, with a context menu for "Remove Friend"/"Block".
- **Blocked** (shown only if non-empty): uid + "Unblock".

Empty-state copy for the friends list points back at the Profile "Your ID"
row. Error `.alert` matches `ProfileView`'s convention.

## 3. `Features/Social/Profile/ProfileView.swift` — "Your ID" row

New section below the stats: `authUser.uid` in a monospaced, truncated
`Text` plus a "Copy" button (`UIPasteboard.general.string`, behind
`#if canImport(UIKit)`).

## 4. `Features/Social/Leaderboard/`

`LeaderboardViewModel` (`@MainActor ObservableObject`): `load()` →
`LeaderboardService().fetchTopPlayers(limit: 50)` → `[UserProfile]`.

`LeaderboardView`: `List` of rank/avatar/name/points rows
(`.scrollContentBackground(.hidden)` to keep `KadiTheme`'s background),
highlighting the current user's row via `.listRowBackground`. `.task` to
load, `.refreshable` to reload.

## 5. `Features/Social/SocialHubView.swift` + new `SocialHubViewModel.swift`

- "Friends" and "Leaderboard" are now `NavigationLink`s to
  `FriendsView(authUser:)`/`LeaderboardView(authUser:)`. "Messages"/"Game
  Invites" remain disabled placeholders (Phase 4d-3).
- `SocialHubViewModel` (`@MainActor ObservableObject`) subscribes to
  `FriendsService().observeIncomingFriendRequests(uid:)` purely for a
  `pendingRequestCount`, shown as a `PillBadge` next to "Friends" when > 0.

## Known limitations / deferred to 4d-3

- No online/presence indicator on friend rows.
- No "Message" action on friend rows (DM chat is 4d-3).
- No way to send a game invite from the friends list (4d-3, needs
  `OnlineHostLobbyView` wiring).

## Verification

- `xcodebuild -project kadi.xcodeproj -scheme kadi -destination 'platform=iOS Simulator,name=iPhone 17' build`
  succeeds with the new `Features/Social/Friends/` and
  `Features/Social/Leaderboard/` sources picked up automatically
  (synchronized group).
- `cd KadiOnline && swift test` unaffected (no package changes).
- Manual (two emulator/dev accounts): from account A's Profile, copy UID;
  from account B's Friends screen, paste UID and send a request; on account
  A, accept it; confirm both accounts now show each other in "Friends" and
  the pending-request badge clears. Confirm Leaderboard lists both accounts
  ordered by `points`, with the signed-in account's row highlighted.
