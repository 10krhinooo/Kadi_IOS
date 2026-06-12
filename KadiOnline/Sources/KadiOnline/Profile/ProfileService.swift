@preconcurrency import FirebaseFirestore
import Foundation

/// Manages `/users/{uid}` profile documents, per docs/GAME_SPEC.md §L.
public struct ProfileService: Sendable {
    private let db: Firestore

    public init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    /// Upserts `/users/{uid}` with `merge: true`.
    ///
    /// - On first call (document doesn't exist yet): sets `createdAt` to the server
    ///   timestamp and initializes `points`/`wins`/`losses`/`gamesPlayed`/`quits` to `0`.
    /// - On every call: refreshes `displayName`, `displayNameLower` (lowercased),
    ///   `email`, `avatarId`, and `lastSeen`.
    /// - Never includes stat fields (`points`/`wins`/`losses`/`gamesPlayed`/`quits`) on
    ///   subsequent calls, so `merge: true` leaves them untouched.
    public func ensureProfile(uid: String, displayName: String, email: String?, avatarId: Int) async throws {
        let ref = db.collection("users").document(uid)
        let snapshot = try await ref.getDocument()

        var data: [String: Any] = [
            "uid": uid,
            "displayName": displayName,
            "displayNameLower": displayName.lowercased(),
            "avatarId": avatarId,
            "lastSeen": FieldValue.serverTimestamp(),
        ]
        if let email {
            data["email"] = email
        }

        if !snapshot.exists {
            data["createdAt"] = FieldValue.serverTimestamp()
            data["points"] = 0
            data["wins"] = 0
            data["losses"] = 0
            data["gamesPlayed"] = 0
            data["quits"] = 0
        }

        try await ref.setData(data, merge: true)
    }

    /// Fetches `/users/{uid}`, if it exists.
    public func fetchProfile(uid: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        return try snapshot.data(as: UserProfile?.self)
    }
}
