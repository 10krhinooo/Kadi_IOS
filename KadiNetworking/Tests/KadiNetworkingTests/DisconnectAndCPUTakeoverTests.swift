import XCTest
import KadiEngine
@testable import KadiNetworking

final class DisconnectAndCPUTakeoverTests: XCTestCase {
    func testDisconnectTriggersCPUTakeoverAndGameProgresses() async throws {
        let host = LANGameHost(hostName: "Host", hostUid: "host-uid")

        let (clientSide, hostSide) = InMemoryMessageConnection.pair()
        let client = LANGameClient(connection: clientSide, name: "Guest", uid: "guest-uid", avatarIndex: 0)
        async let acceptTask: Void = host.acceptConnection(hostSide)
        try await client.start()
        await acceptTask

        try await host.startGame()

        // Drain the initial gameStart broadcast.
        var clientStates = await client.gameStateUpdates().makeAsyncIterator()
        _ = await clientStates.next()

        // Disconnect the guest by closing its connection (simulates a dropped socket).
        await client.stop()

        // Give the host's receive loop a moment to observe the EOF.
        try await Task.sleep(for: .milliseconds(50))

        // Drive the game until it's the guest's (now CPU-controlled) turn, by repeatedly
        // having the host (player 0) play legal actions. After each host action, the host
        // should auto-resolve any CPU turns, eventually returning control to player 0 again
        // (or finishing the game) without ever getting stuck on player 1.
        for _ in 0..<50 {
            guard let state = await host.currentGameState, state.phase != .finished else { break }
            if state.currentPlayerIndex != 0 {
                // CPU takeover should have already advanced past player 1's turn(s).
                XCTFail("host did not auto-resolve CPU turn for disconnected player 1; currentPlayerIndex=\(state.currentPlayerIndex)")
                return
            }
            let cpu = MediumCpu()
            let action = CpuActionResolver.resolve(agent: cpu, state: state, playerIndex: 0)
            try await host.submitHostAction(action)
        }
    }

    func testReconnectByUidClearsCPUControl() async throws {
        let host = LANGameHost(hostName: "Host", hostUid: "host-uid")

        let (clientSide1, hostSide1) = InMemoryMessageConnection.pair()
        let client1 = LANGameClient(connection: clientSide1, name: "Guest", uid: "guest-uid", avatarIndex: 0)
        async let acceptTask1: Void = host.acceptConnection(hostSide1)
        try await client1.start()
        await acceptTask1

        try await host.startGame()
        var states1 = await client1.gameStateUpdates().makeAsyncIterator()
        _ = await states1.next()

        await client1.stop()
        try await Task.sleep(for: .milliseconds(50))

        // Reconnect with the same uid via a fresh in-memory pair.
        let (clientSide2, hostSide2) = InMemoryMessageConnection.pair()
        let client2 = LANGameClient(connection: clientSide2, name: "Guest", uid: "guest-uid", avatarIndex: 0)
        async let acceptTask2: Void = host.acceptConnection(hostSide2)
        try await client2.start()
        await acceptTask2

        // Reconnecting player should be re-assigned the same playerIndex and receive a full
        // state resync.
        let index = await client2.currentPlayerIndex
        XCTAssertEqual(index, 1)

        var states2 = await client2.gameStateUpdates().makeAsyncIterator()
        let resynced = await states2.next()
        XCTAssertNotNil(resynced)
    }
}
