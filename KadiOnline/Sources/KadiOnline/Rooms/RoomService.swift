@preconcurrency import FirebaseFirestore
import Foundation
import KadiEngine

public enum RoomServiceError: Error, Equatable {
    case roomNotFound
    case roomFull
    case roomAlreadyStarted
    case couldNotGenerateUniqueRoomId
}

/// CRUD + real-time access to `/rooms/{roomId}` and its subcollections, per
/// docs/GAME_SPEC.md §L.
public struct RoomService: Sendable {
    private let db: Firestore
    public let maxPlayers: Int

    public init(db: Firestore = Firestore.firestore(), maxPlayers: Int = 4) {
        self.db = db
        self.maxPlayers = maxPlayers
    }

    private func roomRef(_ roomId: String) -> DocumentReference {
        db.collection("rooms").document(roomId)
    }

    // MARK: - Create / join / leave / delete

    /// Creates a new room with `hostUid` as player 0, retrying on `roomId` collisions.
    @discardableResult
    public func createRoom(hostUid: String, hostName: String, rules: RuleSet, quitPenaltyEnabled: Bool = false) async throws -> String {
        let rulesData = try Firestore.Encoder().encode(rules)

        for _ in 0..<10 {
            let roomId = RoomIdGenerator.generate()
            let ref = roomRef(roomId)
            let existing = try await ref.getDocument()
            guard !existing.exists else { continue }

            let hostPlayer = RoomPlayer(uid: hostUid, name: hostName, playerIndex: 0, isConnected: true)
            let data: [String: Any] = [
                "roomId": roomId,
                "hostUid": hostUid,
                "hostName": hostName,
                "players": [try Firestore.Encoder().encode(hostPlayer)],
                "playerUids": [hostUid],
                "status": RoomStatus.waiting.rawValue,
                "rules": rulesData,
                "quitPenaltyEnabled": quitPenaltyEnabled,
                "eventSeq": 0,
                "createdAt": FieldValue.serverTimestamp(),
            ]
            try await ref.setData(data)
            return roomId
        }
        throw RoomServiceError.couldNotGenerateUniqueRoomId
    }

    /// Adds `uid` to the room's roster at the next free `playerIndex`, transactionally.
    /// Throws `.roomNotFound`, `.roomAlreadyStarted`, or `.roomFull`.
    @discardableResult
    public func joinRoom(roomId: String, uid: String, name: String) async throws -> Int {
        let ref = roomRef(roomId)
        let maxPlayers = self.maxPlayers

        let assignedIndex: Any?
        do {
            assignedIndex = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(ref)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            guard snapshot.exists, let data = snapshot.data() else {
                errorPointer?.pointee = NSError(domain: "RoomService", code: 1, userInfo: [NSLocalizedDescriptionKey: "roomNotFound"])
                return nil
            }
            guard (data["status"] as? String) == RoomStatus.waiting.rawValue else {
                errorPointer?.pointee = NSError(domain: "RoomService", code: 2, userInfo: [NSLocalizedDescriptionKey: "roomAlreadyStarted"])
                return nil
            }
            var playerUids = data["playerUids"] as? [String] ?? []
            var players = data["players"] as? [[String: Any]] ?? []

            if playerUids.contains(uid) {
                // Already a member (e.g. rejoining) — return existing index.
                let existingIndex = players.first { ($0["uid"] as? String) == uid }?["playerIndex"] as? Int
                return existingIndex ?? 0
            }

            guard playerUids.count < maxPlayers else {
                errorPointer?.pointee = NSError(domain: "RoomService", code: 3, userInfo: [NSLocalizedDescriptionKey: "roomFull"])
                return nil
            }

            let newIndex = playerUids.count
            playerUids.append(uid)
            players.append([
                "uid": uid,
                "name": name,
                "playerIndex": newIndex,
                "isConnected": true,
            ])
            transaction.updateData(["playerUids": playerUids, "players": players], forDocument: ref)
            return newIndex
        }
        } catch let error as NSError where error.domain == "RoomService" {
            switch error.code {
            case 2: throw RoomServiceError.roomAlreadyStarted
            case 3: throw RoomServiceError.roomFull
            default: throw RoomServiceError.roomNotFound
            }
        }

        guard let index = assignedIndex as? Int else {
            throw RoomServiceError.roomNotFound
        }
        return index
    }

    /// Marks `uid` as disconnected in the room's roster (does not remove the seat).
    public func leaveRoom(roomId: String, uid: String) async throws {
        let ref = roomRef(roomId)
        _ = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(ref)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            guard var players = snapshot.data()?["players"] as? [[String: Any]] else { return nil }
            for i in players.indices where (players[i]["uid"] as? String) == uid {
                players[i]["isConnected"] = false
            }
            transaction.updateData(["players": players], forDocument: ref)
            return nil
        }
    }

    /// Deletes the room document. Does not recursively delete subcollections (Phase 4/ops
    /// concern — Firestore doesn't cascade-delete subcollections automatically).
    public func deleteRoom(roomId: String) async throws {
        try await roomRef(roomId).delete()
    }

    // MARK: - Observation

    /// Streams the room document. Ends when the room is deleted.
    public func observeRoom(roomId: String) -> AsyncThrowingStream<Room, Error> {
        AsyncThrowingStream { continuation in
            let listener = roomRef(roomId).addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let snapshot, snapshot.exists else {
                    continuation.finish()
                    return
                }
                do {
                    let room = try snapshot.data(as: Room.self)
                    continuation.yield(room)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// Streams `/rooms/{roomId}/events`, ordered by `seq`.
    public func observeEvents(roomId: String) -> AsyncThrowingStream<[RoomEvent], Error> {
        AsyncThrowingStream { continuation in
            let listener = roomRef(roomId).collection("events")
                .order(by: "seq")
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else { return }
                    do {
                        let events = try snapshot.documents.map { try $0.data(as: RoomEvent.self) }
                        continuation.yield(events)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// Streams the most recent 200 `/rooms/{roomId}/messages`, ordered by `timestamp`.
    public func observeMessages(roomId: String) -> AsyncThrowingStream<[RoomMessage], Error> {
        AsyncThrowingStream { continuation in
            let listener = roomRef(roomId).collection("messages")
                .order(by: "timestamp")
                .limit(toLast: 200)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else { return }
                    do {
                        let messages = try snapshot.documents.map { try $0.data(as: RoomMessage.self) }
                        continuation.yield(messages)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// Appends a chat message to `/rooms/{roomId}/messages`.
    public func sendMessage(roomId: String, senderUid: String, senderName: String, text: String) async throws {
        let data: [String: Any] = [
            "senderUid": senderUid,
            "senderName": senderName,
            "text": text,
            "timestamp": FieldValue.serverTimestamp(),
        ]
        try await roomRef(roomId).collection("messages").addDocument(data: data)
    }
}
