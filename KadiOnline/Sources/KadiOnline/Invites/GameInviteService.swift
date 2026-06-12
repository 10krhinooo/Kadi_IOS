@preconcurrency import FirebaseFirestore
import Foundation

/// `/gameInvites/{id}` documents, per docs/GAME_SPEC.md §L.
public struct GameInviteService: Sendable {
    public static let defaultTTL: TimeInterval = 3600

    private let db: Firestore

    public init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private var gameInvitesRef: CollectionReference {
        db.collection("gameInvites")
    }

    /// Creates a `/gameInvites/{id}` doc that expires after `ttl` seconds (default 1 hour).
    @discardableResult
    public func sendInvite(fromUid: String, fromName: String, toUid: String, roomId: String, ttl: TimeInterval = defaultTTL) async throws -> String {
        let data: [String: Any] = [
            "fromUid": fromUid,
            "fromName": fromName,
            "toUid": toUid,
            "roomId": roomId,
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: Date().addingTimeInterval(ttl)),
        ]
        let ref = try await gameInvitesRef.addDocument(data: data)
        return ref.documentID
    }

    /// Streams `/gameInvites` where `toUid == uid`, filtering out expired invites.
    public func observeIncomingInvites(uid: String) -> AsyncThrowingStream<[GameInvite], Error> {
        AsyncThrowingStream { continuation in
            let listener = gameInvitesRef
                .whereField("toUid", isEqualTo: uid)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else { return }
                    do {
                        let now = Date()
                        let invites = try snapshot.documents.compactMap { document -> GameInvite? in
                            var invite = try document.data(as: GameInvite.self)
                            invite.id = document.documentID
                            if let expiresAt = invite.expiresAt, expiresAt < now {
                                return nil
                            }
                            return invite
                        }
                        continuation.yield(invites)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// Deletes `/gameInvites/{inviteId}` — used for both accepting (after joining the
    /// room) and declining.
    public func deleteInvite(inviteId: String) async throws {
        try await gameInvitesRef.document(inviteId).delete()
    }
}
