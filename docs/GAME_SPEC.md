# Kadi Game Spec & Wire-Format Reference

This document is the canonical specification for the Kadi game engine, networking protocols,
and Firebase data model. It is preserved verbatim from the original Flutter implementation's
project documentation ("Swift Port Reference" section) and is the authority for:

- Game rules and engine state transitions (sections A, B, C, D, E, F, G, H, I)
- LAN multiplayer wire protocol (section J)
- JSON wire format for `GameState`/`GameAction`/etc. (section K) — **the Swift `KadiEngine`
  package's `Codable` conformances must produce/consume JSON matching this exactly**, so that
  future LAN peers and Firestore documents remain interoperable with the existing Flutter app.
- Firestore/RTDB data model for online multiplayer (section L)

Any future phase (LAN networking, Firebase/online multiplayer, SwiftUI feature work, admin
app, Cloud Functions) should treat this document as the source of truth for behavior and data
shapes, rather than re-deriving them from the original Dart source.

---

This section is a self-contained specification of game logic, networking, and the Firebase data model, intended
to let someone reimplement Kadi (bit-for-bit equivalent rules engine + backend integration) in Swift without
needing to read the Dart source. Field names, enum values, and JSON shapes below are the **wire/serialization
contract** — match them exactly if the Swift client needs to interoperate with existing Firestore data / LAN peers
running the Flutter app.

### A. Card model (`PlayingCard`)

- `Rank` enum (raw values used in JSON via `.name`): `two, three, four, five, six, seven, eight, nine, ten, jack,
  queen, king, ace, joker`
- `Suit` enum: `hearts, diamonds, clubs, spades` — `nil` for Jokers
- `PlayingCard { rank: Rank, suit: Suit? }`, equality/hash on (rank, suit)
- Derived properties:
  - `isJoker` = rank == .joker
  - `isDrawCard` = rank ∈ {.two, .three} || isJoker
  - `isQuestionCard` = rank ∈ {.eight, .queen}
  - `isSkipCard` = rank == .jack
  - `isReverseCard` = rank == .king
  - `isAce` = rank == .ace
  - `isAceOfSpades` = rank == .ace && suit == .spades
  - `isRed` = suit ∈ {.hearts, .diamonds} (red Joker counts as red)
  - `isBlack` = suit ∈ {.clubs, .spades} (black Joker counts as black)
  - `isSpecial` = isDrawCard || isQuestionCard || isSkipCard || isReverseCard || isAce
  - `canEndGame` = true only for ranks four..ten and king (false for joker, jack, queen, eight, two, three, ace)
  - `drawValue` = 2 (two), 3 (three), 5 (joker), 0 otherwise
  - `rankLabel`: "2".."10", "J", "Q", "K", "A", "Joker"
  - `suitSymbol`: ♥️ ♦️ ♣️ ♠️ or "" for nil
  - `displayName`: e.g. "2♥️", "A♠️", "Red Joker", "Black Joker" (joker color from `suit`: hearts=red, clubs=black)

