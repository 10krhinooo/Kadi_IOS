import Foundation

/// Encodes/decodes `NetworkMessage`s as newline-delimited JSON (NDJSON), per
/// docs/GAME_SPEC.md §J: one `\n`-terminated JSON object per line.
public enum NDJSONFramer {
    static let newline: UInt8 = 0x0A // "\n"

    /// Encode a single message as a `\n`-terminated JSON line.
    public static func encode(_ message: NetworkMessage) throws -> Data {
        var data = try JSONEncoder().encode(message)
        data.append(newline)
        return data
    }
}

/// Incrementally reassembles `NetworkMessage`s from arbitrary `Data` chunks delivered by a
/// stream transport (e.g. `NWConnection.receive`), splitting on `\n` and tolerating partial
/// lines split across chunks or multiple lines within a single chunk.
public struct NDJSONLineBuffer {
    private var buffer = Data()
    private let decoder = JSONDecoder()

    public init() {}

    /// Feed a chunk of received bytes, returning all complete `NetworkMessage`s decoded from
    /// any newly-completed lines (in order). Incomplete trailing data is retained for the
    /// next call.
    public mutating func feed(_ data: Data) throws -> [NetworkMessage] {
        buffer.append(data)

        var messages: [NetworkMessage] = []
        while let newlineIndex = buffer.firstIndex(of: NDJSONFramer.newline) {
            let lineData = buffer[buffer.startIndex..<newlineIndex]
            buffer.removeSubrange(buffer.startIndex...newlineIndex)

            guard !lineData.isEmpty else { continue }
            let message = try decoder.decode(NetworkMessage.self, from: lineData)
            messages.append(message)
        }
        return messages
    }
}
