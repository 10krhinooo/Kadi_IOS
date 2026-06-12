import XCTest
import KadiEngine
@testable import KadiNetworking

final class NetworkMessageCodecTests: XCTestCase {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    private func roundTrip(_ message: NetworkMessage) throws -> NetworkMessage {
        let data = try encoder.encode(message)
        return try decoder.decode(NetworkMessage.self, from: data)
    }

    private func samplePlayer(_ id: String) -> Player {
        Player(id: id, name: id, hand: [PlayingCard(rank: .five, suit: .hearts)], isHuman: true, avatarIndex: 1)
    }

    private func sampleState() throws -> GameState {
        try GameEngine.createGame(players: [samplePlayer("host"), samplePlayer("guest")])
    }

    // MARK: - Literal JSON decoding (per docs/GAME_SPEC.md §J)

    func testDecodeJoinRequest() throws {
        let json = """
        {"type":"joinRequest","payload":{"name":"Alice","uid":"user_abc123","avatarIndex":0}}
        """.data(using: .utf8)!
        let message = try decoder.decode(NetworkMessage.self, from: json)
        XCTAssertEqual(message, .joinRequest(JoinRequestPayload(name: "Alice", uid: "user_abc123", avatarIndex: 0)))
    }

    func testDecodePing() throws {
        let json = """
        {"type":"ping","payload":{}}
        """.data(using: .utf8)!
        let message = try decoder.decode(NetworkMessage.self, from: json)
        XCTAssertEqual(message, .ping)
    }

    func testDecodePlayerActionPlayCards() throws {
        let json = """
        {"type":"playerAction","payload":{"type":"PlayCards","cards":[{"rank":"five","suit":"hearts"}]}}
        """.data(using: .utf8)!
        let message = try decoder.decode(NetworkMessage.self, from: json)
        XCTAssertEqual(message, .playerAction(.playCards(cards: [PlayingCard(rank: .five, suit: .hearts)])))
    }

    func testDecodeChat() throws {
        let json = """
        {"type":"chat","payload":{"text":"nice play!","sender":"Alice"}}
        """.data(using: .utf8)!
        let message = try decoder.decode(NetworkMessage.self, from: json)
        XCTAssertEqual(message, .chat(ChatPayload(text: "nice play!", sender: "Alice")))
    }

    // MARK: - Round trips

    func testJoinAckRoundTrip() throws {
        let payload = JoinAckPayload(playerIndex: 1, players: [samplePlayer("host"), samplePlayer("guest")])
        XCTAssertEqual(try roundTrip(.joinAck(payload)), .joinAck(payload))
    }

    func testPlayerJoinedRoundTrip() throws {
        let payload = PlayerJoinedPayload(playerIndex: 1, player: samplePlayer("guest"))
        XCTAssertEqual(try roundTrip(.playerJoined(payload)), .playerJoined(payload))
    }

    func testPlayerDisconnectedRoundTrip() throws {
        let payload = PlayerDisconnectedPayload(playerIndex: 1)
        XCTAssertEqual(try roundTrip(.playerDisconnected(payload)), .playerDisconnected(payload))
    }

    func testHostTransferRoundTrip() throws {
        let payload = HostTransferPayload(newHostPlayerIndex: 1, newHostUid: "user_abc123")
        XCTAssertEqual(try roundTrip(.hostTransfer(payload)), .hostTransfer(payload))
    }

    func testPongRoundTrip() throws {
        XCTAssertEqual(try roundTrip(.pong), .pong)
    }

    func testGameStateRoundTrips() throws {
        let state = try sampleState()
        XCTAssertEqual(try roundTrip(.gameStateFull(state)), .gameStateFull(state))
        XCTAssertEqual(try roundTrip(.stateDelta(state)), .stateDelta(state))
        XCTAssertEqual(try roundTrip(.gameStart(state)), .gameStart(state))
    }

    func testPlayerActionRoundTrip() throws {
        let action = NetworkMessage.playerAction(.makeDemand(rank: .king, suit: .hearts))
        XCTAssertEqual(try roundTrip(action), action)
    }
}
