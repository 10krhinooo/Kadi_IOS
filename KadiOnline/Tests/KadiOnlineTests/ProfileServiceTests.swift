import XCTest
@preconcurrency import FirebaseFirestore
@testable import KadiOnline

final class ProfileServiceTests: EmulatorTestCase {
    func testEnsureProfileSetsCreatedAtAndZeroedStatsOnFirstCall() async throws {
        let service = ProfileService()
        let uid = UUID().uuidString

        try await service.ensureProfile(uid: uid, displayName: "Alice", email: "alice@example.com", avatarId: 2)

        let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
        XCTAssertTrue(doc.exists)
        let data = try XCTUnwrap(doc.data())

        XCTAssertEqual(data["uid"] as? String, uid)
        XCTAssertEqual(data["displayName"] as? String, "Alice")
        XCTAssertEqual(data["displayNameLower"] as? String, "alice")
        XCTAssertEqual(data["email"] as? String, "alice@example.com")
        XCTAssertEqual(data["avatarId"] as? Int, 2)
        XCTAssertEqual(data["points"] as? Int, 0)
        XCTAssertEqual(data["wins"] as? Int, 0)
        XCTAssertEqual(data["losses"] as? Int, 0)
        XCTAssertEqual(data["gamesPlayed"] as? Int, 0)
        XCTAssertEqual(data["quits"] as? Int, 0)
        XCTAssertNotNil(data["createdAt"])
        XCTAssertNotNil(data["lastSeen"])
    }

    func testEnsureProfileNeverOverwritesStatsOnSubsequentCalls() async throws {
        let service = ProfileService()
        let uid = UUID().uuidString
        let ref = Firestore.firestore().collection("users").document(uid)

        try await service.ensureProfile(uid: uid, displayName: "Bob", email: "bob@example.com", avatarId: 0)

        // Simulate stats accrued via gameplay (would normally be FieldValue.increment via
        // Cloud Functions in a later phase).
        try await ref.updateData(["points": 50, "wins": 3, "losses": 1, "gamesPlayed": 4, "quits": 0])

        // Re-run ensureProfile, e.g. on a later sign-in with a changed display name.
        try await service.ensureProfile(uid: uid, displayName: "Bobby", email: "bob@example.com", avatarId: 1)

        let doc = try await ref.getDocument()
        let data = try XCTUnwrap(doc.data())

        XCTAssertEqual(data["displayName"] as? String, "Bobby")
        XCTAssertEqual(data["displayNameLower"] as? String, "bobby")
        XCTAssertEqual(data["avatarId"] as? Int, 1)
        // Stats untouched.
        XCTAssertEqual(data["points"] as? Int, 50)
        XCTAssertEqual(data["wins"] as? Int, 3)
        XCTAssertEqual(data["losses"] as? Int, 1)
        XCTAssertEqual(data["gamesPlayed"] as? Int, 4)
        // createdAt should not be overwritten on second call.
        let createdAtFirst = try await ref.getDocument().data()?["createdAt"] as? Timestamp
        XCTAssertNotNil(createdAtFirst)
    }

    func testEnsureProfileWithoutEmail() async throws {
        let service = ProfileService()
        let uid = UUID().uuidString

        try await service.ensureProfile(uid: uid, displayName: "NoEmail", email: nil, avatarId: 0)

        let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
        let data = try XCTUnwrap(doc.data())
        XCTAssertNil(data["email"])
    }
}
