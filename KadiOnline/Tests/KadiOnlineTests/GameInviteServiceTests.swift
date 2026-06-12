import XCTest
@preconcurrency import FirebaseFirestore
@testable import KadiOnline

final class GameInviteServiceTests: EmulatorTestCase {
    func testSendInviteWritesExpectedFields() async throws {
        let service = GameInviteService()
        let inviteId = try await service.sendInvite(fromUid: "uid-a", fromName: "Alice", toUid: "uid-b", roomId: "ABCDEF")

        let doc = try await Firestore.firestore().collection("gameInvites").document(inviteId).getDocument()
        let data = try XCTUnwrap(doc.data())
        XCTAssertEqual(data["fromUid"] as? String, "uid-a")
        XCTAssertEqual(data["fromName"] as? String, "Alice")
        XCTAssertEqual(data["toUid"] as? String, "uid-b")
        XCTAssertEqual(data["roomId"] as? String, "ABCDEF")
        XCTAssertNotNil(data["createdAt"])

        let expiresAt = try XCTUnwrap(data["expiresAt"] as? Timestamp)
        XCTAssertGreaterThan(expiresAt.dateValue(), Date())
    }

    func testObserveIncomingInvitesReturnsInvite() async throws {
        let service = GameInviteService()
        _ = try await service.sendInvite(fromUid: "uid-a", fromName: "Alice", toUid: "uid-b", roomId: "ABCDEF")

        let stream = service.observeIncomingInvites(uid: "uid-b")
        for try await invites in stream {
            if let first = invites.first(where: { $0.roomId == "ABCDEF" }) {
                XCTAssertEqual(first.fromUid, "uid-a")
                XCTAssertNotNil(first.id)
                break
            }
        }
    }

    func testObserveIncomingInvitesFiltersExpired() async throws {
        let service = GameInviteService()
        _ = try await service.sendInvite(fromUid: "uid-a", fromName: "Alice", toUid: "uid-b", roomId: "EXPIRED", ttl: -1)
        _ = try await service.sendInvite(fromUid: "uid-a", fromName: "Alice", toUid: "uid-b", roomId: "ACTIVE", ttl: GameInviteService.defaultTTL)

        let stream = service.observeIncomingInvites(uid: "uid-b")
        for try await invites in stream {
            XCTAssertEqual(invites.map(\.roomId), ["ACTIVE"])
            break
        }
    }

    func testDeleteInviteRemovesDoc() async throws {
        let service = GameInviteService()
        let inviteId = try await service.sendInvite(fromUid: "uid-a", fromName: "Alice", toUid: "uid-b", roomId: "ABCDEF")

        try await service.deleteInvite(inviteId: inviteId)

        let doc = try await Firestore.firestore().collection("gameInvites").document(inviteId).getDocument()
        XCTAssertFalse(doc.exists)
    }
}
