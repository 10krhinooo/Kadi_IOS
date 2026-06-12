import Foundation
import Network

/// Discovers LAN games via Bonjour (`_kadi._tcp`) and the UDP broadcast beacon fallback on
/// port 4499, per docs/GAME_SPEC.md §J.
public actor LANBrowser {
    private var browser: NWBrowser?
    private var udpListener: NWListener?

    public init() {}

    /// A stream of discovered hosts. Ends when `stop()` is called or the stream is cancelled.
    public func discoveredHosts() -> AsyncStream<DiscoveredHost> {
        AsyncStream { continuation in
            Task { await self.start(continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.stop() }
            }
        }
    }

    /// Stop browsing/listening.
    public func stop() {
        browser?.cancel()
        browser = nil
        udpListener?.cancel()
        udpListener = nil
    }

    private func start(continuation: AsyncStream<DiscoveredHost>.Continuation) {
        startBonjourBrowse(continuation: continuation)
        startBeaconListener(continuation: continuation)
    }

    private func startBonjourBrowse(continuation: AsyncStream<DiscoveredHost>.Continuation) {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: LANAdvertiser.serviceType, domain: nil), using: parameters)
        browser.browseResultsChangedHandler = { results, _ in
            for result in results {
                guard case let .service(name, _, _, _) = result.endpoint else { continue }
                var ip: String?
                if case let .bonjour(record) = result.metadata,
                   case let .string(value) = record.getEntry(for: "ip") {
                    ip = value
                }
                continuation.yield(DiscoveredHost(name: name, endpoint: result.endpoint, ip: ip))
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    private func startBeaconListener(continuation: AsyncStream<DiscoveredHost>.Continuation) {
        guard let port = NWEndpoint.Port(rawValue: LANAdvertiser.beaconPort),
              let listener = try? NWListener(using: .udp, on: port) else {
            return
        }
        listener.newConnectionHandler = { connection in
            connection.start(queue: .main)
            Self.receiveBeacon(on: connection, continuation: continuation)
        }
        listener.start(queue: .main)
        self.udpListener = listener
    }

    private static func receiveBeacon(on connection: NWConnection, continuation: AsyncStream<DiscoveredHost>.Continuation) {
        connection.receiveMessage { data, _, _, error in
            if let data,
               let beacon = try? JSONDecoder().decode(KadiBeacon.self, from: data),
               beacon.type == "kadi_beacon",
               let port = NWEndpoint.Port(rawValue: UInt16(beacon.port)) {
                let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(beacon.ip), port: port)
                continuation.yield(DiscoveredHost(name: beacon.name, endpoint: endpoint, ip: beacon.ip, port: port.rawValue))
            }

            if error == nil {
                receiveBeacon(on: connection, continuation: continuation)
            } else {
                connection.cancel()
            }
        }
    }
}