### B. RuleSet (all fields, defaults, JSON keys identical to field names)

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `aceOfSpadesEnabled` | Bool | true | A♠️ demands a specific rank+suit instead of just a suit |
| `jokersIncluded` | Bool | true | Include Red/Black Jokers in deck |
| `deckCount` | Int | 1 | Number of standard 52-card decks shuffled together |
| `cardsPerPlayer` | Int | 4 | Initial hand size |
| `startingCardReshuffle` | Bool | false | If first flipped card is special: true = reshuffle whole deck, false = put it back and draw next |
| `drawStackCap` | Int | 0 | Max accumulated draw stack (0 = uncapped) |
| `kadiPenalty` | Int | 0 | Extra cards drawn when a Kadi declaration is cancelled (0 = none, but a *false* Kadi win-attempt penalty defaults to 2 regardless) |
| `passAllowed` | Bool | true | Player may pass/draw 1 even if a valid play exists |
| `kingStackable` | Bool | true | Two Kings played together = double-reversal (direction unchanged, same player goes again) |
| `jackStackable` | Bool | true | Multiple Jacks played together skip that many players |
| `lateKadiDeclaration` | Bool | false | Grace window to declare Kadi after emptying hand, before next player acts (else instant 2-card penalty) |
| `turnTimerSeconds` | Int | 0 | Per-turn time limit (0 = none) |
| `jumpInterceptAllowed` | Bool | false | Skipped player(s) may intercept a Jack-skip with their own Jack(s), redirecting it from their position |
| `twosEnabled` | Bool | true | 2s trigger draw-2 |
| `threesEnabled` | Bool | true | 3s trigger draw-3 |
| `drawJumpAllowed` | Bool | false | Player facing a 2/3 draw may redirect with a Jack of the same suit as the triggering card |
| `jokerJumpAllowed` | Bool | false | Player facing a Joker draw may redirect with the Jack of Diamonds |
| `showOpponentCardCounts` | Bool | false | UI: show opponents' hand sizes |
| `hintLevel` | enum `none\|basic\|advanced` | `none` | UI hint verbosity |

### C. GameState

- `players: [Player]`
- `drawPile: [PlayingCard]`, `discardPile: [PlayingCard]` (top = last element)
- `currentPlayerIndex: Int`
- `rules: RuleSet`
- `direction: clockwise | anticlockwise` (default clockwise; clockwise = `+1 % n`, anticlockwise = `-1 mod n`)
- `pendingDrawCount: Int = 0` — accumulated draw stack from 2s/3s/Jokers
- `forcedSuit: Suit?` — suit constraint from a non-A♠️ Ace, or from an 8/Q question card
- `demandedCard: PlayingCard?` — exact card demanded via Ace of Spades / multi-Ace
- `kadiState: { declaringPlayerIndex: Int }?` — non-blocking active Kadi declaration
- `phase: GamePhase` (default `.playing`):
  - `playing` — normal turn
  - `suitChoice` — current player must choose a suit (after non-A♠️ Ace, or after 8/Q with no forced suit path... see engine logic)
  - `demandEntry` — A♠️ (or 2+ Aces) played; current player must call `MakeDemand(rank, suit)`
  - `cardDemand` — a demand is active; the next player must play the demanded card or counter with any Ace
  - `questionAnswer` — same player who played 8/Q must immediately play a card of `forcedSuit`, or pass
  - `skipIntercept` — blocking chain where queued players decide to intercept a pending skip
  - `finished` — game over
- `preSuitChoicePhase: GamePhase?` — phase to restore once `ChooseSuit` resolves
- `pendingSkipTarget: Int?` — legacy/likely-unused
- `winningCards: [PlayingCard] = []` — the cards played on the winning move (only set when `phase == .finished`)
- `kadiGracePeriodPlayerIndex: Int?` — when `lateKadiDeclaration` is on, the player who may still declare Kadi out-of-turn
- `skipInterceptQueue: [Int] = []`, `pendingSkipCount: Int = 0`, `skipOriginIndex: Int?`,
  `skipInterceptedBy: Set<Int> = []`, `skipInterceptGracePeriodPlayerIndex: Int?` — skip-intercept chain bookkeeping
  (see Engine §G "Jack / skip" below)
- Derived: `topCard = discardPile.last`, `currentPlayer = players[currentPlayerIndex]`,
  `isDrawStackActive = pendingDrawCount > 0`

### D. Player

- `id: String`, `name: String`, `hand: [PlayingCard]`, `isHuman: Bool`, `avatarIndex: Int = 0`
- `cardCount = hand.count`

### E. GameAction (discriminated union, `type` field in JSON)

