import Foundation
import KadiEngine

/// `/users/{uid}/ruleSets/{id}` document, per docs/GAME_SPEC.md §L.
///
/// `id` is the Firestore document ID — never stored as a field in the document itself,
/// populated by `RuleSetService` from `DocumentSnapshot.documentID` after decoding.
public struct SavedRuleSet: Codable, Equatable, Sendable {
    public var id: String?
    public var name: String
    public var rules: RuleSet
    public var createdAt: Date?

    public init(id: String? = nil, name: String, rules: RuleSet, createdAt: Date? = nil) {
        self.id = id
        self.name = name
        self.rules = rules
        self.createdAt = createdAt
    }
}
