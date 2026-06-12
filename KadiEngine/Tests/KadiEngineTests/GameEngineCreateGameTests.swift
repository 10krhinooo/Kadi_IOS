import XCTest
@testable import KadiEngine

final class GameEngineCreateGameTests: XCTestCase {
    func testCreateGameDealsHandsAndSetsDefaults() throws {
        var rng = SeededRNG(seed: 100)
        let players = [makePlayer("a", hand: []), makePlayer("b", hand: []), makePlayer("c", hand: [])]
        let rules = RuleSet()
        let state = try GameEngine.createGame(players: players, rules: rules, using: &rng)

        for player in state.players {
            XCTAssertEqual(player.hand.count, rules.cardsPerPlayer)
        }
        XCTAssertEqual(state.currentPlayerIndex, 0)
        XCTAssertEqual(state.direction, .clockwise)
        XCTAssertEqual(state.phase, .playing)
        XCTAssertEqual(state.discardPile.count, 1)
        XCTAssertEqual(state.pendingDrawCount, 0)

        let totalCards = state.players.reduce(0) { $0 + $1.hand.count } + state.drawPile.count + state.discardPile.count
        XCTAssertEqual(totalCards, 54)
    }
}
