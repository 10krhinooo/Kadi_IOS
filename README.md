# Kadi

A native Swift/SwiftUI rebuild of the Flutter "Kadi" card game, aiming for full
feature parity with the original: game engine, LAN + online multiplayer, Firebase
backend, AI opponents, admin panel, and Cloud Functions.

The full rules and wire-format contract live in [`docs/GAME_SPEC.md`](docs/GAME_SPEC.md)
(sections A–L) — the canonical reference for every phase of the rebuild. Project
status, architecture notes, and conventions for contributors (human or AI) are
documented in [`CLAUDE.md`](CLAUDE.md).

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
- **Phase 4a (done)** — SwiftUI app shell, theme, Home screen, and a full Solo
  (vs CPU) game screen.
- **Phase 4b (done)** — LAN lobby + multiplayer game screen, wiring up
  `KadiNetworking` (CPU-takeover and host-migration UI included).
- **Phase 4c–4d, 5, 6 (not started)** — see the Roadmap in `CLAUDE.md`.

See `CLAUDE.md` for the detailed status writeup, architecture, and roadmap.

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

- `kadi/GoogleService-Info.plist` is not checked in. `FirebaseBootstrap.configure()`
  is currently commented out in `kadi/kadiApp.swift` until that file is added — see
  `CLAUDE.md` for details.
