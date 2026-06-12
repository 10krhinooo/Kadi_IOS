import Foundation

/// A player in a `GameState`. Field names/types match the Dart `Player` model exactly for
/// JSON wire compatibility (see docs/GAME_SPEC.md §D, §K).
public struct Player: Codable, Equatable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var hand: [PlayingCard]
    public var isHuman: Bool
    public var avatarIndex: Int

    public init(id: String, name: String, hand: [PlayingCard], isHuman: Bool, avatarIndex: Int = 0) {
        self.id = id
        self.name = name
        self.hand = hand
        self.isHuman = isHuman
        self.avatarIndex = avatarIndex
    }

    enum CodingKeys: String, CodingKey {
        case id, name, hand, isHuman, avatarIndex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        hand = try container.decode([PlayingCard].self, forKey: .hand)
        isHuman = try container.decode(Bool.self, forKey: .isHuman)
        avatarIndex = try container.decodeIfPresent(Int.self, forKey: .avatarIndex) ?? 0
    }

    public var cardCount: Int { hand.count }
}
