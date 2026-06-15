# Phase 6: Cloud Functions + FCM Push Notifications

## Context

Per `CLAUDE.md`'s Roadmap, Phase 6 is TypeScript Cloud Functions (region
`europe-west1`) for `onGameInviteCreated`, `onFriendRequestCreated`,
`onDmMessageCreated`, plus FCM push token registration/delivery (deferred from
Phase 3c — token registration is only useful once these triggers exist to
consume it).

`onCampaignCreated`/`processCampaigns` depend on the `/campaigns` collection,
which only exists once Phase 5 (Admin app) is built — those are **deferred to
Phase 5** and not part of this phase.

This phase has two halves:
1. **Cloud Functions backend** (new `functions/` directory, Node 20 / TS,
   `firebase-functions` v2): three Firestore-create triggers that send FCM
   pushes to the recipient's registered device token(s), with automatic
   cleanup of stale tokens.
2. **iOS FCM wiring**: `FirebaseMessaging` SPM dependency, an `AppDelegate`
   (via `@UIApplicationDelegateAdaptor`) that requests notification
   permission and obtains an FCM token, a new `PushNotificationCoordinator`
   (mirroring `Shared/Session/PresenceCoordinator`) that registers/
   unregisters the token on `/users/{uid}` as auth state changes, and a new
   `fcmTokens: [String]` field on `UserProfile`/`ProfileService`.

## 1. `KadiOnline` — `fcmTokens` + token registration

- `Profile/UserProfile.swift`: added `public var fcmTokens: [String] = []`
  and a custom `init(from decoder:)` that decodes it via
  `decodeIfPresent(...) ?? []`, so existing `/users/{uid}` docs (written
  before this phase, with no `fcmTokens` key) still decode via `data(as:)`.
- `Profile/ProfileService.swift`: added `registerFCMToken(uid:token:)` →
  `setData(["fcmTokens": FieldValue.arrayUnion([token])], merge: true)` and
  `unregisterFCMToken(uid:token:)` → same with `FieldValue.arrayRemove`.
  `ensureProfile` is unaffected — `merge: true` leaves `fcmTokens` untouched
  on profile-refresh writes.
- `KadiOnlineTests/ProfileServiceTests.swift`: added
  `testRegisterAndUnregisterFCMToken`, an emulator-backed round-trip test via
  `fetchProfile`.

## 2. `KadiOnline/Package.swift` — `FirebaseMessaging` dependency

Added `.product(name: "FirebaseMessaging", package: "firebase-ios-sdk")` to
the `KadiOnline` target's dependencies.

## 3. iOS push registration — `kadi/Shared/Push/`

- **`PushTokenStore.swift`**: `final class PushTokenStore: ObservableObject`,
  singleton `static let shared`, `@Published var fcmToken: String?` — bridges
  the UIKit-side `MessagingDelegate` callback to SwiftUI.
- **`AppDelegate.swift`**: `final class AppDelegate: NSObject,
  UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate`
  — on launch, sets `Messaging.messaging().delegate`/
  `UNUserNotificationCenter.current().delegate`, requests
  `.alert/.sound/.badge` authorization, then calls
  `registerForRemoteNotifications()`; forwards the APNs device token to
  `Messaging.messaging().apnsToken`; sets `PushTokenStore.shared.fcmToken` on
  `didReceiveRegistrationToken`; and presents foreground notifications as
  `[.banner, .sound, .badge]`.
- **`PushNotificationCoordinator.swift`** (`@MainActor`, mirrors
  `PresenceCoordinator`): `handle(authState:token:)` — when `.signedIn` and a
  new (non-duplicate) token is available, calls
  `ProfileService().registerFCMToken`; on sign-out, if a token was
  registered, calls `unregisterFCMToken` best-effort.

## 4. `kadi/kadiApp.swift` wiring

Added `@UIApplicationDelegateAdaptor(AppDelegate.self)`,
`@StateObject private var pushTokenStore = PushTokenStore.shared`, and a new
`pushCoordinator: PushNotificationCoordinator`. `.onChange(of:
authViewModel.authState)` and `.onChange(of: pushTokenStore.fcmToken)` both
call `pushCoordinator.handle(authState:token:)`.

## 5. Entitlements + Info.plist (push capability)

- New `kadi/kadi.entitlements` with `aps-environment` = `development`.
- `kadi.xcodeproj/project.pbxproj`: for both Debug and Release configs of the
  `kadi` target, added `CODE_SIGN_ENTITLEMENTS = kadi/kadi.entitlements` and
  `INFOPLIST_KEY_UIBackgroundModes = "remote-notification"`.

## 6. `functions/` — Cloud Functions project

New top-level `functions/` directory (Node 20, TypeScript, `firebase-admin`/
`firebase-functions` v2, jest/ts-jest):

- `src/push.ts`: `sendPushToUser(uid, notification, data)` — reads
  `/users/{uid}.fcmTokens`, calls
  `admin.messaging().sendEachForMulticast({tokens, notification, data})`, and
  removes any token FCM reports as
  `messaging/registration-token-not-registered` via `FieldValue.arrayRemove`.
- `src/index.ts` — three `onDocumentCreated` triggers (region
  `europe-west1`):
  - `onFriendRequestCreated` (`/friendRequests/{id}`): "Friend Request" / "X
    sent you a friend request".
  - `onGameInviteCreated` (`/gameInvites/{id}`): "Game Invite" / "X invited
    you to a game", with `roomId` in `data`.
  - `onDmMessageCreated` (`/conversations/{convId}/messages/{id}`): looks up
    the sender's `displayName` from `/users/{senderUid}`, derives
    `recipientUid` from `convId.split('_')`, and sends `{title: senderName,
    body: text (truncated to 100 chars)}`.
- `src/push.test.ts`: jest unit tests for `sendPushToUser`'s multicast send
  and stale-token cleanup, with `firebase-admin` mocked.

## 7. `firebase.json`

Added `"functions": {"source": "functions"}` and a `functions` emulator port
(5001) alongside the existing `firestore`/`auth`/`database` emulators.

## Manual steps (not done by Claude — repo changes can't perform these)

- Upload an APNs Auth Key (`.p8`) to **Firebase Console → Project Settings →
  Cloud Messaging → Apple app configuration**, for `kadi-ios`.
- In the **Apple Developer portal**, enable the "Push Notifications"
  capability for the `com.victorkimanga.kadi` App ID, and ensure your
  provisioning profile/signing includes it.
- Run `firebase deploy --only functions` to deploy the new Cloud Functions to
  the live `kadi-ios` project.

## Verification

- `xcodebuild -project kadi.xcodeproj -scheme kadi -destination 'platform=iOS Simulator,name=iPhone 17' build`
  succeeds (push notifications themselves require a physical device — APNs
  doesn't work in the Simulator — but the registration code paths compile and
  run without crashing).
- `cd KadiOnline && npx firebase-tools@latest emulators:exec --only firestore,auth,database 'swift test --package-path KadiOnline'`
  — new `testRegisterAndUnregisterFCMToken` passes alongside the existing
  suite.
- `cd functions && npm install && npm run build && npm test && npm run lint`
  — all pass.
- Manual, on a physical device once the APNs key + Push Notifications
  capability are set up: sign in, confirm `/users/{uid}.fcmTokens` gains an
  entry; from a second account, send a friend request / game invite / DM and
  confirm a push notification arrives.
