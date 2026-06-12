import Foundation

/// UI hint verbosity. Raw values match the Dart `HintLevel` enum's `.name`.
public enum HintLevel: String, Codable, CaseIterable, Sendable {
    case none, basic, advanced
}

/// All configurable game rules. Field names, types, and defaults match the Dart `RuleSet`
/// exactly (see docs/GAME_SPEC.md §B) for JSON wire compatibility.
public struct RuleSet: Codable, Equatable, Hashable, Sendable {
    /// A♠️ demands a specific rank+suit instead of just a suit.
    public var aceOfSpadesEnabled: Bool
    /// Include Red/Black Jokers in the deck.
    public var jokersIncluded: Bool
    /// Number of standard 52-card decks shuffled together.
    public var deckCount: Int
    /// Initial hand size.
    public var cardsPerPlayer: Int
    /// If first flipped card is special: true = reshuffle whole deck, false = put it back and
    /// draw next.
    public var startingCardReshuffle: Bool
    /// Max accumulated draw stack (0 = uncapped).
    public var drawStackCap: Int
    /// Extra cards drawn when a Kadi declaration is cancelled (0 = none). A *false* Kadi
    /// win-attempt penalty defaults to 2 regardless of this value.
    public var kadiPenalty: Int
    /// Player may pass/draw 1 even if a valid play exists.
    public var passAllowed: Bool
    /// Two Kings played together = double-reversal (direction unchanged, same player goes
    /// again).
    public var kingStackable: Bool
    /// Multiple Jacks played together skip that many players.
    public var jackStackable: Bool
    /// Grace window to declare Kadi after emptying hand, before next player acts (else
    /// instant 2-card penalty).
    public var lateKadiDeclaration: Bool
    /// Per-turn time limit in seconds (0 = none).
    public var turnTimerSeconds: Int
    /// Skipped player(s) may intercept a Jack-skip with their own Jack(s), redirecting it
    /// from their position.
    public var jumpInterceptAllowed: Bool
    /// 2s trigger draw-2.
    public var twosEnabled: Bool
    /// 3s trigger draw-3.
    public var threesEnabled: Bool
    /// Player facing a 2/3 draw may redirect with a Jack of the same suit as the triggering
    /// card.
    public var drawJumpAllowed: Bool
    /// Player facing a Joker draw may redirect with the Jack of Diamonds.
    public var jokerJumpAllowed: Bool
    /// UI: show opponents' hand sizes.
    public var showOpponentCardCounts: Bool
    /// UI hint verbosity.
    public var hintLevel: HintLevel

    public init(
        aceOfSpadesEnabled: Bool = true,
        jokersIncluded: Bool = true,
        deckCount: Int = 1,
        cardsPerPlayer: Int = 4,
        startingCardReshuffle: Bool = false,
        drawStackCap: Int = 0,
        kadiPenalty: Int = 0,
        passAllowed: Bool = true,
        kingStackable: Bool = true,
        jackStackable: Bool = true,
        lateKadiDeclaration: Bool = false,
        turnTimerSeconds: Int = 0,
        jumpInterceptAllowed: Bool = false,
        twosEnabled: Bool = true,
        threesEnabled: Bool = true,
        drawJumpAllowed: Bool = false,
        jokerJumpAllowed: Bool = false,
        showOpponentCardCounts: Bool = false,
        hintLevel: HintLevel = .none
    ) {
        self.aceOfSpadesEnabled = aceOfSpadesEnabled
        self.jokersIncluded = jokersIncluded
        self.deckCount = deckCount
        self.cardsPerPlayer = cardsPerPlayer
        self.startingCardReshuffle = startingCardReshuffle
        self.drawStackCap = drawStackCap
        self.kadiPenalty = kadiPenalty
        self.passAllowed = passAllowed
        self.kingStackable = kingStackable
        self.jackStackable = jackStackable
        self.lateKadiDeclaration = lateKadiDeclaration
        self.turnTimerSeconds = turnTimerSeconds
        self.jumpInterceptAllowed = jumpInterceptAllowed
        self.twosEnabled = twosEnabled
        self.threesEnabled = threesEnabled
        self.drawJumpAllowed = drawJumpAllowed
        self.jokerJumpAllowed = jokerJumpAllowed
        self.showOpponentCardCounts = showOpponentCardCounts
        self.hintLevel = hintLevel
    }
}
