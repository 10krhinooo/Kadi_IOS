import XCTest
import KadiEngine
@testable import KadiNetworking

final class ConnectionEventsTests: XCTestCase {
    func testHostConnectionEventsOnDisconnectAndReconnect() async throws {
        let host = LANGameHost(hostName: "Host", hostUid: "host-uid")

        let (clientSide1, hostSide1) = InMemoryMessageConnection.pair()
        let client1 = LANGameClient(connection: clientSide1, name: "Guest", uid: "guest-uid", avatarIndex: 0)
        async let acceptTask1: Void = host.acceptConnection(hostSide1)
        try await client1.start()
        await acceptTask1

        try await host.startGame()
        var clientStates = await client1.gameStateUpdates().makeAsyncIterator()
        _ = await clientStates.next()

        var hostEvents = await host.connectionEvents().makeAsyncIterator()

        await client1.stop()
        try await Task.sleep(for: .milliseconds(50))

        let disconnected = await hostEvents.next()
        XCTAssertEqual(disconnected, .playerDisconnected(playerIndex: 1))

        // Reconnect with the same uid via a fresh in-memory pair.
        let (clientSide2, hostSide2) = InMemoryMessageConnection.pair()
        let client2 = LANGameClient(connection: clientSide2, name: "Guest", uid: "guest-uid", avatarIndex: 0)
        async let acceptTask2: Void = host.acceptConnection(hostSide2)
        try await client2.start()
        await acceptTask2

        let reconnected = await hostEvents.next()
        XCTAssertEqual(reconnected, .playerReconnected(playerIndex: 1))
    }

    func testClientConnectionEventsObserveOtherPlayerDisconnectAndReconnect() async throws {
        let host = LANGameHost(hostName: "Host", hostUid: "host-uid")

        let (aliceClientSide, aliceHostSide) = InMemoryMessageConnection.pair()
        let alice = LANGameClient(connection: aliceClientSide, name: "Alice", uid: "alice-uid", avatarIndex: 0)
        async let aliceAccept: Void = host.acceptConnection(aliceHostSide)
        try await alice.start()
        await aliceAccept

        let (bobClientSide, bobHostSide) = InMemoryMessageConnection.pair()
        let bob = LANGameClient(connection: bobClientSide, name: "Bob", uid: "bob-uid", avatarIndex: 0)
        async let bobAccept: Void = host.acceptConnection(bobHostSide)
        try await bob.start()
        await bobAccept

        try await host.startGame()

        var aliceStates = await alice.gameStateUpdates().makeAsyncIterator()
        _ = await aliceStates.next()
        var bobStates = await bob.gameStateUpdates().makeAsyncIterator()
        _ = await bobStates.next()

        var aliceEvents = await alice.connectionEvents().makeAsyncIterator()

        // Bob disconnects; Alice should observe it via the host's broadcast.
        await bob.stop()
        try await Task.sleep(for: .milliseconds(50))

        let disconnected = await aliceEvents.next()
        XCTAssertEqual(disconnected, .playerDisconnected(playerIndex: 2))

        // Bob reconnects with the same uid.
        let (bobClientSide2, bobHostSide2) = InMemoryMessageConnection.pair()
        let bob2 = LANGameClient(connection: bobClientSide2, name: "Bob", uid: "bob-uid", avatarIndex: 0)
        async let bobAccept2: Void = host.acceptConnection(bobHostSide2)
        try await bob2.start()
        await bobAccept2

        let reconnected = await aliceEvents.next()
        XCTAssertEqual(reconnected, .playerReconnected(playerIndex: 2))
    }
}
