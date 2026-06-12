import Foundation
import Network

/// A LAN game host discovered via Bonjour (`_kadi._tcp`) or the UDP broadcast beacon
/// fallback on port 4499 (docs/GAME_SPEC.md §J).
public struct DiscoveredHost: Equatable, Sendable {
    /// Human-readable game/host name.
    public var name: String
    /// Endpoint to connect to. For Bonjour results this is a `.service` endpoint that
    /// `NWConnection` resolves automatically; for UDP-beacon results this is a
    /// `.hostPort` endpoint built from the beacon's `ip`/`port`.
    public var endpoint: NWEndpoint
    /// Host's LAN IPv4 address, if known (from the Bonjour TXT record or beacon payload).
    public var ip: String?
    /// TCP port, if known (always known for beacon results).
    public var port: UInt16?

    public init(name: String, endpoint: NWEndpoint, ip: String? = nil, port: UInt16? = nil) {
        self.name = name
        self.endpoint = endpoint
        self.ip = ip
        self.port = port
    }
}

/// Wire payload for the UDP broadcast beacon fallback: raw JSON (not NDJSON-wrapped),
/// `{"type":"kadi_beacon","name","port","ip"}`, sent every 2s to `255.255.255.255:4499`.
struct KadiBeacon: Codable, Equatable {
    var type: String
    var name: String
    var port: Int
    var ip: String

    init(name: String, port: Int, ip: String) {
        self.type = "kadi_beacon"
        self.name = name
        self.port = port
        self.ip = ip
    }
}
