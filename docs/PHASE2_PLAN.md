# Phase 2 — LAN Multiplayer (KadiNetworking package)

> **Status: COMPLETE.** Preserved verbatim as the approved plan that produced the
> `KadiNetworking` package, its test suite, and the `kadi.xcodeproj` wiring. See `plan.md`
> for current status and the Phase 3–6 roadmap. Two implementation deviations from this
> plan:
> - A new `Session/CpuActionResolver.swift` resolves a safe `GameAction` for a
>   CPU-controlled player: if `agent.chooseAction` fails `GameEngine.validateAction` (e.g.
>   an unplayable declared-Kadi chain involving a Joker), it falls back to
>   `agent.drawStackResponse` (if `state.isDrawStackActive`) or `agent.normalPlay`
>   otherwise, then `.pass`, then `.drawStack` as a last resort. `LANGameHost.nextCPUAction`
>   uses this resolver so the host never gets stuck on a CPU-controlled turn (including
>   while a draw stack is active, when `.pass` is always invalid).
> - `LANGameHost` also tracks `hostPlayerIndex` (not hardcoded to `0`) so
>   `submitHostAction` and disconnect/CPU-takeover work correctly after host migration.

## Context

Phase 1 produced `KadiEngine`, a pure Swift package with `GameState`/`GameAction`/`Player`
models (Codable, byte-for-bit compatible with the Dart wire format) and a host-authoritative
`GameEngine.validateAction`/`applyAction` API. The `kadi` SwiftUI app currently has no
networking and is just the default Xcode scaffold.

Phase 2's goal (per `plan.md` roadmap and `docs/GAME_SPEC.md` §J) is to build the LAN
multiplayer transport layer: TCP/NDJSON protocol, Bonjour + UDP-beacon discovery, and a
host-authoritative session layer that wraps `GameEngine`. This is a networking/protocol
phase only — SwiftUI screens for lobby/game UI come in Phase 4. The deliverable is a new,
independently-testable Swift package (`KadiNetworking`) plus integration tests, linked into
the `kadi` app target the same way `KadiEngine` already is.

**Design decisions confirmed with user:**
- Swift-app-to-Swift-app only for now — payload shapes for `playerJoined`,
  `playerDisconnected`, `hostTransfer`, `chat` (not pinned by `docs/GAME_SPEC.md` §K /
  `CodecTests.swift`) are designed freely, documented in this package's own docs, and can be
  revisited if Dart interop is needed later.
- Disconnected non-host players: host substitutes a `CpuAgent` (from `KadiEngine/CPU`) to
  play their turns until they reconnect (matched by `uid`).
- Host disconnect: lowest-`playerIndex` surviving client promotes itself to host
  (best-effort "host migration" — see Session Layer below for the handoff mechanism).

## New package: `KadiNetworking`

Sibling to `KadiEngine`, same platform targets (`iOS 17`, `macOS 14`), depends on
`KadiEngine` (path dependency) for `GameState`/`GameAction`/`Player`/`CpuAgent` etc., and
imports `Network` (system framework, no extra SPM dependency needed).

