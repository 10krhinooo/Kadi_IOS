import XCTest
@preconcurrency import FirebaseFirestore
@testable import KadiOnline

final class LeaderboardServiceTests: EmulatorTestCase {
    func testFetchTopPlayersOrdersByPointsDescending() async throws {
        let db = Firestore.firestore()
        try await db.collection("users").document("uid-a").setData([
            "uid": "uid-a", "displayName": "Alice", "displayNameLower": "alice", "avatarId": 1,
            "points": 10, "wins": 0, "losses": 0, "gamesPlayed": 0, "quits": 0,
        ])
        try await db.collection("users").document("uid-b").setData([
            "uid": "uid-b", "displayName": "Bob", "displayNameLower": "bob", "avatarId": 2,
            "points": 30, "wins": 0, "losses": 0, "gamesPlayed": 0, "quits": 0,
        ])
        try await db.collection("users").document("uid-c").setData([
            "uid": "uid-c", "displayName": "Carol", "displayNameLower": "carol", "avatarId": 3,
            "points": 20, "wins": 0, "losses": 0, "gamesPlayed": 0, "quits": 0,
        ])

        let service = LeaderboardService()
        let players = try await service.fetchTopPlayers()

        XCTAssertEqual(players.map(\.uid), ["uid-b", "uid-c", "uid-a"])
        XCTAssertEqual(players.map(\.points), [30, 20, 10])
    }

    func testFetchTopPlayersRespectsLimit() async throws {
        let db = Firestore.firestore()
        try await db.collection("users").document("uid-a").setData([
            "uid": "uid-a", "displayName": "Alice", "displayNameLower": "alice", "avatarId": 1,
            "points": 10, "wins": 0, "losses": 0, "gamesPlayed": 0, "quits": 0,
        ])
        try await db.collection("users").document("uid-b").setData([
            "uid": "uid-b", "displayName": "Bob", "displayNameLower": "bob", "avatarId": 2,
            "points": 30, "wins": 0, "losses": 0, "gamesPlayed": 0, "quits": 0,
        ])

        let service = LeaderboardService()
        let players = try await service.fetchTopPlayers(limit: 1)

        XCTAssertEqual(players.map(\.uid), ["uid-b"])
    }
}
