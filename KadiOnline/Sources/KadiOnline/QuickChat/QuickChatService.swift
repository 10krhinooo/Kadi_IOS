@preconcurrency import FirebaseDatabase
import Foundation

/// Ephemeral in-game quick chat at `/quickChat/{roomId}/{uid}`, per docs/GAME_SPEC.md §L.
public struct QuickChatService: Sendable {
    private let db: Database

    public init(db: Database = Database.database()) {
        self.db = db
    }

    private func quickChatRef(_ roomId: String) -> DatabaseReference {
        db.reference(withPath: "quickChat/\(roomId)")
    }

    /// Sets `uid`'s quick-chat slot for `roomId`, overwriting any previous message
    /// ("one slot per player" per §L).
    public func sendQuickChat(roomId: String, uid: String, message: String) async throws {
        let ref = quickChatRef(roomId).child(uid)
        let value: [String: Any] = [
            "message": message,
            "timestamp": ServerValue.timestamp(),
        ]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setValue(value) { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Streams `/quickChat/{roomId}`, one `QuickChatMessage` per player.
    public func observeQuickChat(roomId: String) -> AsyncThrowingStream<[QuickChatMessage], Error> {
        AsyncThrowingStream { continuation in
            let ref = quickChatRef(roomId)
            let handle = ref.observe(.value, with: { snapshot in
                do {
                    let messages: [QuickChatMessage] = try snapshot.children.compactMap { child -> QuickChatMessage? in
                        guard let child = child as? DataSnapshot else { return nil }
                        var message = try child.data(as: QuickChatMessage.self)
                        message.uid = child.key
                        return message
                    }
                    continuation.yield(messages)
                } catch {
                    continuation.finish(throwing: error)
                }
            }, withCancel: { error in
                continuation.finish(throwing: error)
            })
            continuation.onTermination = { _ in ref.removeObserver(withHandle: handle) }
        }
    }

    /// Removes all quick-chat messages for `roomId` (host calls this when the room
    /// closes/game ends, since quickChat is explicitly ephemeral).
    public func clearQuickChat(roomId: String) async throws {
        let ref = quickChatRef(roomId)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.removeValue { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
