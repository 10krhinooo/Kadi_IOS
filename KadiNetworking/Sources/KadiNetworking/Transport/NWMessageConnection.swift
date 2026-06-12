import Foundation
import Network

/// `MessageConnection` backed by an `NWConnection`, framing messages as NDJSON
/// (see `NDJSONFramer`).
public actor NWMessageConnection: MessageConnection {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private var lineBuffer = NDJSONLineBuffer()
    private var pendingMessages: [NetworkMessage] = []
    private var pendingError: Error?
    private var isClosed = false
    private var waiters: [CheckedContinuation<NetworkMessage?, Error>] = []

    public init(connection: NWConnection, queue: DispatchQueue? = nil) {
        self.connection = connection
        self.queue = queue ?? DispatchQueue(label: "KadiNetworking.NWMessageConnection")
    }

    /// Create and start a client connection to `endpoint`, suspending until ready.
    public static func connect(to endpoint: NWEndpoint, parameters: NWParameters = .tcp) async throws -> NWMessageConnection {
        let connection = NWConnection(to: endpoint, using: parameters)
        let messageConnection = NWMessageConnection(connection: connection)
        try await messageConnection.start()
        return messageConnection
    }

    /// Wrap an already-accepted `NWConnection` (from an `NWListener`) and start it.
    public static func accepted(_ connection: NWConnection) async throws -> NWMessageConnection {
        let messageConnection = NWMessageConnection(connection: connection)
        try await messageConnection.start()
        return messageConnection
    }

    /// Start the underlying connection and wait until it's ready.
    public func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            nonisolated(unsafe) var didResume = false
            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    if !didResume {
                        didResume = true
                        continuation.resume()
                    }
                    Task { await self?.installSteadyStateHandler() }
                case .failed(let error):
                    if !didResume {
                        didResume = true
                        continuation.resume(throwing: error)
                    } else {
                        Task { await self?.fail(error) }
                    }
                case .cancelled:
                    if !didResume {
                        didResume = true
                        continuation.resume(throwing: CancellationError())
                    } else {
                        Task { await self?.fail(CancellationError()) }
                    }
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
        beginReceiveLoop()
    }

    private func installSteadyStateHandler() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error):
                Task { await self?.fail(error) }
            case .cancelled:
                Task { await self?.fail(CancellationError()) }
            default:
                break
            }
        }
    }

    public func send(_ message: NetworkMessage) async throws {
        guard !isClosed else { throw ConnectionError.closed }
        let data = try NDJSONFramer.encode(message)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    public func receive() async throws -> NetworkMessage? {
        if !pendingMessages.isEmpty {
            return pendingMessages.removeFirst()
        }
        if let error = pendingError {
            pendingError = nil
            throw error
        }
        if isClosed {
            return nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
    }

    public func close() {
        guard !isClosed else { return }
        isClosed = true
        connection.cancel()
        for waiter in waiters {
            waiter.resume(returning: nil)
        }
        waiters.removeAll()
    }

    private func beginReceiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { await self?.handleReceive(data: data, isComplete: isComplete, error: error) }
        }
    }

    private func handleReceive(data: Data?, isComplete: Bool, error: NWError?) {
        guard !isClosed else { return }

        if let data, !data.isEmpty {
            do {
                let messages = try lineBuffer.feed(data)
                for message in messages {
                    deliver(.success(message))
                }
            } catch {
                deliver(.failure(error))
                close()
                return
            }
        }

        if let error {
            deliver(.failure(error))
            close()
            return
        }

        if isComplete {
            isClosed = true
            connection.cancel()
            for waiter in waiters {
                waiter.resume(returning: nil)
            }
            waiters.removeAll()
            return
        }

        beginReceiveLoop()
    }

    private func deliver(_ result: Result<NetworkMessage, Error>) {
        if waiters.isEmpty {
            switch result {
            case .success(let message):
                pendingMessages.append(message)
            case .failure(let error):
                pendingError = error
            }
            return
        }
        let waiter = waiters.removeFirst()
        switch result {
        case .success(let message):
            waiter.resume(returning: message)
        case .failure(let error):
            waiter.resume(throwing: error)
        }
    }

    private func fail(_ error: Error) {
        guard !isClosed else { return }
        isClosed = true
        pendingError = error
        for waiter in waiters {
            waiter.resume(throwing: error)
        }
        waiters.removeAll()
    }
}