| Type | Fields | Meaning |
| --- | --- | --- |
| `PlayCards` | `cards: [Card]` | Play one or more cards (validated as a chain) |
| `Pass` | — | Pass turn, draw 1 |
| `DrawStack` | — | Accept full `pendingDrawCount`, draw that many |
| `DeclareKadi` | `cards: [Card]` (may be empty) | Declare intent to win this/next turn, optionally playing the winning cards |
| `ChooseSuit` | `suit: Suit` | Pick next suit after a non-A♠️ Ace, or after 8/Q in suit-choice phase |
| `MakeDemand` | `rank: Rank` (≠ joker), `suit: Suit` | After A♠️/multi-Ace: name the exact card demanded |
| `RespondToDemand` | `card: Card?` | Play the demanded card, or `nil` to draw 1 instead |
| `RefuseDraw` | `ace: Card` | Use an Ace to cancel a pending draw stack |
| `RefuseSkip` | `jack: Card` | Cancel an incoming skip with another Jack (skip moves to *next* player instead) |
| `RefuseReverse` | `king: Card` | Cancel a King's reversal (direction stays the same) |
| `InterceptSkip` | `jacks: [Card]` (≥1) | Redirect a pending skip from the interceptor's position |
| `DeclineIntercept` | — | Decline the intercept opportunity |
| `JumpDraw` | `jack: Card` | Redirect a pending 2/3/Joker draw to the next player via a matching Jack |

### F. Deck construction & dealing (`DeckBuilder`)

- Build `deckCount` standard 52-card decks (all 4 suits × ranks two..ace); if `jokersIncluded`, add 2 Jokers per
  deck — Red Joker = `{rank: .joker, suit: .hearts}`, Black Joker = `{rank: .joker, suit: .clubs}`. Shuffle.
- Deal round-robin: `cardsPerPlayer` rounds, one card to each player per round, in player order.
- Starting card: pop cards off the deck until one with rank in `{4,5,6,7,8,9,10}` is found (these are the only
  ranks with `canEndGame == true` minus King... actually King is also valid to end but not as a starting card set —
  starting set is exactly four..ten). If a popped card is "special" (joker/J/Q/K/A/2/3): push it to the back of the
  remaining deck; if `startingCardReshuffle`, reshuffle the whole remaining deck before continuing. Throw if deck
  exhausted. Remaining deck (after removing the chosen starting card) becomes `drawPile`; `discardPile = [startCard]`.

### G. GameEngine — validation & state transitions

Engine is pure/stateless: `createGame`, `validateAction(state, action) -> ErrorMessage?`,
`applyAction(state, action) -> GameState` (throws `InvalidActionException` if `validateAction` returns non-nil).

**Shared helpers:**
- `isRuledDrawCard(card, rules)`: two→`twosEnabled`, three→`threesEnabled`, else `card.isDrawCard` (covers Jokers).
- `isValidPlay(card, state)`: Joker → always true; Ace → always true; else if `forcedSuit != nil` → `card.suit ==
  forcedSuit`; else if `topCard.isJoker` → `card.isRed == topCard.isRed`; else `card.suit == topCard.suit ||
  card.rank == topCard.rank`.
- `_drawCards(n)`: if `drawPile.count < n` and `discardPile.count > 1`, keep the top discard card aside, shuffle the
  rest of the discard pile into the draw pile, then draw `n` cards from the front.
- `_advanceTurn`: move `currentPlayerIndex` by ±1 per `direction` (wrapping), reset `phase = .playing`; if
  `lateKadiDeclaration`, open a grace window (`kadiGracePeriodPlayerIndex`) for the player whose turn just ended.

**`createGame(players, rules, rng?)`**: build deck, deal hands, pick starting card, return `GameState` with
`currentPlayerIndex = 0`, `direction = .clockwise`, `phase = .playing`, all special fields nil/empty/zero.

**`validateAction` rules per phase/action** — see exhaustive list below; **`applyAction`** then performs the
matching transition. Always: clear `kadiGracePeriodPlayerIndex` if action ≠ `DeclareKadi` (when
`lateKadiDeclaration`), and clear `skipInterceptGracePeriodPlayerIndex` if action ≠ `InterceptSkip`.

