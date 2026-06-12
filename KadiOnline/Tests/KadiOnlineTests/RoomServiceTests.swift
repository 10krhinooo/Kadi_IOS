import XCTest
@preconcurrency import FirebaseFirestore
import KadiEngine
@testable import KadiOnline

final class RoomServiceTests: EmulatorTestCase {
    func testCreateRoomProducesValidRoomId() async throws {
        let service = RoomService()
        let roomId = try await service.createRoom(hostUid: "host-1", hostName: "Host", rules: RuleSet())

        XCTAssertEqual(roomId.count, RoomIdGenerator.length)
        for character in roomId {
            XCTAssertTrue(RoomIdGenerator.alphabet.contains(character))
        }

        let doc = try await Firestore.firestore().collection("rooms").document(roomId).getDocument()
        let data = try XCTUnwrap(doc.data())
        XCTAssertEqual(data["hostUid"] as? String, "host-1")
        XCTAssertEqual(data["hostName"] as? String, "Host")
        XCTAssertEqual(data["status"] as? String, "waiting")
        XCTAssertEqual(data["playerUids"] as? [String], ["host-1"])
        XCTAssertEqual(data["eventSeq"] as? Int, 0)
        XCTAssertNotNil(data["createdAt"])

        let players = try XCTUnwrap(data["players"] as? [[String: Any]])
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(players[0]["uid"] as? String, "host-1")
        XCTAssertEqual(players[0]["playerIndex"] as? Int, 0)
    }

    func testJoinRoomAssignsNextPlayerIndex() async throws {
        let service = RoomService()
        let roomId = try await service.createRoom(hostUid: "host-1", hostName: "Host", rules: RuleSet())

        let index = try await service.joinRoom(roomId: roomId, uid: "guest-1", name: "Guest")
        XCTAssertEqual(index, 1)

        let doc = try await Firestore.firestore().collection("rooms").document(roomId).getDocument()
        let data = try XCTUnwrap(doc.data())
        XCTAssertEqual(data["playerUids"] as? [String], ["host-1", "guest-1"])
        let players = try XCTUnwrap(data["players"] as? [[String: Any]])
        XCTAssertEqual(players.count, 2)
        XCTAssertEqual(players[1]["uid"] as? String, "guest-1")
        XCTAssertEqual(players[1]["playerIndex"] as? Int, 1)
    }

    func testJoinRoomRejectsWhenFull() async throws {
        let service = RoomService(maxPlayers: 2)
        let roomId = try await service.createRoom(hostUid: "host-1", hostName: "Host", rules: RuleSet())
        _ = try await service.joinRoom(roomId: roomId, uid: "guest-1", name: "Guest1")

        do {
            _ = try await service.joinRoom(roomId: roomId, uid: "guest-2", name: "Guest2")
            XCTFail("expected roomFull error")
        } catch RoomServiceError.roomFull {
            // expected
        }
    }

    func testJoinRoomRejectsWhenAlreadyStarted() async throws {
        let service = RoomService()
        let roomId = try await service.createRoom(hostUid: "host-1", hostName: "Host", rules: RuleSet())
        try await Firestore.firestore().collection("rooms").document(roomId).updateData(["status": RoomStatus.playing.rawValue])

        do {
            _ = try await service.joinRoom(roomId: roomId, uid: "guest-1", name: "Guest")
            XCTFail("expected roomAlreadyStarted error")
        } catch RoomServiceError.roomAlreadyStarted {
            // expected
        }
    }

    func testRejoinReturnsExistingIndex() async throws {
        let service = RoomService()
        let roomId = try await service.createRoom(hostUid: "host-1", hostName: "Host", rules: RuleSet())
        _ = try await service.joinRoom(roomId: roomId, uid: "guest-1", name: "Guest")

        let index = try await service.joinRoom(roomId: roomId, uid: "guest-1", name: "Guest")
        XCTAssertEqual(index, 1)

        let doc = try await Firestore.firestore().collection("rooms").document(roomId).getDocument()
        let players = try XCTUnwrap(doc.data()?["players"] as? [[String: Any]])
        XCTAssertEqual(players.count, 2, "rejoining should not duplicate the seat")
    }

    func testSendAndObserveMessages() async throws {
        let service = RoomService()
        let roomId = try await service.createRoom(hostUid: "host-1", hostName: "Host", rules: RuleSet())

        try await service.sendMessage(roomId: roomId, senderUid: "host-1", senderName: "Host", text: "gg")

        let stream = service.observeMessages(roomId: roomId)
        for try await messages in stream {
            if let first = messages.first {
                XCTAssertEqual(first.senderUid, "host-1")
                XCTAssertEqual(first.text, "gg")
                break
            }
        }
    }

    func testDeleteRoom() async throws {
        let service = RoomService()
        let roomId = try await service.createRoom(hostUid: "host-1", hostName: "Host", rules: RuleSet())
        try await service.deleteRoom(roomId: roomId)

        let doc = try await Firestore.firestore().collection("rooms").document(roomId).getDocument()
        XCTAssertFalse(doc.exists)
    }
}
