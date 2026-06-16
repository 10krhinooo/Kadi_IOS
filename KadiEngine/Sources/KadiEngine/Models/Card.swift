import Foundation

/// Card rank. Raw values match the Dart `Rank` enum's `.name` exactly for JSON wire
/// compatibility (see docs/GAME_SPEC.md §A, §K).
public enum Rank: String, Codable, CaseIterable, Sendable {
    case two, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace, joker

    /// Display label used by `PlayingCard.rankLabel` / `displayName`.
    public var label: String {
        switch self {
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        case .joker: return "Joker"
        }
    }
}

/// Card suit. Raw values match the Dart `Suit` enum's `.name` exactly for JSON wire
/// compatibility (see docs/GAME_SPEC.md §A, §K). `nil` on `PlayingCard.suit` represents Jokers
/// without a fixed suit context (joker color is still encoded via `suit` — see `PlayingCard`).
public enum Suit: String, Codable, CaseIterable, Sendable {
    case hearts, diamonds, clubs, spades

    /// Suit symbol used by `PlayingCard.suitSymbol` / `displayName`.
    public var symbol: String {
        switch self {
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        case .spades: return "♠"
        }
    }
}

/// A single playing card. Equality/hash are based on `(rank, suit)` only — see
/// docs/GAME_SPEC.md §A.
public struct PlayingCard: Codable, Equatable, Hashable, Sendable {
    public var rank: Rank
    public var suit: Suit?

    public init(rank: Rank, suit: Suit?) {
        self.rank = rank
        self.suit = suit
    }

    enum CodingKeys: String, CodingKey {
        case rank, suit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rank = try container.decode(Rank.self, forKey: .rank)
        suit = try container.decodeIfPresent(Suit.self, forKey: .suit)
    }

    /// Always emits `"suit"`, encoding `null` for Jokers without a fixed suit, to match
    /// the Dart wire format (`{"rank": ..., "suit": "<Suit.name>"|null}`, see
    /// docs/GAME_SPEC.md §K).
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rank, forKey: .rank)
        try container.encode(suit, forKey: .suit)
    }

    // MARK: - Derived properties (docs/GAME_SPEC.md §A)

    public var isJoker: Bool { rank == .joker }

    public var isDrawCard: Bool { rank == .two || rank == .three || isJoker }

    public var isQuestionCard: Bool { rank == .eight || rank == .queen }

    public var isSkipCard: Bool { rank == .jack }

    public var isReverseCard: Bool { rank == .king }

    public var isAce: Bool { rank == .ace }

    public var isAceOfSpades: Bool { rank == .ace && suit == .spades }

    /// Red joker counts as red (suit == .hearts for red joker per spec §F).
    public var isRed: Bool { suit == .hearts || suit == .diamonds }

    /// Black joker counts as black (suit == .clubs for black joker per spec §F).
    public var isBlack: Bool { suit == .clubs || suit == .spades }

    public var isSpecial: Bool {
        isDrawCard || isQuestionCard || isSkipCard || isReverseCard || isAce
    }

    /// True only for ranks four..ten and king.
    public var canEndGame: Bool {
        switch rank {
        case .four, .five, .six, .seven, .eight, .nine, .ten, .king:
            return true
        default:
            return false
        }
    }

    public var drawValue: Int {
        switch rank {
        case .two: return 2
        case .three: return 3
        case .joker: return 5
        default: return 0
        }
    }

    public var rankLabel: String { rank.label }

    public var suitSymbol: String { suit?.symbol ?? "" }

    /// e.g. "2♥️", "A♠️", "Red Joker", "Black Joker".
    public var displayName: String {
        if isJoker {
            return isRed ? "Red Joker" : "Black Joker"
        }
        return "\(rankLabel)\(suitSymbol)"
    }
}