1. **`MakeDemand(rank, suit)`** — valid only if `phase == .demandEntry` and `rank != .joker`. Apply: set
   `demandedCard = Card(rank, suit)`, `phase = .cardDemand`, advance turn.

2. **`PlayCards(cards)`** — validation:
   - `cards` non-empty; not allowed during `.suitChoice`/`.demandEntry` (must resolve those first).
   - During `.cardDemand`: only a single Ace (counter) or exactly the `demandedCard` is allowed.
   - All `cards` must be in the current player's hand.
   - During `.questionAnswer`: first card's suit must equal `forcedSuit`.
   - If `isDrawStackActive`: every card must be `isRuledDrawCard` or an Ace; if stacking a draw card onto a Joker
     top card, its `isRed` must match the Joker's `isRed`.
   - First card (unless answering a question) must satisfy `isValidPlay`.
   - For multi-card plays: if draw-stack-active, all cards in the chain must share the same `rank`; otherwise each
     subsequent card must match the previous by suit OR rank.

   Apply (`_applyPlayCards`, also used by `DeclareKadi` and `RespondToDemand`):
   1. Remove `cards` from hand, append to `discardPile`. Clear `forcedSuit` and `demandedCard`.
   2. **Hand now empty** → win check:
      - If this was a `DeclareKadi` play, OR `kadiState?.declaringPlayerIndex == currentPlayerIndex`: `phase =
        .finished`, `pendingDrawCount = 0`, `winningCards = cards`. Done.
      - Else (no valid declaration): apply false-Kadi penalty — draw `max(2, rules.kadiPenalty)`... *(engine uses 2
        as the hardcoded default penalty; `rules.kadiPenalty` is the additional penalty applied when an active
        declaration is cancelled — see step 3)* — then `_advanceTurn`. Done.
   3. If `kadiState?.declaringPlayerIndex == currentPlayerIndex` but hand is non-empty: declaration is cancelled
      (`kadiState = nil`); if `rules.kadiPenalty > 0`, draw that many extra cards.
   4. **Last played card is a ruled draw card:**
      - If `isDrawStackActive` already (stacking): `pendingDrawCount += lastCard.drawValue`, capped at
        `drawStackCap` if >0; `_advanceTurn`. Done.
      - Else (opening a new stack): `pendingDrawCount = sum(drawValue for each draw card in the played chain)`,
        capped if `drawStackCap > 0`; `_advanceTurn`. Done.
   5. **Last card is a question card (8 or Q):** `phase = .questionAnswer`, `forcedSuit = lastCard.suit`,
      `pendingDrawCount = 0`. Same player acts again. Done.
   6. **Phase was `.cardDemand` and last card is an Ace** (counter play): `demandedCard = nil`, `forcedSuit =`
      (the suit that was demanded), `phase = .playing`, `_advanceTurn`. Done.
   7. **Last card is an Ace and `isDrawStackActive`** (refusing the stack by playing it as part of the chain):
      `pendingDrawCount = 0`; if the Ace is A♠️ or 2+ Aces were played → `phase = .suitChoice`,
      `preSuitChoicePhase = .playing` (no turn advance); else `_advanceTurn`. Done.
   8. **2+ Aces played (no draw stack active):** `phase = .demandEntry`, `pendingDrawCount = 0` (current player will
      call `MakeDemand`). Done.
   9. **Single A♠️ played and `rules.aceOfSpadesEnabled`:** `phase = .demandEntry`, `pendingDrawCount = 0`. Done.
   10. **Any other single Ace:** `phase = .suitChoice`, `preSuitChoicePhase = ` current phase, `pendingDrawCount =
       0`. Done.
   11. **Last card is a Jack (skip):** `skipCount = (rules.jackStackable && cards.count > 1) ? cards.count : 1`.
       Advance `currentPlayerIndex` by `skipCount + 1` positions (in `direction`) from the Jack-player's seat to land
       on the next active player. If `rules.jumpInterceptAllowed`, open a non-blocking grace window for the first
       skipped player (`skipInterceptGracePeriodPlayerIndex`). If `rules.lateKadiDeclaration`, set
       `kadiGracePeriodPlayerIndex` to the Jack-player. `phase = .playing`, `pendingDrawCount = 0`. Done.
   12. **Last card is a King (reverse):** if exactly 2 Kings played → direction unchanged, same player acts again
       (no turn advance); else flip `direction` and `_advanceTurn`. Done.
   13. **Otherwise (plain card):** `pendingDrawCount = 0`, `_advanceTurn`. Done.

