import XCTest
import KadiEngine
@testable import KadiOnline

final class RoomModelCodecTests: XCTestCase {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    private func makeGameState() throws -> GameState {
        let players = [
            Player(id: "host-uid", name: "Host", hand: [], isHuman: true),
            Player(id: "guest-uid", name: "Guest", hand: [], isHuman: true),
        ]
        var rng = SeededGenerator(seed: 1)
        return try GameEngine.createGame(players: players, rules: RuleSet(), using: &rng)
    }

    func testRoomRoundTripPreservesEmbeddedGameState() throws {
        let state = try makeGameState()
        let room = Room(
            roomId: "ABCDEF",
            hostUid: "host-uid",
            hostName: "Host",
            players: [
                RoomPlayer(uid: "host-uid", name: "Host", playerIndex: 0, isConnected: true),
                RoomPlayer(uid: "guest-uid", name: "Guest", playerIndex: 1, isConnected: true),
            ],
            playerUids: ["host-uid", "guest-uid"],
            status: .playing,
            rules: RuleSet(),
            gameState: state,
            quitPenaltyEnabled: true,
            eventSeq: 3,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            startedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let data = try encoder.encode(room)
        let decoded = try decoder.decode(Room.self, from: data)

        XCTAssertEqual(decoded.roomId, room.roomId)
        XCTAssertEqual(decoded.hostUid, room.hostUid)
        XCTAssertEqual(decoded.players, room.players)
        XCTAssertEqual(decoded.playerUids, room.playerUids)
        XCTAssertEqual(decoded.status, room.status)
        XCTAssertEqual(decoded.eventSeq, room.eventSeq)
        XCTAssertEqual(decoded.gameState, room.gameState)
    }

    func testRoomActionRoundTrip() throws {
        let action = RoomAction(
            playerUid: "guest-uid",
            action: .playCards(cards: [PlayingCard(rank: .king, suit: .hearts)]),
            timestamp: Date(timeIntervalSince1970: 1_700_000_200)
        )
        let data = try encoder.encode(action)
        let decoded = try decoder.decode(RoomAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }

    func testRoomEventRoundTrip() throws {
        let event = RoomEvent(seq: 5, kind: "actionApplied", detail: "PlayCards", playerUid: "guest-uid", timestamp: Date(timeIntervalSince1970: 1_700_000_300))
        let data = try encoder.encode(event)
        let decoded = try decoder.decode(RoomEvent.self, from: data)
        XCTAssertEqual(decoded, event)
    }

    func testRoomMessageRoundTrip() throws {
        let message = RoomMessage(senderUid: "host-uid", senderName: "Host", text: "gg", timestamp: Date(timeIntervalSince1970: 1_700_000_400))
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(RoomMessage.self, from: data)
        XCTAssertEqual(decoded, message)
    }

    func testRoomWithNilGameStateRoundTrip() throws {
        let room = Room(
            roomId: "GHJKLM",
            hostUid: "host-uid",
            hostName: "Host",
            players: [RoomPlayer(uid: "host-uid", name: "Host", playerIndex: 0, isConnected: true)],
            playerUids: ["host-uid"],
            status: .waiting,
            rules: RuleSet()
        )
        let data = try encoder.encode(room)
        let decoded = try decoder.decode(Room.self, from: data)
        XCTAssertNil(decoded.gameState)
        XCTAssertEqual(decoded.status, .waiting)
    }
}
