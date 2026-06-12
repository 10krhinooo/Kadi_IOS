@preconcurrency import FirebaseFirestore
import Foundation

/// Leaderboard queries over `/users`, per docs/GAME_SPEC.md §L.
public struct LeaderboardService: Sendable {
    private let db: Firestore

    public init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    /// Returns the top `limit` players ordered by `points` descending.
    public func fetchTopPlayers(limit: Int = 50) async throws -> [UserProfile] {
        let snapshot = try await db.collection("users")
            .order(by: "points", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: UserProfile.self) }
    }
}
