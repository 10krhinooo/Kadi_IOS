import Foundation

/// `/conversations/{convId}` document, per docs/GAME_SPEC.md §L.
///
/// `convId` is the deterministic, sorted pair of the two participants' uids (see
/// `ConversationService.conversationId(for:and:)`).
public struct DMConversation: Codable, Equatable, Sendable {
    public var participants: [String]
    public var lastMessage: String?
    public var updatedAt: Date?
    public var unreadCounts: [String: Int]

    public init(
        participants: [String],
        lastMessage: String? = nil,
        updatedAt: Date? = nil,
        unreadCounts: [String: Int] = [:]
    ) {
        self.participants = participants
        self.lastMessage = lastMessage
        self.updatedAt = updatedAt
        self.unreadCounts = unreadCounts
    }
}

/// `/conversations/{convId}/messages/{id}` document, per docs/GAME_SPEC.md §L.
public struct DMMessage: Codable, Equatable, Sendable {
    public var senderUid: String
    public var text: String
    public var timestamp: Date?

    public init(senderUid: String, text: String, timestamp: Date? = nil) {
        self.senderUid = senderUid
        self.text = text
        self.timestamp = timestamp
    }
}
