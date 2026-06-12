import XCTest
@testable import KadiOnline

final class RealtimeModelCodecTests: XCTestCase {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    func testPresenceRoundTrip() throws {
        let presence = Presence(
            uid: "uid-a",
            status: .online,
            customStatus: "Looking for a game",
            inGame: true,
            roomId: "ABCDEF",
            lastSeen: 1_700_000_000_000
        )
        let data = try encoder.encode(presence)
        let decoded = try decoder.decode(Presence.self, from: data)
        XCTAssertEqual(decoded, presence)
    }

    func testPresenceRoundTripWithNilFields() throws {
        let presence = Presence(status: .offline)
        let data = try encoder.encode(presence)
        let decoded = try decoder.decode(Presence.self, from: data)
        XCTAssertEqual(decoded, presence)
    }

    func testQuickChatMessageRoundTrip() throws {
        let message = QuickChatMessage(uid: "uid-a", message: "gg", timestamp: 1_700_000_000_000)
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(QuickChatMessage.self, from: data)
        XCTAssertEqual(decoded, message)
    }
}
