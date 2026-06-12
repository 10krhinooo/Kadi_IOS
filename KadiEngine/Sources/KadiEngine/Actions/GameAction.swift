import Foundation

/// A player action submitted to the `GameEngine`. Encoded as a discriminated union with a
/// `"type"` field matching the exact type names below (see docs/GAME_SPEC.md §E, §K).
public enum GameAction: Equatable, Sendable {
    /// Play one or more cards (validated as a chain).
    case playCards(cards: [PlayingCard])
    /// Pass turn, draw 1.
    case pass
    /// Accept the full `pendingDrawCount` and draw that many.
    case drawStack
    /// Declare intent to win this/next turn, optionally playing the winning cards.
    case declareKadi(cards: [PlayingCard])
    /// Pick the next suit after a non-A♠️ Ace, or after 8/Q in suit-choice phase.
    case chooseSuit(suit: Suit)
    /// After A♠️/multi-Ace: name the exact card demanded.
    case makeDemand(rank: Rank, suit: Suit)
    /// Play the demanded card, or `nil` to draw 1 instead.
    case respondToDemand(card: PlayingCard?)
    /// Use an Ace to cancel a pending draw stack.
    case refuseDraw(ace: PlayingCard)
    /// Cancel an incoming skip with another Jack (skip moves to *next* player instead).
    case refuseSkip(jack: PlayingCard)
    /// Cancel a King's reversal (direction stays the same).
    case refuseReverse(king: PlayingCard)
    /// Redirect a pending skip from the interceptor's position.
    case interceptSkip(jacks: [PlayingCard])
    /// Decline the intercept opportunity.
    case declineIntercept
    /// Redirect a pending 2/3/Joker draw to the next player via a matching Jack.
    case jumpDraw(jack: PlayingCard)
}

// MARK: - Codable (matches docs/GAME_SPEC.md §K wire format)

extension GameAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case cards
        case suit
        case rank
        case card
        case ace
        case jack
        case king
        case jacks
    }

    private enum ActionType: String, Codable {
        case playCards = "PlayCards"
        case pass = "Pass"
        case drawStack = "DrawStack"
        case declareKadi = "DeclareKadi"
        case chooseSuit = "ChooseSuit"
        case makeDemand = "MakeDemand"
        case respondToDemand = "RespondToDemand"
        case refuseDraw = "RefuseDraw"
        case refuseSkip = "RefuseSkip"
        case refuseReverse = "RefuseReverse"
        case interceptSkip = "InterceptSkip"
        case declineIntercept = "DeclineIntercept"
        case jumpDraw = "JumpDraw"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ActionType.self, forKey: .type)
        switch type {
        case .playCards:
            self = .playCards(cards: try container.decode([PlayingCard].self, forKey: .cards))
        case .pass:
            self = .pass
        case .drawStack:
            self = .drawStack
        case .declareKadi:
            let cards = try container.decodeIfPresent([PlayingCard].self, forKey: .cards) ?? []
            self = .declareKadi(cards: cards)
        case .chooseSuit:
            self = .chooseSuit(suit: try container.decode(Suit.self, forKey: .suit))
        case .makeDemand:
            let rank = try container.decode(Rank.self, forKey: .rank)
            let suit = try container.decode(Suit.self, forKey: .suit)
            self = .makeDemand(rank: rank, suit: suit)
        case .respondToDemand:
            let card = try container.decodeIfPresent(PlayingCard.self, forKey: .card)
            self = .respondToDemand(card: card)
        case .refuseDraw:
            self = .refuseDraw(ace: try container.decode(PlayingCard.self, forKey: .ace))
        case .refuseSkip:
            self = .refuseSkip(jack: try container.decode(PlayingCard.self, forKey: .jack))
        case .refuseReverse:
            self = .refuseReverse(king: try container.decode(PlayingCard.self, forKey: .king))
        case .interceptSkip:
            self = .interceptSkip(jacks: try container.decode([PlayingCard].self, forKey: .jacks))
        case .declineIntercept:
            self = .declineIntercept
        case .jumpDraw:
            self = .jumpDraw(jack: try container.decode(PlayingCard.self, forKey: .jack))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .playCards(let cards):
            try container.encode(ActionType.playCards, forKey: .type)
            try container.encode(cards, forKey: .cards)
        case .pass:
            try container.encode(ActionType.pass, forKey: .type)
        case .drawStack:
            try container.encode(ActionType.drawStack, forKey: .type)
        case .declareKadi(let cards):
            try container.encode(ActionType.declareKadi, forKey: .type)
            try container.encode(cards, forKey: .cards)
        case .chooseSuit(let suit):
            try container.encode(ActionType.chooseSuit, forKey: .type)
            try container.encode(suit, forKey: .suit)
        case .makeDemand(let rank, let suit):
            try container.encode(ActionType.makeDemand, forKey: .type)
            try container.encode(rank, forKey: .rank)
            try container.encode(suit, forKey: .suit)
        case .respondToDemand(let card):
            try container.encode(ActionType.respondToDemand, forKey: .type)
            try container.encodeIfPresent(card, forKey: .card)
        case .refuseDraw(let ace):
            try container.encode(ActionType.refuseDraw, forKey: .type)
            try container.encode(ace, forKey: .ace)
        case .refuseSkip(let jack):
            try container.encode(ActionType.refuseSkip, forKey: .type)
            try container.encode(jack, forKey: .jack)
        case .refuseReverse(let king):
            try container.encode(ActionType.refuseReverse, forKey: .type)
            try container.encode(king, forKey: .king)
        case .interceptSkip(let jacks):
            try container.encode(ActionType.interceptSkip, forKey: .type)
            try container.encode(jacks, forKey: .jacks)
        case .declineIntercept:
            try container.encode(ActionType.declineIntercept, forKey: .type)
        case .jumpDraw(let jack):
            try container.encode(ActionType.jumpDraw, forKey: .type)
            try container.encode(jack, forKey: .jack)
        }
    }
}