3. **`Pass`** — valid if `phase == .questionAnswer` (always ok, forfeits the question — `forcedSuit = nil`); else
   `phase` must be `.playing`, no draw stack active, and if `!rules.passAllowed` then `KadiValidator.validPlays`
   must be empty. Apply: draw 1 card; if was answering a question, clear `forcedSuit`; cancel any active Kadi
   declaration for current player (+ `kadiPenalty` extra cards if >0); `_advanceTurn`.

4. **`DrawStack`** — valid only if `isDrawStackActive`. Apply: draw `pendingDrawCount` cards, reset to 0; cancel
   Kadi declaration if active (+ penalty); `_advanceTurn`.

5. **`DeclareKadi(cards)`**:
   - **Out-of-turn (late) path** — valid if `rules.lateKadiDeclaration`, `kadiGracePeriodPlayerIndex != nil`,
     `kadiGracePeriodPlayerIndex != currentPlayerIndex`, and `cards.isEmpty`. Apply: set
     `kadiState = {declaringPlayerIndex: kadiGracePeriodPlayerIndex}`, clear the grace window, **do not** advance
     turn.
   - **In-turn path** — `phase` must be `.playing` (validated as `PlayCards(cards)` if `cards` non-empty). Apply:
     set `kadiState = {declaringPlayerIndex: currentPlayerIndex}`; if `cards.isEmpty`, `_advanceTurn`; else run
     `_applyPlayCards(cards, isDeclaring: true)` (this is the path that can reach `phase = .finished`).

6. **`ChooseSuit(suit)`** — valid only if `phase == .suitChoice`. Apply: restore `phase` from
   `preSuitChoicePhase` (default `.playing`), set `forcedSuit = suit`, `_advanceTurn`.

7. **`RespondToDemand(card)`** — valid only if `phase == .cardDemand`. Apply: if `card == nil` → draw 1,
   `demandedCard = nil`, `phase = .playing`, cancel Kadi if declaring, `_advanceTurn`. Else → run
   `_applyPlayCards([card])` against state with `phase = .playing, demandedCard = nil` already set.

8. **`RefuseDraw(ace)`** — valid only if `isDrawStackActive`, `ace` in hand, `ace.isAce`. Apply: move `ace` from hand
   to discard, `pendingDrawCount = 0`; if `ace.isAceOfSpades` → `phase = .suitChoice`, `preSuitChoicePhase =
   .playing` (no advance); else `_advanceTurn`.

9. **`RefuseSkip(jack)`** — valid if `jack` in hand and `jack.isSkipCard`. Apply: move `jack` to discard; the skip is
   cancelled and instead lands on the *next* player (i.e. effectively shifts the skip target by one); `_advanceTurn`.

10. **`RefuseReverse(king)`** — valid if `king` in hand and `king.isReverseCard`. Apply: move `king` to discard;
    direction stays unchanged (reversal cancelled); `_advanceTurn`.

