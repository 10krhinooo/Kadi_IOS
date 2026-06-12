import XCTest
import Network
import KadiEngine
@testable import KadiNetworking

final class HostMigrationTests: XCTestCase {
    /// 3-player scenario: the original host (player 0) goes away. Player 1 (the lowest
    /// surviving non-host index) promotes itself to host, seeded with the last-known
    /// `GameState`/roster (player 0's seat becomes CPU-controlled). Player 2 then rejoins
    /// the new host by `uid` over a real loopback TCP connection and is resynced with a
    /// full `gameStateFull`.
    func testLowestIndexClientPromotesAndOtherClientRejoins() async throws {
        let host = LANGameHost(hostName: "Host", hostUid: "host-uid")

        let (client1Side, host1Side) = InMemoryMessageConnection.pair()
        let client1 = LANGameClient(connection: client1Side, name: "P1", uid: "p1-uid", avatarIndex: 0)
        async let accept1: Void = host.acceptConnection(host1Side)
        try await client1.start()
        await accept1

        let (client2Side, host2Side) = InMemoryMessageConnection.pair()
        let client2 = LANGameClient(connection: client2Side, name: "P2", uid: "p2-uid", avatarIndex: 0)
        async let accept2: Void = host.acceptConnection(host2Side)
        try await client2.start()
        await accept2

        try await host.startGame()

        // Drain the initial gameStart broadcast on both clients so their roster/state are
        // populated.
        var client1States = await client1.gameStateUpdates().makeAsyncIterator()
        _ = await client1States.next()
        var client2States = await client2.gameStateUpdates().makeAsyncIterator()
        _ = await client2States.next()

        // Player 1 is the lowest surviving non-host index; player 2 is not.
        let isP1Lowest = await client1.isLowestSurvivingPlayerIndex()
        let isP2Lowest = await client2.isLowestSurvivingPlayerIndex()
        XCTAssertTrue(isP1Lowest)
        XCTAssertFalse(isP2Lowest)

        // Player 1 promotes itself to host, seeded with the last-known state.
        let newHost = try await client1.promoteToHost(gameName: "MigratedGame", rules: RuleSet())
        let newState = await newHost.currentGameState
        XCTAssertNotNil(newState)

        guard let port = await newHost.port else {
            return XCTFail("new host did not bind a port")
        }

        // Player 2 rejoins the new host by uid over a real loopback connection.
        let endpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
        try await client2.reconnect(to: endpoint)

        var client2StatesAfter = await client2.gameStateUpdates().makeAsyncIterator()
        let resynced = await client2StatesAfter.next()
        XCTAssertNotNil(resynced)

        let index2 = await client2.currentPlayerIndex
        XCTAssertEqual(index2, 2)

        await newHost.stop()
    }
}
