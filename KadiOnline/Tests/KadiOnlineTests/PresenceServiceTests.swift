import XCTest
@testable import KadiOnline

final class PresenceServiceTests: EmulatorTestCase {
    func testGoOnlineWritesOnlinePresence() async throws {
        let service = PresenceService()
        try await service.goOnline(uid: "uid-a", inGame: true, roomId: "ABCDEF")

        let stream = service.observePresence(uid: "uid-a")
        for try await presence in stream {
            if let presence {
                XCTAssertEqual(presence.uid, "uid-a")
                XCTAssertEqual(presence.status, .online)
                XCTAssertTrue(presence.inGame)
                XCTAssertEqual(presence.roomId, "ABCDEF")
                XCTAssertNotNil(presence.lastSeen)
                break
            }
        }
    }

    func testGoOfflineWritesOfflinePresence() async throws {
        let service = PresenceService()
        try await service.goOnline(uid: "uid-a", inGame: true, roomId: "ABCDEF")
        try await service.goOffline(uid: "uid-a")

        let stream = service.observePresence(uid: "uid-a")
        for try await presence in stream {
            if let presence {
                XCTAssertEqual(presence.status, .offline)
                XCTAssertFalse(presence.inGame)
                break
            }
        }
    }

    func testUpdatePresenceWritesOnlyProvidedFields() async throws {
        let service = PresenceService()
        try await service.goOnline(uid: "uid-a", inGame: false)
        try await service.updatePresence(uid: "uid-a", inGame: true, roomId: "ZZZZZZ", customStatus: "Ready to play")

        let stream = service.observePresence(uid: "uid-a")
        for try await presence in stream {
            if let presence, presence.inGame {
                XCTAssertEqual(presence.status, .online)
                XCTAssertEqual(presence.roomId, "ZZZZZZ")
                XCTAssertEqual(presence.customStatus, "Ready to play")
                break
            }
        }
    }

    func testObservePresenceYieldsNilForMissingNode() async throws {
        let service = PresenceService()

        let stream = service.observePresence(uid: "missing-uid")
        for try await presence in stream {
            XCTAssertNil(presence)
            break
        }
    }
}