11. **`InterceptSkip(jacks)`** — two contexts:
    - **Non-blocking grace** (`skipInterceptGracePeriodPlayerIndex != nil`): valid if `jacks` non-empty, all in the
      grace player's hand, all Jacks. Apply: move `jacks` to discard, close the grace window, `newSkipCount =
      jacks.count`; advance from the grace player's seat by `newSkipCount + 1` to find the new landing seat; set
      `currentPlayerIndex` to it, `phase = .playing`.
    - **Blocking** (`phase == .skipIntercept`): valid if `jacks` non-empty, all in current player's hand, all Jacks.
      Apply: move `jacks` to discard, add `currentPlayerIndex` to `skipInterceptedBy`; `newSkipCount = jacks.count`;
      rebuild the intercept queue (`_buildSkipInterceptQueue`) from the current player's seat, skipping
      `newSkipCount` players and excluding anyone already in `skipInterceptedBy`. If queue non-empty: `phase =
      .skipIntercept`, `currentPlayerIndex = queue.first` (chain continues). Else: `_resolveSkip` (advance from
      `skipOriginIndex` by `pendingSkipCount + 1`, clear all skip-intercept fields, `phase = .playing`).

12. **`DeclineIntercept`** — valid if `phase == .skipIntercept` or `skipInterceptGracePeriodPlayerIndex != nil`.
    Apply: in the grace case, just close the grace window; in the blocking case, advance the intercept queue
    (move to next queued player, or `_resolveSkip` if queue empty).

13. **`JumpDraw(jack)`** — valid only if `isDrawStackActive`, `jack` in hand, `jack.isSkipCard`. Find the
    triggering draw card by scanning `discardPile` backwards for the first draw card: if it's a Joker,
    `rules.jokerJumpAllowed` must be true and `jack.suit == .diamonds`; if it's a 2/3, `rules.drawJumpAllowed` must
    be true and `jack.suit == ` the triggering card's suit. Apply: move `jack` to discard;
    `pendingDrawCount` unchanged (the draw obligation passes to the next player); `_advanceTurn`.

### H. KadiValidator (`lib/core/rules/kadi_validator.dart`)

Independent of the engine's turn-application logic — used by CPUs and UI to check "can I declare/win right now?":

- `validPlays(hand, topCard, forcedSuit, rules) -> [Card]`: all cards individually `isValidPlay` against current
  state (same `isValidPlay` rule as the engine).
- `canDeclareKadi(hand, topCard, forcedSuit, rules) -> Bool`: false if hand empty; otherwise recursive DFS
  (`_canPlayAll`) over the hand looking for *any* ordering that plays the entire hand as one legal chain such that
  the **last** card played has `canEndGame == true`. Branches: question cards (8/Q) force the next card to match
  their suit; Aces are tried against all 4 suits as the "next forced suit"; other cards continue with no forced
  suit. Returns true iff some full ordering reaches an empty hand on a `canEndGame` card.

### I. CpuAgent (`lib/core/cpu/cpu_agent.dart`)

Common decision points across all difficulty levels (each implements `chooseAction(state, playerIndex)`):
suit choice, demand entry (rank+suit), question-answer, responding to a card demand, draw-stack response, whether
to declare/play out a Kadi win, skip-intercept decisions, and normal-play card selection.

- **EasyCpu**: fully random among legal options. Declines all intercepts. Random suit on `ChooseSuit`. Random
  rank/suit on `MakeDemand`. Plays a matching-suit card if available on question-answer else passes. On card
  demand: plays the demanded card if held, else counters with an Ace if held, else draws. On draw stack: plays an
  Ace if held, else any valid draw card, else accepts the stack. Only declares Kadi by actually playing a
  game-ending hand (never a bare declaration unless it can win immediately).
- **MediumCpu**: intercepts skips if holding ≥2 Jacks. Picks `ChooseSuit`/demand suit as the most common suit in
  hand (`_mostCommonSuit`); demands rank `6` and the *least* common suit in hand (`_leastCommonSuit`). Normal play:
  prefers playing draw cards (pressure opponents); holds back refusal cards (Ace/Jack/King) unless they're the only
  legal play; randomizes among equally-good options.
- **HardCpu**: maintains `_playedCards` (call `recordPlayed(card)` on every card seen) for card counting.
  Intercepts skips if any opponent has ≤2 cards OR it holds ≥2 Jacks (plays only 1 Jack when intercepting via the
  grace path). Demand: picks the rank least represented in `_playedCards` (preferring ranks seen <2 times) and the
  suit most common in its own hand (`_bestSuit`, ties favor hearts). Question-answer: prefers a non-special
  same-suit card over a special one. Normal play: if any opponent has ≤2 cards, prioritizes draw/skip cards;
  otherwise prefers draw cards generally and holds Aces/Jacks/Kings back when other legal plays exist.
- **AdaptiveCpu**: wraps Easy/Medium/Hard. Starts as Easy. After each round (`recordRoundResult(playerWon:)`),
  every 3 rounds recomputes the human player's win rate over those rounds and switches: win rate > 60% → Hard,
  > 40% → Medium, else Easy. Delegates `chooseAction` to the currently-selected agent.

### J. LAN multiplayer protocol

- **Transport**: raw TCP, NDJSON framing — one `{"type": "<NetworkMessageType>", "payload": {...}}` JSON object per
  line (`\n`-terminated), enums serialized via `.name`.
- **`NetworkMessageType`**: `gameStateFull` (full `GameState`, sent on game start/reconnect), `playerAction`
  (encoded `GameAction`, client→host), `stateDelta` (full `GameState`, host→clients after every applied action —
  *not actually a diff despite the name*), `playerJoined`, `playerDisconnected`, `hostTransfer`, `ping` (host→client
  every 2s), `pong` (client→host, swallowed by server), `joinRequest` (client→host, first message after connect;
  carries player name/uid/avatar), `joinAck` (host→client; assigned player index + current player list),
  `gameStart` (host→clients; initial `GameState` + index assignments), `chat` (`{text, sender}`).
- **Connection flow**: client connects via TCP to host's advertised port → sends `joinRequest` → host replies
  `joinAck` → host eventually sends `gameStart` with full state → thereafter clients send `playerAction`, host
  validates+applies via `GameEngine` and broadcasts `stateDelta` (full state) to everyone.
- **Heartbeat**: host pings every 2s; client auto-replies `pong`; client disconnects itself after 3 missed pings
  (6s timeout).
- **Discovery**: Bonsoir mDNS/DNS-SD service type `_kadi._tcp` (host broadcasts name + dynamically-bound TCP port,
  TXT attr `ip` = host's LAN IPv4), plus a UDP broadcast beacon fallback on port **4499**
  (`{"type":"kadi_beacon","name","port","ip"}`, sent every 2s to `255.255.255.255:4499`). Web platform: discovery/
  broadcast are no-op stubs (no mDNS/raw sockets in browser); `_io` vs `_web` files split this.

### K. GameStateCodec — JSON wire format (`lib/network/sync/game_state_codec.dart`)

- **Card**: `{"rank": "<Rank.name>", "suit": "<Suit.name>"|null}`
- **Player**: `{"id", "name", "hand": [Card...], "isHuman": bool, "avatarIndex": int}`
- **KadiState**: `{"declaringPlayerIndex": int}` or `null`
- **RuleSet**: object with exactly the field names/types from table B above (`hintLevel` as its enum `.name` string)
- **GameState**: `{"players":[...], "drawPileCount": int, "drawPile":[Card...], "discardPile":[Card...],
  "currentPlayerIndex", "direction": "clockwise"|"anticlockwise", "pendingDrawCount", "forcedSuit": Suit?|null,
  "demandedCard": Card?|null, "kadiState": KadiState?|null, "rules": RuleSet, "phase": GamePhase.name,
  "preSuitChoicePhase": GamePhase?|null, "pendingSkipTarget": int?|null, "winningCards":[Card...],
  "skipInterceptQueue":[int...], "pendingSkipCount", "skipOriginIndex": int?|null, "skipInterceptedBy":[int...]}`
- **GameAction**: discriminated by `"type"` — see table E for the per-type field shapes (e.g.
  `{"type":"PlayCards","cards":[...]}`, `{"type":"ChooseSuit","suit":"hearts"}`,
  `{"type":"MakeDemand","rank":"king","suit":"hearts"}`, `{"type":"RespondToDemand","card":Card?|null}`, etc.)

### L. Online multiplayer — Firestore/RTDB data model

**Firestore root collections:**

- **`/rooms/{roomId}`** (roomId = 6-char code, A–Z/2–9, excluding 0/1/I/O):
  `{roomId, hostUid, hostName, players:[{uid,name,playerIndex,isConnected}], playerUids:[uid...],
  status: "waiting"|"playing"|"finished", rules: RuleSet, gameState: GameState|null,
  quitPenaltyEnabled: bool, createdAt, startedAt?}`
  - `/rooms/{roomId}/actions/{id}` — `{playerUid, action: GameAction, timestamp}`; guests create, host
    reads (`orderBy timestamp`), applies, deletes.
  - `/rooms/{roomId}/events/{id}` — `{seq: int, ...event fields, timestamp}`; host writes (monotonic `seq`),
    all players read for the game log.
  - `/rooms/{roomId}/messages/{id}` — `{senderUid, senderName, text (≤500 chars), timestamp}`; room chat,
    last 200 read; host deletes on room cleanup.
- **`/users/{uid}`** — `{uid, displayName, displayNameLower, email?, avatarId, points, wins, losses,
  gamesPlayed, quits, lastSeen, createdAt}`. Stats updated only via `FieldValue.increment`.
  - `/users/{uid}/friends/{friendUid}` — `{uid, displayName, avatarId, since}` (bilateral, written on accept).
  - `/users/{uid}/ruleSets/...` — owner-only saved rule presets.
- **`/friendRequests/{id}`** — `{fromUid, fromName, fromAvatarId, toUid, status: "pending"|"accepted"|"declined",
  createdAt}`.
- **`/blocks/{uid}/blocked/{targetUid}`** — `{blockedAt}` (uni-directional, owner-only).
- **`/conversations/{convId}`** (`convId = sorted([uidA,uidB]).join('_')`) —
  `{participants:[uidA,uidB], lastMessage?, updatedAt, unreadCounts:{uid:count}}`.
  - `/conversations/{convId}/messages/{id}` — `{senderUid, text (≤500 chars), timestamp}`, last 200 read.
- **`/gameInvites/{id}`** — `{fromUid, fromName, toUid, roomId, expiresAt, createdAt}` (default 1h expiry).
- **`/reports/{id}`** — `{reporterUid, targetUid, reason, createdAt}` — write-only from clients.
- **`/admins/{uid}`**, **`/campaigns/{id}`** — admin app only.

**RTDB:**
- **`/presence/{uid}`** — `{status: "online"|"offline"|"busy", customStatus?, inGame: bool, roomId?, lastSeen}`,
  with an `onDisconnect()` handler setting `status: "offline"`.
- **`/quickChat/{roomId}/{uid}`** — `{message, timestamp}` — ephemeral in-game quick-chat, one slot per player.

**Sync flow**: host listens to `actions`, applies via `GameEngine`, writes the new `gameState` onto the room doc
and an `events` entry, then deletes the processed action — all via real-time `snapshots()` listeners (no polling).
Guests submit to `actions` and listen to the room doc + `events` for state/log updates. Action processing order is
by server `timestamp`; host is authoritative.

**Auth**: Email/Password (mandatory verification) and Google Sign-In (web client ID
`652988490285-d66ufeirui0qbhcoht8is7rn2b4utivc.apps.googleusercontent.com`). On sign-in/registration,
`ProfileService.ensureProfile()` upserts `/users/{uid}` with `merge: true` (sets `createdAt` only for new accounts;
always refreshes `displayName`, `displayNameLower`, `email`, `avatarId`, `lastSeen` — never overwrites stat
counters).

**Firestore indexes**: `users` ordered by `points desc` (leaderboard); `campaigns` by `(status, scheduledAt)`
(admin scheduling).
