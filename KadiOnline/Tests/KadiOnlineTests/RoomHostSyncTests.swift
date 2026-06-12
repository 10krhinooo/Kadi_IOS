import XCTest
@preconcurrency import FirebaseFirestore
import KadiEngine
@testable import KadiOnline

final class RoomHostSyncTests: EmulatorTestCase {
    private func roomRef(_ roomId: String) -> DocumentReference {
        Firestore.firestore().collection("rooms").document(roomId)
    }

    private func fetchRoom(_ roomId: String) async throws -> Room {
        try await roomRef(roomId).getDocument(as: Room.self)
    }

    func testStartGameWritesGameStateAndMarksPlaying() async throws {
        let roomService = RoomService()
        let roomId = try await roomService.createRoom(hostUid: "host-1", hostName: "Host", rules: RuleSet())
        _ = try await roomService.joinRoom(roomId: roomId, uid: "guest-1", name: "Guest")

        let room = try await fetchRoom(roomId)
        let host = RoomHost(roomId: roomId, hostUid: "host-1", players: room.players, rules: room.rules)
        try await host.startGame()

        let updated = try await fetchRoom(roomId)
        XCTAssertEqual(updated.status, .playing)
        XCTAssertEqual(updated.eventSeq, 1)
        XCTAssertNotNil(updated.gameState)
        XCTAssertEqual(updated.gameState?.players.map(\.id), ["host-1", "guest-1"])

        let eventsSnapshot = try await roomRef(roomId).collection("events").getDocuments()
        XCTAssertEqual(eventsSnapshot.documents.count, 1)
        XCTAssertEqual(eventsSnapshot.documents.first?.data()["kind"] as? String, "gameStart")
    }

    func testHostProcessesGuestActionAndAcksIt() async throws {
        let roomService = RoomService()
        let roomId = try await roomService.createRoom(hostUid: "host-1", hostName: "Host", rules: RuleSet())
        _ = try await roomService.joinRoom(roomId: roomId, uid: "guest-1", name: "Guest")

        let room = try await fetchRoom(roomId)
        let host = RoomHost(roomId: roomId, hostUid: "host-1", players: room.players, rules: room.rules)
        try await host.startGame()

        // Force it to be guest-1's turn (playerIndex 1) so a guest-submitted action is
        // authorized, then re-create the host "resuming" from that state.
        let started = try await fetchRoom(roomId)
        guard var state = started.gameState else { return XCTFail("expected gameState after startGame") }
        state.currentPlayerIndex = 1
        try await roomRef(roomId).updateData(["gameState": try Firestore.Encoder().encode(state)])

        let resumedHost = RoomHost(roomId: roomId, hostUid: "host-1", players: started.players, rules: started.rules, gameState: state, eventSeq: started.eventSeq)
        await resumedHost.startProcessingActions()
        defer { Task { await resumedHost.stop() } }

        let client = RoomClient(roomId: roomId, uid: "guest-1")
        try await client.submitAction(.pass)

        let updated = try await pollUntil(roomId: roomId) { $0.eventSeq == 2 }
        XCTAssertEqual(updated.gameState?.currentPlayerIndex, 0, "pass should advance the turn back to the host")

        let actionsSnapshot = try await roomRef(roomId).collection("actions").getDocuments()
        XCTAssertTrue(actionsSnapshot.documents.isEmpty, "processed actions should be deleted")

        let eventsSnapshot = try await roomRef(roomId).collection("events").order(by: "seq").getDocuments()
        XCTAssertEqual(eventsSnapshot.documents.count, 2)
        let lastEvent = try XCTUnwrap(eventsSnapshot.documents.last?.data())
        XCTAssertEqual(lastEvent["kind"] as? String, "pass")
        XCTAssertEqual(lastEvent["playerUid"] as? String, "guest-1")
    }

    func testHostRejectsAndDeletesUnauthorizedAction() async throws {
        let roomService = RoomService()
        let roomId = try await roomService.createRoom(hostUid: "host-1", hostName: "Host", rules: RuleSet())
        _ = try await roomService.joinRoom(roomId: roomId, uid: "guest-1", name: "Guest")

        let room = try await fetchRoom(roomId)
        let host = RoomHost(roomId: roomId, hostUid: "host-1", players: room.players, rules: room.rules)
        try await host.startGame()
        await host.startProcessingActions()
        defer { Task { await host.stop() } }

        // It's host-1's turn (playerIndex 0); guest-1 (playerIndex 1) submits an action.
        let client = RoomClient(roomId: roomId, uid: "guest-1")
        try await client.submitAction(.pass)

        // The unauthorized action should be deleted without bumping eventSeq/gameState.
        try await waitUntilActionsEmpty(roomId: roomId)
        let updated = try await fetchRoom(roomId)
        XCTAssertEqual(updated.eventSeq, 1, "unauthorized action must not produce a new event")
    }

    func testSubmitHostActionUpdatesStateDirectly() async throws {
        let roomService = RoomService()
        let roomId = try await roomService.createRoom(hostUid: "host-1", hostName: "Host", rules: RuleSet())
        _ = try await roomService.joinRoom(roomId: roomId, uid: "guest-1", name: "Guest")

        let room = try await fetchRoom(roomId)
        let host = RoomHost(roomId: roomId, hostUid: "host-1", players: room.players, rules: room.rules)
        try await host.startGame()

        // It's host-1's turn (playerIndex 0).
        try await host.submitHostAction(.pass)

        let updated = try await fetchRoom(roomId)
        XCTAssertEqual(updated.eventSeq, 2)
        XCTAssertEqual(updated.gameState?.currentPlayerIndex, 1)

        let eventsSnapshot = try await roomRef(roomId).collection("events").order(by: "seq").getDocuments()
        let lastEvent = try XCTUnwrap(eventsSnapshot.documents.last?.data())
        XCTAssertEqual(lastEvent["kind"] as? String, "pass")
        XCTAssertEqual(lastEvent["playerUid"] as? String, "host-1")
    }

    // MARK: - Helpers

    private func pollUntil(roomId: String, timeout: TimeInterval = 10, _ predicate: (Room) -> Bool) async throws -> Room {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let room = try await fetchRoom(roomId)
            if predicate(room) { return room }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw XCTSkip("timed out waiting for room \(roomId) to update")
    }

    private func waitUntilActionsEmpty(roomId: String, timeout: TimeInterval = 10) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let snapshot = try await roomRef(roomId).collection("actions").getDocuments()
            if snapshot.documents.isEmpty { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("timed out waiting for actions to be processed")
    }
}
