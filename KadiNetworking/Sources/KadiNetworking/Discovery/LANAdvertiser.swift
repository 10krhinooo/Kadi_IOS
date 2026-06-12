import Foundation
import Network

/// Advertises a LAN game via Bonjour (`_kadi._tcp`) and a UDP broadcast beacon fallback on
/// port 4499, per docs/GAME_SPEC.md §J. Owns the `NWListener` that accepts incoming player
/// connections.
public actor LANAdvertiser {
    public static let serviceType = "_kadi._tcp"
    public static let beaconPort: UInt16 = 4499
    public static let beaconInterval: Duration = .seconds(2)

    private let gameName: String
    private let onConnection: @Sendable (NWConnection) -> Void

    private var listener: NWListener?
    private var beaconTask: Task<Void, Never>?

    public init(gameName: String, onConnection: @escaping @Sendable (NWConnection) -> Void) {
        self.gameName = gameName
        self.onConnection = onConnection
    }

    /// Start the TCP listener (advertised via Bonjour) and the UDP beacon broadcaster.
    /// Returns the bound TCP port.
    @discardableResult
    public func start() async throws -> UInt16 {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let listener = try NWListener(using: parameters)

        var txtRecord = NWTXTRecord()
        if let ip = LocalNetwork.ipv4Address() {
            txtRecord["ip"] = ip
        }
        listener.service = NWListener.Service(name: gameName, type: Self.serviceType, txtRecord: txtRecord)

        let onConnection = self.onConnection
        listener.newConnectionHandler = { connection in
            onConnection(connection)
        }

        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            nonisolated(unsafe) var didResume = false
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !didResume, let port = listener.port?.rawValue {
                        didResume = true
                        continuation.resume(returning: port)
                    }
                case .failed(let error):
                    if !didResume {
                        didResume = true
                        continuation.resume(throwing: error)
                    }
                default:
                    break
                }
            }
            listener.start(queue: .main)
        }

        self.listener = listener
        startBeacon(port: port)
        return port
    }

    /// Stop the listener and beacon broadcaster.
    public func stop() {
        listener?.cancel()
        listener = nil
        beaconTask?.cancel()
        beaconTask = nil
    }

    private func startBeacon(port: UInt16) {
        let beacon = KadiBeacon(name: gameName, port: Int(port), ip: LocalNetwork.ipv4Address() ?? "")
        guard let payload = try? JSONEncoder().encode(beacon) else { return }

        beaconTask = Task {
            let connection = NWConnection(
                host: "255.255.255.255",
                port: NWEndpoint.Port(rawValue: Self.beaconPort)!,
                using: .udp
            )
            connection.start(queue: .main)
            defer { connection.cancel() }

            while !Task.isCancelled {
                connection.send(content: payload, completion: .contentProcessed { _ in })
                try? await Task.sleep(for: Self.beaconInterval)
            }
        }
    }
}
