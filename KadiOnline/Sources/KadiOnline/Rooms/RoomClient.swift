@preconcurrency import FirebaseFirestore
import Foundation
import KadiEngine

/// Guest-side handle to a `/rooms/{roomId}` game session, per docs/GAME_SPEC.md §L.
///
/// Submits the local player's actions to `/rooms/{roomId}/actions` for the host's
/// `RoomHost` to validate, apply, and acknowledge (by deleting the action doc and writing
/// the resulting `gameState`/`events`). Observation (`gameState`, `events`, `messages`)
/// is delegated to `RoomService`.
public struct RoomClient: Sendable {
    private let db: Firestore
    public let roomId: String
    public let uid: String

    public init(roomId: String, uid: String, db: Firestore = Firestore.firestore()) {
        self.roomId = roomId
        self.uid = uid
        self.db = db
    }

    private func actionsRef() -> CollectionReference {
        db.collection("rooms").document(roomId).collection("actions")
    }

    /// Submits `action` for the host to process.
    public func submitAction(_ action: GameAction) async throws {
        var data = try Firestore.Encoder().encode(RoomAction(playerUid: uid, action: action))
        data["timestamp"] = FieldValue.serverTimestamp()
        try await actionsRef().addDocument(data: data)
    }
}
