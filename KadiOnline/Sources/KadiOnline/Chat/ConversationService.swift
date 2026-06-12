@preconcurrency import FirebaseFirestore
import Foundation

public enum ConversationServiceError: Error, Equatable {
    case messageTooLong
}

/// `/conversations/{convId}` DM conversations + messages, per docs/GAME_SPEC.md §L.
public struct ConversationService: Sendable {
    public static let maxMessageLength = 500

    private let db: Firestore

    public init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    /// Deterministic conversation ID for a pair of uids — the sorted pair joined by `_`.
    public static func conversationId(for uidA: String, and uidB: String) -> String {
        [uidA, uidB].sorted().joined(separator: "_")
    }

    private func conversationRef(_ convId: String) -> DocumentReference {
        db.collection("conversations").document(convId)
    }

    /// Appends a message and updates the conversation doc (`participants`,
    /// `lastMessage`, `updatedAt`, and `unreadCounts.{recipientUid}` incremented by 1)
    /// in a single batch. Throws `.messageTooLong` if `text` exceeds
    /// `maxMessageLength`.
    public func sendMessage(senderUid: String, recipientUid: String, text: String) async throws {
        guard text.count <= Self.maxMessageLength else {
            throw ConversationServiceError.messageTooLong
        }

        let convId = Self.conversationId(for: senderUid, and: recipientUid)
        let ref = conversationRef(convId)

        let batch = db.batch()
        batch.setData([
            "senderUid": senderUid,
            "text": text,
            "timestamp": FieldValue.serverTimestamp(),
        ], forDocument: ref.collection("messages").document())
        batch.setData([
            "participants": [senderUid, recipientUid].sorted(),
            "lastMessage": text,
            "updatedAt": FieldValue.serverTimestamp(),
            "unreadCounts": [recipientUid: FieldValue.increment(Int64(1))],
        ], forDocument: ref, merge: true)
        try await batch.commit()
    }

    /// Streams `/conversations` where `participants` contains `uid`, ordered by
    /// `updatedAt` descending.
    public func observeConversations(uid: String) -> AsyncThrowingStream<[DMConversation], Error> {
        AsyncThrowingStream { continuation in
            let listener = db.collection("conversations")
                .whereField("participants", arrayContains: uid)
                .order(by: "updatedAt", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else { return }
                    do {
                        let conversations = try snapshot.documents.map { try $0.data(as: DMConversation.self) }
                        continuation.yield(conversations)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// Streams the most recent 200 messages in `/conversations/{convId}/messages`,
    /// ordered by `timestamp`.
    public func observeMessages(convId: String) -> AsyncThrowingStream<[DMMessage], Error> {
        AsyncThrowingStream { continuation in
            let listener = conversationRef(convId).collection("messages")
                .order(by: "timestamp")
                .limit(toLast: 200)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else { return }
                    do {
                        let messages = try snapshot.documents.map { try $0.data(as: DMMessage.self) }
                        continuation.yield(messages)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// Resets `unreadCounts.{uid}` to `0` on `/conversations/{convId}`.
    public func markRead(convId: String, uid: String) async throws {
        try await conversationRef(convId).updateData(["unreadCounts.\(uid)": 0])
    }
}
