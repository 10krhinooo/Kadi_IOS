@preconcurrency import FirebaseDatabase
import Foundation

/// Real-time presence at `/presence/{uid}`, per docs/GAME_SPEC.md §L.
public struct PresenceService: Sendable {
    private let db: Database

    public init(db: Database = Database.database()) {
        self.db = db
    }

    private func presenceRef(_ uid: String) -> DatabaseReference {
        db.reference(withPath: "presence/\(uid)")
    }

    /// Marks `uid` online, registering an `onDisconnect()` handler that flips
    /// `status` back to `offline` if the client disconnects without calling
    /// `goOffline`.
    public func goOnline(uid: String, inGame: Bool = false, roomId: String? = nil) async throws {
        let ref = presenceRef(uid)

        let disconnectValue: [String: Any] = [
            "status": PresenceStatus.offline.rawValue,
            "inGame": false,
            "lastSeen": ServerValue.timestamp(),
        ]
        try await onDisconnectSetValue(disconnectValue, on: ref)

        let value: [String: Any] = [
            "status": PresenceStatus.online.rawValue,
            "inGame": inGame,
            "roomId": roomId ?? NSNull(),
            "lastSeen": ServerValue.timestamp(),
        ]
        try await setValue(value, on: ref)
    }

    /// Marks `uid` offline and cancels the `onDisconnect()` handler registered by
    /// `goOnline`, since it's no longer needed.
    public func goOffline(uid: String) async throws {
        let ref = presenceRef(uid)
        let value: [String: Any] = [
            "status": PresenceStatus.offline.rawValue,
            "inGame": false,
            "lastSeen": ServerValue.timestamp(),
        ]
        try await setValue(value, on: ref)
        _ = try await ref.cancelDisconnectOperations()
    }

    /// Updates the subset of presence fields that changed (e.g. entering/leaving a
    /// room mid-session). Only non-nil parameters are written. Pass `clearRoomId: true`
    /// to clear a previously-set `roomId` back to null (e.g. when leaving a room);
    /// `roomId` itself is otherwise only written when non-nil.
    public func updatePresence(
        uid: String,
        inGame: Bool? = nil,
        roomId: String? = nil,
        clearRoomId: Bool = false,
        customStatus: String? = nil
    ) async throws {
        var values: [String: Any] = [:]
        if let inGame { values["inGame"] = inGame }
        if let roomId { values["roomId"] = roomId } else if clearRoomId { values["roomId"] = NSNull() }
        if let customStatus { values["customStatus"] = customStatus }
        guard !values.isEmpty else { return }
        try await updateChildValues(values, on: presenceRef(uid))
    }

    /// Streams `/presence/{uid}`, yielding `nil` when the node doesn't exist.
    public func observePresence(uid: String) -> AsyncThrowingStream<Presence?, Error> {
        AsyncThrowingStream { continuation in
            let ref = presenceRef(uid)
            let handle = ref.observe(.value, with: { snapshot in
                guard snapshot.exists() else {
                    continuation.yield(nil)
                    return
                }
                do {
                    var presence = try snapshot.data(as: Presence.self)
                    presence.uid = uid
                    continuation.yield(presence)
                } catch {
                    continuation.finish(throwing: error)
                }
            }, withCancel: { error in
                continuation.finish(throwing: error)
            })
            continuation.onTermination = { _ in ref.removeObserver(withHandle: handle) }
        }
    }

    // MARK: - Completion-block bridging

    private func setValue(_ value: Any?, on ref: DatabaseReference) async throws {
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

    private func updateChildValues(_ values: [String: Any], on ref: DatabaseReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.updateChildValues(values) { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func onDisconnectSetValue(_ value: Any?, on ref: DatabaseReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.onDisconnectSetValue(value) { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
