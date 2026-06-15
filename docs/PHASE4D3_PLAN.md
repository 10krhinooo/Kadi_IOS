# Phase 4d-3: DM Chat + Game Invites

## Context

Phase 4d-2 wired up Friends + Leaderboard, leaving "Messages" and "Game
Invites" as disabled placeholders on `SocialHubView`. This phase wires up
both, completing the "Profile" tab's full surface from
`docs/GAME_SPEC.md` §L.

`ConversationService` and `GameInviteService` already existed and were fully
tested in `KadiOnline` — no `KadiOnline` package changes were needed. This
phase is purely `kadi/Features/Social/` plus a small addition to
`Features/Online/OnlineHostLobbyView`/`OnlineHostLobbyViewModel`.

A shared `FriendPickerSheet` (`Features/Social/Friends/`) is reused by both
"New Message" (Messages) and "Invite Friend" (host lobby).

## 1. `Features/Social/Friends/FriendPickerSheet.swift`

A modal `.sheet` wrapping a `FriendsViewModel`: lists `friends` (avatar +
display name); tapping a row calls `onSelect(friend)` and dismisses. Empty
state points back at the Friends tab.

## 2. `Features/Social/Messages/`

`ConversationsViewModel` subscribes to
`ConversationService().observeConversations(uid:)` and lazily fetches
`UserProfile`s (via `ProfileService().fetchProfile(uid:)`) for each
conversation's other participant, caching them in `profiles: [String:
UserProfile]`.

`ConversationsListView` lists conversations (avatar, display name, last
message preview, unread-count `PillBadge`); "New Message" opens
`FriendPickerSheet` to start a new thread. Both existing-conversation taps
and friend picks navigate to `ChatView` via a `navigationDestination(item:)`
on a local `ChatTarget` (uid + display name).

`ChatViewModel` subscribes to `ConversationService().observeMessages(convId:)`
(`convId` computed via `ConversationService.conversationId(for:and:)`), calls
`markRead` on start, and sends via `sendMessage` (catching
`ConversationServiceError.messageTooLong`).

`ChatView` renders messages as left/right bubbles (mine = accent background,
right-aligned) with a `TextField` + "Send" button.

## 3. `Features/Social/Invites/`

`GameInvitesViewModel` subscribes to
`GameInviteService().observeIncomingInvites(uid:)`. `accept(_:authUser:)`
calls `RoomService().joinRoom(roomId:uid:name:)` (using
`PlayerIdentityStore().name`), sets `joinedRoom` (an `Identifiable` roomId +
playerIndex pair) to trigger `navigationDestination(item:)` →
`OnlineGuestLobbyView`, then deletes the invite. `decline(_:)` deletes the
invite via `GameInviteService().deleteInvite(inviteId:)`. Catches
`RoomServiceError.roomNotFound/.roomFull/.roomAlreadyStarted` into
`errorMessage`, mirroring `OnlineSetupView.joinRoom`.

`GameInvitesView` lists invites (`fromName` + Accept/Decline buttons).

## 4. `Features/Online/OnlineHostLobbyViewModel.swift` + `OnlineHostLobbyView.swift`

`OnlineHostLobbyViewModel.sendInvite(to: Friend)` calls
`GameInviteService().sendInvite(fromUid: authUser.uid, fromName:
PlayerIdentityStore().name, toUid: friend.uid, roomId: roomId)`.
`OnlineHostLobbyView` adds an "Invite Friend" button that presents
`FriendPickerSheet`, wiring the selected friend into `sendInvite(to:)`.

## 5. `Features/Social/SocialHubView.swift` + `SocialHubViewModel.swift`

`SocialHubViewModel` gained two more subscriptions alongside the existing
friend-request one: `observeConversations(uid:)` (summing
`unreadCounts[authUser.uid]` across conversations into
`unreadMessageCount`) and `observeIncomingInvites(uid:)` (`.count` into
`pendingInviteCount`), all started/stopped together.

"Messages" and "Game Invites" are now `NavigationLink`s to
`ConversationsListView(authUser:)`/`GameInvitesView(authUser:)`, each with a
`PillBadge` when their count is `> 0` (same pattern as "Friends").

## Verification

- `xcodebuild -project kadi.xcodeproj -scheme kadi -destination 'platform=iOS Simulator,name=iPhone 17' build`
  succeeds with the new `Features/Social/Messages/`, `Features/Social/Invites/`,
  and `Features/Social/Friends/FriendPickerSheet.swift` sources picked up
  automatically (synchronized group).
- `cd KadiOnline && swift test` unaffected (no package changes).
- Manual (two emulator/dev accounts, already friends): from account A's
  Messages, "New Message" → pick account B → send a message; confirm it
  appears on B's Messages with an unread badge, and reading it clears the
  badge. From account A, create an online room, "Invite Friend" → pick
  account B; confirm B's "Game Invites" shows the invite with a badge; B
  accepts → lands in `OnlineGuestLobbyView` for that room code; B declines →
  invite disappears.
