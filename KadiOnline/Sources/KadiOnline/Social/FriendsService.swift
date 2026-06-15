@preconcurrency import FirebaseFirestore
import Foundation

public enum FriendsServiceError: Error, Equatable {
    case requestAlreadyPending
    case requestNotFound
    case blocked
}

/// Friends list, friend requests, and blocks, per docs/GAME_SPEC.md §L.
public struct FriendsService: Sendable {
    private let db: Firestore

    public init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func friendsRef(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("friends")
    }

    private func blockedRef(_ uid: String) -> CollectionReference {
        db.collection("blocks").document(uid).collection("blocked")
    }

    private var friendRequestsRef: CollectionReference {
        db.collection("friendRequests")
    }

    // MARK: - Friend requests

    /// Creates a `/friendRequests/{id}` doc with `status: "pending"`. Throws
    /// `.requestAlreadyPending` if a pending request already exists between this pair
    /// (in either direction).
    @discardableResult
    public func sendFriendRequest(fromUid: String, fromName: String, fromAvatarId: Int, toUid: String) async throws -> String {
        let forward = try await friendRequestsRef
            .whereField("fromUid", isEqualTo: fromUid)
            .whereField("toUid", isEqualTo: toUid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .limit(to: 1)
            .getDocuments()
        guard forward.documents.isEmpty else {
            throw FriendsServiceError.requestAlreadyPending
        }

        let reverse = try await friendRequestsRef
            .whereField("fromUid", isEqualTo: toUid)
            .whereField("toUid", isEqualTo: fromUid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .limit(to: 1)
            .getDocuments()
        guard reverse.documents.isEmpty else {
            throw FriendsServiceError.requestAlreadyPending
        }

        let data: [String: Any] = [
            "fromUid": fromUid,
            "fromName": fromName,
            "fromAvatarId": fromAvatarId,
            "toUid": toUid,
            "status": FriendRequestStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        let ref = try await friendRequestsRef.addDocument(data: data)
        return ref.documentID
    }

    /// Accepts or declines `/friendRequests/{requestId}`.
    ///
    /// On accept: writes bilateral `/users/{uid}/friends/{friendUid}` docs (using the
    /// requester's captured name/avatar and the recipient's current profile snapshot)
    /// and marks the request `"accepted"`. On decline: marks the request
    /// `"declined"`. Throws `.requestNotFound` if the request doesn't exist.
    public func respondToFriendRequest(requestId: String, accept: Bool) async throws {
        let requestRef = friendRequestsRef.document(requestId)
        let snapshot = try await requestRef.getDocument()
        guard let data = snapshot.data() else {
            throw FriendsServiceError.requestNotFound
        }

        guard accept else {
            try await requestRef.updateData(["status": FriendRequestStatus.declined.rawValue])
            return
        }

        guard
            let fromUid = data["fromUid"] as? String,
            let fromName = data["fromName"] as? String,
            let fromAvatarId = data["fromAvatarId"] as? Int,
            let toUid = data["toUid"] as? String
        else {
            throw FriendsServiceError.requestNotFound
        }

        if try await isBlocked(fromUid, by: toUid) {
            throw FriendsServiceError.blocked
        }
        if try await isBlocked(toUid, by: fromUid) {
            throw FriendsServiceError.blocked
        }

        let toProfileSnapshot = try await db.collection("users").document(toUid).getDocument()
        let toName = toProfileSnapshot.data()?["displayName"] as? String ?? fromName
        let toAvatarId = toProfileSnapshot.data()?["avatarId"] as? Int ?? fromAvatarId

        let batch = db.batch()
        batch.setData([
            "uid": toUid,
            "displayName": toName,
            "avatarId": toAvatarId,
            "since": FieldValue.serverTimestamp(),
        ], forDocument: friendsRef(fromUid).document(toUid))
        batch.setData([
            "uid": fromUid,
            "displayName": fromName,
            "avatarId": fromAvatarId,
            "since": FieldValue.serverTimestamp(),
        ], forDocument: friendsRef(toUid).document(fromUid))
        batch.updateData(["status": FriendRequestStatus.accepted.rawValue], forDocument: requestRef)
        try await batch.commit()
    }

    /// Streams pending incoming `/friendRequests` for `uid`.
    public func observeIncomingFriendRequests(uid: String) -> AsyncThrowingStream<[FriendRequest], Error> {
        AsyncThrowingStream { continuation in
            let listener = friendRequestsRef
                .whereField("toUid", isEqualTo: uid)
                .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else { return }
                    do {
                        let requests = try snapshot.documents.map { document -> FriendRequest in
                            var request = try document.data(as: FriendRequest.self)
                            request.id = document.documentID
                            return request
                        }
                        continuation.yield(requests)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - Friends list

    /// Streams `/users/{uid}/friends`.
    public func observeFriends(uid: String) -> AsyncThrowingStream<[Friend], Error> {
        AsyncThrowingStream { continuation in
            let listener = friendsRef(uid).addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let snapshot else { return }
                do {
                    let friends = try snapshot.documents.map { try $0.data(as: Friend.self) }
                    continuation.yield(friends)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// Removes the bilateral friendship between `uid` and `friendUid`.
    public func removeFriend(uid: String, friendUid: String) async throws {
        let batch = db.batch()
        batch.deleteDocument(friendsRef(uid).document(friendUid))
        batch.deleteDocument(friendsRef(friendUid).document(uid))
        try await batch.commit()
    }

    // MARK: - Blocks

    /// Returns whether `uid` has blocked `targetUid` (`/blocks/{uid}/blocked/{targetUid}` exists).
    public func isBlocked(_ targetUid: String, by uid: String) async throws -> Bool {
        try await blockedRef(uid).document(targetUid).getDocument().exists
    }

    /// Sets `/blocks/{uid}/blocked/{targetUid}`.
    public func blockUser(uid: String, targetUid: String) async throws {
        try await blockedRef(uid).document(targetUid).setData([
            "uid": targetUid,
            "blockedAt": FieldValue.serverTimestamp(),
        ])
    }

    /// Deletes `/blocks/{uid}/blocked/{targetUid}`.
    public func unblockUser(uid: String, targetUid: String) async throws {
        try await blockedRef(uid).document(targetUid).delete()
    }

    /// Streams `/blocks/{uid}/blocked`.
    public func observeBlockedUsers(uid: String) -> AsyncThrowingStream<[BlockedUser], Error> {
        AsyncThrowingStream { continuation in
            let listener = blockedRef(uid).addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let snapshot else { return }
                do {
                    let blocked = try snapshot.documents.map { try $0.data(as: BlockedUser.self) }
                    continuation.yield(blocked)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}
