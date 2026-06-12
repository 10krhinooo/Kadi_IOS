import XCTest
import KadiEngine
@testable import KadiNetworking

final class LobbyUpdatesTests: XCTestCase {
    func testLobbyUpdatesYieldsGrowingRoster() async throws {
        let host = LANGameHost(hostName: "Host", hostUid: "host-uid")

        var lobby = await host.lobbyUpdates().makeAsyncIterator()

        let initial = await lobby.next()
        XCTAssertEqual(initial?.map(\.name), ["Host"])

        let (clientSide1, hostSide1) = InMemoryMessageConnection.pair()
        let client1 = LANGameClient(connection: clientSide1, name: "Alice", uid: "alice-uid", avatarIndex: 1)
        async let acceptTask1: Void = host.acceptConnection(hostSide1)
        try await client1.start()
        await acceptTask1

        let afterAlice = await lobby.next()
        XCTAssertEqual(afterAlice?.map(\.name), ["Host", "Alice"])
        XCTAssertEqual(afterAlice?.last?.avatarIndex, 1)

        let (clientSide2, hostSide2) = InMemoryMessageConnection.pair()
        let client2 = LANGameClient(connection: clientSide2, name: "Bob", uid: "bob-uid", avatarIndex: 2)
        async let acceptTask2: Void = host.acceptConnection(hostSide2)
        try await client2.start()
        await acceptTask2

        let afterBob = await lobby.next()
        XCTAssertEqual(afterBob?.map(\.name), ["Host", "Alice", "Bob"])

        try await host.startGame()
        let afterStart = await lobby.next()
        XCTAssertEqual(afterStart?.map(\.name), ["Host", "Alice", "Bob"])
    }
}
