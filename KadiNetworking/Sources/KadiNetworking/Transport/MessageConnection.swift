import Foundation

/// Errors thrown by `MessageConnection` implementations.
public enum ConnectionError: Error, Sendable, Equatable {
    /// `send` was called after the connection was closed.
    case closed
}

/// Protocol abstraction over a bidirectional `NetworkMessage` stream.
///
/// Implemented by `NWMessageConnection` (real TCP via `Network.framework`, NDJSON-framed)
/// and `InMemoryMessageConnection` (paired in-memory transport for unit tests).
public protocol MessageConnection: Actor {
    /// Send a single message.
    func send(_ message: NetworkMessage) async throws
    /// Await the next message, or `nil` if the connection closed cleanly (EOF).
    func receive() async throws -> NetworkMessage?
    /// Close the connection. Any pending `receive()` calls resolve to `nil`.
    func close() async
}
