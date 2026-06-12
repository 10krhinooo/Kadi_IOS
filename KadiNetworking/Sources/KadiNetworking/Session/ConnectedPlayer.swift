import Foundation
import KadiEngine

/// Host-side bookkeeping for one seat in a LAN game.
struct ConnectedPlayer {
    var playerIndex: Int
    var uid: String
    var name: String
    var avatarIndex: Int
    var connection: (any MessageConnection)?
    var isCPUControlled: Bool
    var cpuAgent: CpuAgent?

    init(
        playerIndex: Int,
        uid: String,
        name: String,
        avatarIndex: Int,
        connection: (any MessageConnection)? = nil,
        isCPUControlled: Bool = false,
        cpuAgent: CpuAgent? = nil
    ) {
        self.playerIndex = playerIndex
        self.uid = uid
        self.name = name
        self.avatarIndex = avatarIndex
        self.connection = connection
        self.isCPUControlled = isCPUControlled
        self.cpuAgent = cpuAgent
    }
}
