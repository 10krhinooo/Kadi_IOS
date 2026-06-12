import XCTest
import Network
import KadiEngine
@testable import KadiNetworking

final class LANGameHostClientTests: XCTestCase {
    /// Connects a `LANGameClient` to a `LANGameHost` over an in-memory pair, performing the
    /// join handshake, without any real sockets.
    private func connectClient(
        to host: LANGameHost,
        name: String,
        uid: String,
        avatarIndex: Int = 0
    ) async throws -> LANGameClient {
        let (clientSide, hostSide) = InMemoryMessageConnection.pair()
        let client = LANGameClient(connection: clientSide, name: name, uid: uid, avatarIndex: avatarIndex)
        async let acceptTask: Void = host.acceptConnection(hostSide)
        try await client.start()
        await acceptTask
        return client
    }

    func testJoinHandshakeAssignsPlayerIndexAndRoster() async throws {
        let host = LANGameHost(hostName: "Host", hostUid: "host-uid")
        let client = try await connectClient(to: host, name: "Guest", uid: "guest-uid")

        var rosterIterator = await client.rosterUpdates().makeAsyncIterator()
        let roster = await rosterIterator.next()

        let index = await client.currentPlayerIndex
        XCTAssertEqual(index, 1)
        XCTAssertEqual(roster?.map(\.id), ["host-uid", "guest-uid"])
    }

    func testGameStartBroadcastsInitialState() async throws {
        let host = LANGameHost(hostName: "Host", hostUid: "host-uid")
        let client = try await connectClient(to: host, name: "Guest", uid: "guest-uid")

        var stateIterator = await client.gameStateUpdates().makeAsyncIterator()
        try await host.startGame()

        let state = await stateIterator.next()
        XCTAssertEqual(state?.players.map(\.id), ["host-uid", "guest-uid"])
        XCTAssertEqual(state?.phase, .playing)
        XCTAssertEqual(state?.currentPlayerIndex, 0)
    }

    func testPlayerActionAppliedAndBroadcast() async throws {
        let host = LANGameHost(hostName: "Host", hostUid: "host-uid")
        let client = try await connectClient(to: host, name: "Guest", uid: "guest-uid")
        try await host.startGame()

        var clientStates = await client.gameStateUpdates().makeAsyncIterator()
        _ = await clientStates.next() // initial gameStart

        // Find a legal action for the host (player 0, currentPlayerIndex == 0).
        guard let initialState = await host.currentGameState else {
            return XCTFail("game not started")
        }
        let cpu = MediumCpu()
        let action = CpuActionResolver.resolve(agent: cpu, state: initialState, playerIndex: 0)
        try await host.submitHostAction(action)

        let updated = await clientStates.next()
        XCTAssertNotEqual(updated, initialState)
        let hostState = await host.currentGameState
        XCTAssertEqual(hostState, updated)
    }

    func testInvalidPlayerActionIsSilentlyDropped() async throws {
        let host = LANGameHost(hostName: "Host", hostUid: "host-uid")
        let client = try await connectClient(to: host, name: "Guest", uid: "guest-uid")
        try await host.startGame()

        var clientStates = await client.gameStateUpdates().makeAsyncIterator()
        let initial = await clientStates.next()

        // It's player 0's (host's) turn, so the guest (player 1) sending an action should be
        // rejected silently — no stateDelta, state unchanged.
        try await client.sendAction(.pass)

        // Give the host a moment to (not) process it.
        try await Task.sleep(for: .milliseconds(50))

        let hostState = await host.currentGameState
        XCTAssertEqual(hostState, initial)
    }

    func testClientRepliesToPingWithPong() async throws {
        let (clientSide, hostSide) = InMemoryMessageConnection.pair()
        let client = LANGameClient(connection: clientSide, name: "Guest", uid: "guest-uid", avatarIndex: 0)
        try await client.start()
        _ = try await hostSide.receive() // joinRequest

        try await hostSide.send(.ping)
        let response = try await hostSide.receive()
        XCTAssertEqual(response, .pong)
    }
}
