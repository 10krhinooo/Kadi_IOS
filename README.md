# Kadi

A native Swift/SwiftUI rebuild of the Flutter "Kadi" card game, aiming for full
feature parity with the original: game engine, LAN + online multiplayer, Firebase
backend, AI opponents, admin panel, and Cloud Functions.

The full rules and wire-format contract live in [`docs/GAME_SPEC.md`](docs/GAME_SPEC.md)
(sections A–L) — the canonical reference for every phase of the rebuild. Project
status, architecture notes, and conventions are documented in
[`plan.md`](plan.md).

## Status

- **Phase 1 (done)** — `KadiEngine`: pure game engine (models, rules, deck building,
  turn-resolution engine, Kadi-validity DFS, CPU agents).
- **Phase 2 (done)** — `KadiNetworking`: TCP/NDJSON LAN multiplayer with
  Bonjour/UDP-beacon discovery, host-authoritative session layer (CPU takeover,
  reconnect-by-uid, host migration).
- **Phase 3a–3c (done)** — `KadiOnline`: Firebase setup, Auth (Email/Password +
  Google Sign-In), profiles, `/rooms` online multiplayer sync, social features
  (friends, chat, invites, reports, leaderboard, saved rule sets), and RTDB
  presence/quickChat.
- **Phase 4a–4d (done)** — Full SwiftUI app: Home/Solo (vs CPU), LAN multiplayer
  lobby + game, Online multiplayer (auth, lobby, game), and the Profile tab
  (profile/settings, friends, leaderboard, DM chat, game invites).
- **Phase 6 (done)** — Cloud Functions (friend request/game invite/DM push
  notifications) + FCM push token registration.
- **Phase 5 (not started)** — Admin app for campaign management. See the
  Roadmap in `plan.md`.

See `plan.md` for the detailed status writeup, architecture, and roadmap.

## Project layout

```
kadi/                     (repo root)
├── KadiEngine/            (Swift package — pure game logic)
├── KadiNetworking/        (Swift package — LAN multiplayer, depends on KadiEngine)
├── KadiOnline/            (Swift package — Firebase-backed online multiplayer)
├── kadi/                  (SwiftUI app target)
├── docs/                  (canonical game spec + per-phase plans)
└── kadi.xcodeproj/
```

## Commands

- Engine unit tests: `cd KadiEngine && swift test`
- Networking unit/integration tests: `cd KadiNetworking && swift test`
- Online (KadiOnline) unit + emulator tests (run from repo root):
  `npx firebase-tools@latest emulators:exec --only firestore,auth,database 'swift test --package-path KadiOnline'`
- App build: `xcodebuild -project kadi.xcodeproj -scheme kadi -destination 'platform=iOS Simulator,name=iPhone 17' build`

## Notes

- `kadi/GoogleService-Info.plist` is not checked in (see `.gitignore`). To build the
  app target, add your own Firebase iOS config file for the project at that path —
  `FirebaseBootstrap.configure()` in `kadi/kadiApp.swift` requires it.