```
KadiNetworking/
├── Package.swift                  (depends on local KadiEngine package)
├── Sources/KadiNetworking/
│   ├── Protocol/
│   │   ├── NetworkMessageType.swift   (raw-String enum: gameStateFull, playerAction,
│   │   │                               stateDelta, playerJoined, playerDisconnected,
│   │   │                               hostTransfer, ping, pong, joinRequest, joinAck,
│   │   │                               gameStart, chat — matches §J `.name` values)
│   │   └── NetworkMessage.swift       (enum with one case per type + associated payload,
│   │                                   custom Codable producing/consuming
│   │                                   {"type":"...","payload":{...}}; payload structs:
│   │                                   JoinRequestPayload{name,uid,avatarIndex},
│   │                                   JoinAckPayload{playerIndex,players:[Player]},
│   │                                   PlayerJoinedPayload{playerIndex,player:Player},
│   │                                   PlayerDisconnectedPayload{playerIndex},
│   │                                   HostTransferPayload{newHostPlayerIndex,newHostUid},
│   │                                   ChatPayload{text,sender}; gameStateFull/stateDelta/
│   │                                   gameStart wrap GameState; playerAction wraps
│   │                                   GameAction; ping/pong have empty payload {})
│   ├── Framing/
│   │   └── NDJSONFramer.swift         (encode: JSON + "\n"; decode: incremental line
│   │                                   buffer that yields complete JSON lines from
│   │                                   arbitrary Data chunks)
│   ├── Transport/
│   │   ├── MessageConnection.swift    (protocol: send(NetworkMessage) async throws,
│   │   │                               an AsyncStream<NetworkMessage> for inbound
│   │   │                               messages, close())
│   │   ├── NWMessageConnection.swift  (concrete impl wrapping NWConnection +
│   │   │                               NDJSONFramer; used for both client-initiated
│   │   │                               and listener-accepted connections)
│   │   └── InMemoryMessageConnection.swift (paired in-memory impl for unit tests —
│   │                                   no real sockets)
│   ├── Discovery/
│   │   ├── LANAdvertiser.swift        (Bonjour: NWListener with NWParameters advertising
│   │   │                               service `_kadi._tcp`, TXT record `ip`; + UDP
│   │   │                               beacon sender broadcasting
│   │   │                               {"type":"kadi_beacon","name","port","ip"} to
│   │   │                               255.255.255.255:4499 every 2s)
│   │   ├── LANBrowser.swift           (NWBrowser for `_kadi._tcp` + UDP beacon listener
│   │   │                               on 4499; emits AsyncStream<DiscoveredHost>)
│   │   └── DiscoveredHost.swift       (struct: name, host (NWEndpoint), port, ip)
│   └── Session/
│       ├── ConnectedPlayer.swift      (struct: playerIndex, uid, name, avatarIndex,
│       │                               connection: MessageConnection?, isCPUControlled,
│       │                               cpuAgent: CpuAgent?)
│       ├── LANGameHost.swift          (actor — owns NWListener via LANAdvertiser,
│       │                               GameState, RuleSet, [ConnectedPlayer]; handles
│       │                               joinRequest→joinAck, gameStart broadcast,
│       │                               playerAction→validateAction/applyAction→
│       │                               stateDelta broadcast, 2s ping loop, disconnect→
│       │                               CPU takeover via CpuAgent, reconnect-by-uid,
│       │                               exposes snapshot for host-migration handoff)
│       └── LANGameClient.swift        (actor — connects via NWConnection, sends
│                                       joinRequest, handles joinAck/gameStart/
│                                       stateDelta/ping(→pong)/playerJoined/
│                                       playerDisconnected/hostTransfer/chat, exposes
│                                       AsyncStream<GameState> + AsyncStream<...> for
│                                       chat/roster, sends playerAction; on host-loss
│                                       (3 missed pings) re-browses via LANBrowser and
│                                       either promotes itself (if lowest surviving
│                                       playerIndex — becomes a LANGameHost seeded with
│                                       its last-known GameState/roster) or rejoins the
│                                       new host via joinRequest with its existing uid)
└── Tests/KadiNetworkingTests/
    ├── NDJSONFramerTests.swift        (chunked/partial-line reassembly, multiple
    │                                   messages per chunk)
    ├── NetworkMessageCodecTests.swift (literal-JSON round trips for every message
    │                                   type, mirroring CodecTests.swift style)
    ├── LANGameHostClientTests.swift   (loopback integration: NWListener on 127.0.0.1
    │                                   port 0 + real NWConnection client(s); full
    │                                   join→gameStart→playerAction→stateDelta flow,
    │                                   ping/pong, multi-client turn order)
    ├── DisconnectAndCPUTakeoverTests.swift (host detects disconnect, substitutes
    │                                   CpuAgent, game continues; player reconnects
    │                                   by uid and CPU control is released)
    └── HostMigrationTests.swift       (3-player loopback scenario: host connection
                                        closed, lowest-index client promotes to host
                                        and other client rejoins)
```

## Implementation notes

