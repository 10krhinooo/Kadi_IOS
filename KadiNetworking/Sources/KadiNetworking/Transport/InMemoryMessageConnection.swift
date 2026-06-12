import Foundation

/// `MessageConnection` backed by in-memory `AsyncStream`s — no real sockets. Used to unit
/// test the session layer (join flow, action validation/broadcast, disconnect handling)
/// quickly and deterministically.
public actor InMemoryMessageConnection: MessageConnection {
    private let outbox: AsyncStream<NetworkMessage>.Continuation
    private var inbox: AsyncStream<NetworkMessage>.Iterator
    private var isClosed = false

    private init(outbox: AsyncStream<NetworkMessage>.Continuation, inbox: AsyncStream<NetworkMessage>.Iterator) {
        self.outbox = outbox
        self.inbox = inbox
    }

    /// Create a connected pair: messages sent on one side are received on the other.
    public static func pair() -> (InMemoryMessageConnection, InMemoryMessageConnection) {
        let (streamA, continuationA) = AsyncStream<NetworkMessage>.makeStream()
        let (streamB, continuationB) = AsyncStream<NetworkMessage>.makeStream()
        let a = InMemoryMessageConnection(outbox: continuationA, inbox: streamB.makeAsyncIterator())
        let b = InMemoryMessageConnection(outbox: continuationB, inbox: streamA.makeAsyncIterator())
        return (a, b)
    }

    public func send(_ message: NetworkMessage) async throws {
        guard !isClosed else { throw ConnectionError.closed }
        outbox.yield(message)
    }

    public func receive() async throws -> NetworkMessage? {
        var iterator = inbox
        let message = await iterator.next()
        inbox = iterator
        return message
    }

    public func close() {
        guard !isClosed else { return }
        isClosed = true
        outbox.finish()
    }
}
