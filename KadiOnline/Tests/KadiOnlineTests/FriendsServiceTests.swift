import XCTest
@preconcurrency import FirebaseFirestore
@testable import KadiOnline

final class FriendsServiceTests: EmulatorTestCase {
    func testSendFriendRequestCreatesPendingRequest() async throws {
        let service = FriendsService()
        let requestId = try await service.sendFriendRequest(fromUid: "uid-a", fromName: "Alice", fromAvatarId: 1, toUid: "uid-b")

        let doc = try await Firestore.firestore().collection("friendRequests").document(requestId).getDocument()
        let data = try XCTUnwrap(doc.data())
        XCTAssertEqual(data["fromUid"] as? String, "uid-a")
        XCTAssertEqual(data["toUid"] as? String, "uid-b")
        XCTAssertEqual(data["status"] as? String, "pending")
        XCTAssertNotNil(data["createdAt"])
    }

    func testSendFriendRequestRejectsDuplicatePending() async throws {
        let service = FriendsService()
        _ = try await service.sendFriendRequest(fromUid: "uid-a", fromName: "Alice", fromAvatarId: 1, toUid: "uid-b")

        do {
            _ = try await service.sendFriendRequest(fromUid: "uid-a", fromName: "Alice", fromAvatarId: 1, toUid: "uid-b")
            XCTFail("expected requestAlreadyPending error")
        } catch FriendsServiceError.requestAlreadyPending {
            // expected
        }

        do {
            _ = try await service.sendFriendRequest(fromUid: "uid-b", fromName: "Bob", fromAvatarId: 2, toUid: "uid-a")
            XCTFail("expected requestAlreadyPending error for reverse direction")
        } catch FriendsServiceError.requestAlreadyPending {
            // expected
        }
    }

    func testObserveIncomingFriendRequests() async throws {
        let service = FriendsService()
        _ = try await service.sendFriendRequest(fromUid: "uid-a", fromName: "Alice", fromAvatarId: 1, toUid: "uid-b")

        let stream = service.observeIncomingFriendRequests(uid: "uid-b")
        for try await requests in stream {
            if let first = requests.first {
                XCTAssertEqual(first.fromUid, "uid-a")
                XCTAssertEqual(first.fromName, "Alice")
                XCTAssertEqual(first.status, .pending)
                XCTAssertNotNil(first.id)
                break
            }
        }
    }

    func testAcceptFriendRequestWritesBilateralFriendDocs() async throws {
        let db = Firestore.firestore()
        try await db.collection("users").document("uid-b").setData([
            "uid": "uid-b",
            "displayName": "Bob",
            "displayNameLower": "bob",
            "avatarId": 2,
            "points": 0,
        ])

        let service = FriendsService()
        let requestId = try await service.sendFriendRequest(fromUid: "uid-a", fromName: "Alice", fromAvatarId: 1, toUid: "uid-b")

        try await service.respondToFriendRequest(requestId: requestId, accept: true)

        let requestDoc = try await db.collection("friendRequests").document(requestId).getDocument()
        XCTAssertEqual(requestDoc.data()?["status"] as? String, "accepted")

        let aFriendOfB = try await db.collection("users").document("uid-a").collection("friends").document("uid-b").getDocument()
        let bData = try XCTUnwrap(aFriendOfB.data())
        XCTAssertEqual(bData["uid"] as? String, "uid-b")
        XCTAssertEqual(bData["displayName"] as? String, "Bob")
        XCTAssertEqual(bData["avatarId"] as? Int, 2)
        XCTAssertNotNil(bData["since"])

        let bFriendOfA = try await db.collection("users").document("uid-b").collection("friends").document("uid-a").getDocument()
        let aData = try XCTUnwrap(bFriendOfA.data())
        XCTAssertEqual(aData["uid"] as? String, "uid-a")
        XCTAssertEqual(aData["displayName"] as? String, "Alice")
        XCTAssertEqual(aData["avatarId"] as? Int, 1)
        XCTAssertNotNil(aData["since"])
    }

    func testDeclineFriendRequestMarksDeclined() async throws {
        let service = FriendsService()
        let requestId = try await service.sendFriendRequest(fromUid: "uid-a", fromName: "Alice", fromAvatarId: 1, toUid: "uid-b")

        try await service.respondToFriendRequest(requestId: requestId, accept: false)

        let doc = try await Firestore.firestore().collection("friendRequests").document(requestId).getDocument()
        XCTAssertEqual(doc.data()?["status"] as? String, "declined")
    }

    func testRemoveFriendDeletesBothSides() async throws {
        let db = Firestore.firestore()
        let service = FriendsService()
        try await db.collection("users").document("uid-a").collection("friends").document("uid-b").setData(["uid": "uid-b", "displayName": "Bob", "avatarId": 2])
        try await db.collection("users").document("uid-b").collection("friends").document("uid-a").setData(["uid": "uid-a", "displayName": "Alice", "avatarId": 1])

        try await service.removeFriend(uid: "uid-a", friendUid: "uid-b")

        let aSide = try await db.collection("users").document("uid-a").collection("friends").document("uid-b").getDocument()
        let bSide = try await db.collection("users").document("uid-b").collection("friends").document("uid-a").getDocument()
        XCTAssertFalse(aSide.exists)
        XCTAssertFalse(bSide.exists)
    }

    func testBlockAndUnblockUser() async throws {
        let service = FriendsService()
        try await service.blockUser(uid: "uid-a", targetUid: "uid-b")

        let stream = service.observeBlockedUsers(uid: "uid-a")
        for try await blocked in stream {
            if let first = blocked.first {
                XCTAssertEqual(first.uid, "uid-b")
                XCTAssertNotNil(first.blockedAt)
                break
            }
        }

        try await service.unblockUser(uid: "uid-a", targetUid: "uid-b")
        let doc = try await Firestore.firestore().collection("blocks").document("uid-a").collection("blocked").document("uid-b").getDocument()
        XCTAssertFalse(doc.exists)
    }
}
