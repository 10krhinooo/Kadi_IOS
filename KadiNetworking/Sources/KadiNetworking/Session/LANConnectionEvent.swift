import KadiEngine

/// CPU-takeover / reconnect events for a player seat, exposed uniformly by both
/// `LANGameHost.connectionEvents()` and `LANGameClient.connectionEvents()`, so
/// app-level view models can show "Player X — CPU controlling" / reconnect banners
/// regardless of whether this device is the host or a guest.
public enum LANConnectionEvent: Equatable, Sendable {
    case playerDisconnected(playerIndex: Int)
    case playerReconnected(playerIndex: Int)
}
