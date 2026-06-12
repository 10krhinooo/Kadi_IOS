import XCTest
@testable import KadiOnline

final class RoomIdGeneratorTests: XCTestCase {
    func testAlphabetExcludesAmbiguousCharacters() {
        for forbidden in ["0", "1", "I", "O"] {
            XCTAssertFalse(RoomIdGenerator.alphabet.contains(forbidden))
        }
    }

    func testAlphabetIsThirtyTwoCharacters() {
        XCTAssertEqual(RoomIdGenerator.alphabet.count, 32)
        XCTAssertEqual(Set(RoomIdGenerator.alphabet).count, 32, "alphabet should have no duplicates")
    }

    func testGeneratesSixCharacterCodeFromAlphabet() {
        var rng = SeededGenerator(seed: 42)
        let code = RoomIdGenerator.generate(using: &rng)
        XCTAssertEqual(code.count, RoomIdGenerator.length)
        for character in code {
            XCTAssertTrue(RoomIdGenerator.alphabet.contains(character))
        }
    }

    func testIsDeterministicWithSeededGenerator() {
        var rng1 = SeededGenerator(seed: 7)
        var rng2 = SeededGenerator(seed: 7)
        XCTAssertEqual(RoomIdGenerator.generate(using: &rng1), RoomIdGenerator.generate(using: &rng2))
    }
}

/// Simple deterministic RNG for tests (xorshift64*).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xdeadbeef : seed
    }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
}
