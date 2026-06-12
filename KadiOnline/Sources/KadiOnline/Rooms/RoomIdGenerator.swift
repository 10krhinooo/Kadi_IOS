import Foundation

/// Generates 6-character room codes per docs/GAME_SPEC.md §L: A-Z/2-9, excluding the
/// visually-ambiguous characters 0, 1, I, O. The resulting 32-character alphabet is a power
/// of two, so `Int.random(in: 0..<32)` (or any `RandomNumberGenerator`) samples it without
/// modulo bias.
public enum RoomIdGenerator {
    public static let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    public static let length = 6

    /// Generates a random 6-character room code using `generator`.
    public static func generate(using generator: inout some RandomNumberGenerator) -> String {
        let characters = Array(alphabet)
        var code = ""
        code.reserveCapacity(length)
        for _ in 0..<length {
            code.append(characters[Int.random(in: 0..<characters.count, using: &generator)])
        }
        return code
    }

    /// Generates a random 6-character room code using the system RNG.
    public static func generate() -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(using: &rng)
    }
}