- **NDJSON framing**: `NWConnection.receive` delivers arbitrary-sized `Data` chunks, so
  `NDJSONFramer` must buffer and split on `\n`, handling partial lines across chunks and
  multiple lines in one chunk. Pure logic, fully unit-testable without sockets.
- **`NetworkMessage` Codable**: same `"type"`/`"payload"` discriminated-union pattern already
  used for `GameAction` in `KadiEngine/Sources/KadiEngine/Actions/GameAction.swift` — reuse
  that style for consistency. `gameStateFull`/`stateDelta`/`gameStart` payloads are the
  existing `GameState` (already Codable, wire-compatible). `playerAction` payload is the
  existing `GameAction`.
- **Host authority**: `LANGameHost` is the only place `GameEngine.applyAction` is called
  during a live LAN game. On `playerAction`, call `validateAction`; if it returns an error
  string, drop the message (no broadcast); otherwise `applyAction` (with `SystemRandomNumberGenerator`)
  and broadcast `stateDelta` (full `GameState`) to all connected players including the
  sender, per §J.
- **Heartbeat**: host runs a 2s repeating `ping` broadcast; `LANGameClient` replies `pong`
  immediately and tracks last-ping time, disconnecting itself after 6s of silence (3 missed
  pings), matching §J exactly.
- **CPU takeover**: on detecting a dropped `MessageConnection` for a non-host player, host
  marks that `ConnectedPlayer.isCPUControlled = true` and assigns a `CpuAgent` (default
  `MediumCpu` from `KadiEngine/CPU/CpuAgent.swift`); when it becomes that player's turn, host
  calls the CPU agent's decision methods to synthesize a `GameAction` and applies it exactly
  like a real `playerAction`. On reconnect (`joinRequest` with matching `uid`), clears
  `isCPUControlled`, reattaches the new connection, and sends `gameStateFull` to resync.
- **Host migration**: when `LANGameClient` decides the host is gone (6s ping timeout), it
  checks whether its own `playerIndex` is the lowest among players it last knew to be
  connected. If so, it stops being a client, becomes a `LANGameHost` seeded with its
  last-received `GameState` and roster (treating the old host's slot as CPU-controlled,
  same mechanism as any other disconnect), starts advertising via `LANAdvertiser`. If not
  the lowest index, it uses `LANBrowser` to find the newly-advertised host and sends
  `joinRequest` with its existing `uid` to resume its slot. This is best-effort for Phase 2;
  note in code/docs that true network partitions or near-simultaneous promotions aren't
  fully handled.

## Xcode project wiring

Add `KadiNetworking` as a second local Swift package dependency to `kadi.xcodeproj`,
mirroring the existing `KadiEngine` entries in `kadi.xcodeproj/project.pbxproj`:
- New `XCLocalSwiftPackageReference "KadiNetworking"` (relativePath `KadiNetworking`)
- New `XCSwiftPackageProductDependency` for product `KadiNetworking`
- Add to `packageReferences` and `packageProductDependencies` lists, and to the
  `Frameworks` build phase — same four edit points used for `KadiEngine` (lines ~10, ~30,
  ~73, ~104 of the current `project.pbxproj`).

No SwiftUI/app-code changes beyond linking the package — the app target doesn't consume
`KadiNetworking` yet (that's Phase 4).

## Verification

- `cd KadiNetworking && swift test` — all unit/integration tests above, including loopback
  TCP tests on `127.0.0.1` (no real network/mDNS required for these).
- Manually note in test output / docs which tests (Bonjour `_kadi._tcp` advertise/browse,
  UDP broadcast beacon) may be sandbox-restricted in CI and are best verified on a real
  device or two simulators on the same Mac.
- `xcodebuild -project kadi.xcodeproj -scheme kadi -destination 'platform=iOS Simulator,name=iPhone 17' build`
  to confirm the new package links cleanly into the app target.
- Update `plan.md` status section to mark Phase 2 done and describe the new
  package, following the same pattern Phase 1 used (`docs/PHASE2_PLAN.md` preserved as
  history, `plan.md` updated to reflect current status).
