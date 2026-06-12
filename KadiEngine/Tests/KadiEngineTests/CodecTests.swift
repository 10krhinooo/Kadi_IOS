import XCTest
@testable import KadiEngine

final class CodecTests: XCTestCase {
    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    let decoder = JSONDecoder()

    private func encodeToObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try encoder.encode(value)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    // MARK: - Card

    func testCardEncoding() throws {
        let c = card(.ace, .spades)
        let obj = try encodeToObject(c)
        XCTAssertEqual(obj["rank"] as? String, "ace")
        XCTAssertEqual(obj["suit"] as? String, "spades")
    }

    func testCardWithNilSuitEncoding() throws {
        let c = card(.joker, nil)
        let data = try encoder.encode(c)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"rank\":\"joker\""))
        XCTAssertTrue(json.contains("\"suit\":null"))
    }

    func testCardDecoding() throws {
        let json = """
        {"rank":"king","suit":"hearts"}
        """.data(using: .utf8)!
        let c = try decoder.decode(PlayingCard.self, from: json)
        XCTAssertEqual(c, card(.king, .hearts))
    }

    func testCardRoundTrip() throws {
        let c = card(.ten, .diamonds)
        let data = try encoder.encode(c)
        let decoded = try decoder.decode(PlayingCard.self, from: data)
        XCTAssertEqual(c, decoded)
    }

    // MARK: - Player

    func testPlayerEncoding() throws {
        let p = makePlayer("p1", hand: [card(.two, .hearts)])
        let obj = try encodeToObject(p)
        XCTAssertEqual(obj["id"] as? String, "p1")
        XCTAssertEqual(obj["name"] as? String, "p1")
        XCTAssertEqual(obj["isHuman"] as? Bool, false)
        XCTAssertEqual(obj["avatarIndex"] as? Int, 0)
        XCTAssertEqual((obj["hand"] as? [[String: Any]])?.count, 1)
    }

    func testPlayerDecodingWithoutAvatarIndexDefaultsToZero() throws {
        let json = """
        {"id":"p1","name":"P1","hand":[],"isHuman":true}
        """.data(using: .utf8)!
        let p = try decoder.decode(Player.self, from: json)
        XCTAssertEqual(p.avatarIndex, 0)
        XCTAssertTrue(p.isHuman)
    }

    // MARK: - RuleSet

    func testRuleSetDefaultEncoding() throws {
        let rules = RuleSet()
        let obj = try encodeToObject(rules)
        XCTAssertEqual(obj["aceOfSpadesEnabled"] as? Bool, true)
        XCTAssertEqual(obj["jokersIncluded"] as? Bool, true)
        XCTAssertEqual(obj["deckCount"] as? Int, 1)
        XCTAssertEqual(obj["cardsPerPlayer"] as? Int, 4)
        XCTAssertEqual(obj["startingCardReshuffle"] as? Bool, false)
        XCTAssertEqual(obj["drawStackCap"] as? Int, 0)
        XCTAssertEqual(obj["kadiPenalty"] as? Int, 0)
        XCTAssertEqual(obj["passAllowed"] as? Bool, true)
        XCTAssertEqual(obj["kingStackable"] as? Bool, true)
        XCTAssertEqual(obj["jackStackable"] as? Bool, true)
        XCTAssertEqual(obj["lateKadiDeclaration"] as? Bool, false)
        XCTAssertEqual(obj["turnTimerSeconds"] as? Int, 0)
        XCTAssertEqual(obj["jumpInterceptAllowed"] as? Bool, false)
        XCTAssertEqual(obj["twosEnabled"] as? Bool, true)
        XCTAssertEqual(obj["threesEnabled"] as? Bool, true)
        XCTAssertEqual(obj["drawJumpAllowed"] as? Bool, false)
        XCTAssertEqual(obj["jokerJumpAllowed"] as? Bool, false)
        XCTAssertEqual(obj["showOpponentCardCounts"] as? Bool, false)
        XCTAssertEqual(obj["hintLevel"] as? String, "none")
    }

    func testRuleSetRoundTrip() throws {
        var rules = RuleSet()
        rules.deckCount = 2
        rules.hintLevel = .advanced
        let data = try encoder.encode(rules)
        let decoded = try decoder.decode(RuleSet.self, from: data)
        XCTAssertEqual(rules, decoded)
    }

    // MARK: - GameAction

    func testPlayCardsActionEncoding() throws {
        let action = GameAction.playCards(cards: [card(.five, .hearts)])
        let obj = try encodeToObject(action)
        XCTAssertEqual(obj["type"] as? String, "PlayCards")
        XCTAssertEqual((obj["cards"] as? [[String: Any]])?.count, 1)
    }

    func testChooseSuitActionEncoding() throws {
        let action = GameAction.chooseSuit(suit: .hearts)
        let obj = try encodeToObject(action)
        XCTAssertEqual(obj["type"] as? String, "ChooseSuit")
        XCTAssertEqual(obj["suit"] as? String, "hearts")
    }

    func testMakeDemandActionEncoding() throws {
        let action = GameAction.makeDemand(rank: .king, suit: .hearts)
        let obj = try encodeToObject(action)
        XCTAssertEqual(obj["type"] as? String, "MakeDemand")
        XCTAssertEqual(obj["rank"] as? String, "king")
        XCTAssertEqual(obj["suit"] as? String, "hearts")
    }

    func testRespondToDemandNilCardEncoding() throws {
        let action = GameAction.respondToDemand(card: nil)
        let data = try encoder.encode(action)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"type\":\"RespondToDemand\""))
        XCTAssertFalse(json.contains("\"card\""))
    }

    func testDeclineInterceptEncoding() throws {
        let action = GameAction.declineIntercept
        let obj = try encodeToObject(action)
        XCTAssertEqual(obj["type"] as? String, "DeclineIntercept")
    }

    func testGameActionDecoding() throws {
        let json = """
        {"type":"RefuseDraw","ace":{"rank":"ace","suit":"clubs"}}
        """.data(using: .utf8)!
        let action = try decoder.decode(GameAction.self, from: json)
        XCTAssertEqual(action, .refuseDraw(ace: card(.ace, .clubs)))
    }

    func testAllActionTypesRoundTrip() throws {
        let actions: [GameAction] = [
            .playCards(cards: [card(.five, .hearts)]),
            .pass,
            .drawStack,
            .declareKadi(cards: []),
            .declareKadi(cards: [card(.seven, .hearts)]),
            .chooseSuit(suit: .diamonds),
            .makeDemand(rank: .six, suit: .clubs),
            .respondToDemand(card: card(.six, .clubs)),
            .respondToDemand(card: nil),
            .refuseDraw(ace: card(.ace, .hearts)),
            .refuseSkip(jack: card(.jack, .spades)),
            .refuseReverse(king: card(.king, .diamonds)),
            .interceptSkip(jacks: [card(.jack, .hearts), card(.jack, .clubs)]),
            .declineIntercept,
            .jumpDraw(jack: card(.jack, .diamonds)),
        ]
        for action in actions {
            let data = try encoder.encode(action)
            let decoded = try decoder.decode(GameAction.self, from: data)
            XCTAssertEqual(action, decoded)
        }
    }

    // MARK: - GameState

    func testGameStateEncodingIncludesDrawPileCount() throws {
        let state = makeState(
            players: [makePlayer("a", hand: []), makePlayer("b", hand: [])],
            drawPile: [card(.two, .hearts), card(.three, .hearts)],
            discardPile: [card(.five, .clubs)]
        )
        let obj = try encodeToObject(state)
        XCTAssertEqual(obj["drawPileCount"] as? Int, 2)
        XCTAssertEqual((obj["drawPile"] as? [[String: Any]])?.count, 2)
        XCTAssertEqual(obj["direction"] as? String, "clockwise")
        XCTAssertEqual(obj["phase"] as? String, "playing")
        XCTAssertEqual(obj["currentPlayerIndex"] as? Int, 0)
        XCTAssertEqual(obj["pendingDrawCount"] as? Int, 0)
        XCTAssertEqual((obj["winningCards"] as? [[String: Any]])?.count, 0)
        XCTAssertEqual((obj["skipInterceptQueue"] as? [Int])?.count, 0)
        XCTAssertEqual(obj["pendingSkipCount"] as? Int, 0)
        XCTAssertEqual((obj["skipInterceptedBy"] as? [Int])?.count, 0)
        XCTAssertNil(obj["forcedSuit"])
        XCTAssertNil(obj["demandedCard"])
        XCTAssertNil(obj["kadiState"])
    }

    func testGameStateRoundTrip() throws {
        let state = makeState(
            players: [
                makePlayer("a", hand: [card(.two, .hearts), card(.king, .spades)]),
                makePlayer("b", hand: [card(.queen, .clubs)]),
            ],
            drawPile: [card(.three, .diamonds)],
            discardPile: [card(.five, .hearts)],
            currentPlayerIndex: 1,
            direction: .anticlockwise,
            pendingDrawCount: 2,
            forcedSuit: .hearts,
            demandedCard: card(.ace, .spades),
            kadiState: KadiState(declaringPlayerIndex: 0),
            phase: .cardDemand,
            preSuitChoicePhase: .playing,
            skipInterceptQueue: [1, 2],
            pendingSkipCount: 1,
            skipOriginIndex: 0,
            skipInterceptedBy: [1, 3]
        )

        let data = try encoder.encode(state)
        let decoded = try decoder.decode(GameState.self, from: data)

        // Engine-local grace fields are not part of the wire format and are nil after decode.
        XCTAssertNil(decoded.kadiGracePeriodPlayerIndex)
        XCTAssertNil(decoded.skipInterceptGracePeriodPlayerIndex)
        XCTAssertEqual(decoded.players, state.players)
        XCTAssertEqual(decoded.drawPile, state.drawPile)
        XCTAssertEqual(decoded.discardPile, state.discardPile)
        XCTAssertEqual(decoded.currentPlayerIndex, state.currentPlayerIndex)
        XCTAssertEqual(decoded.direction, state.direction)
        XCTAssertEqual(decoded.pendingDrawCount, state.pendingDrawCount)
        XCTAssertEqual(decoded.forcedSuit, state.forcedSuit)
        XCTAssertEqual(decoded.demandedCard, state.demandedCard)
        XCTAssertEqual(decoded.kadiState, state.kadiState)
        XCTAssertEqual(decoded.phase, state.phase)
        XCTAssertEqual(decoded.preSuitChoicePhase, state.preSuitChoicePhase)
        XCTAssertEqual(decoded.skipInterceptQueue, state.skipInterceptQueue)
        XCTAssertEqual(decoded.pendingSkipCount, state.pendingSkipCount)
        XCTAssertEqual(decoded.skipOriginIndex, state.skipOriginIndex)
        XCTAssertEqual(decoded.skipInterceptedBy, state.skipInterceptedBy)
    }

    func testGameStateDecodingFromLiteralWireFormat() throws {
        let json = """
        {
          "players": [
            {"id":"p1","name":"Alice","hand":[{"rank":"two","suit":"hearts"}],"isHuman":true,"avatarIndex":0},
            {"id":"p2","name":"Bob","hand":[],"isHuman":false,"avatarIndex":1}
          ],
          "drawPileCount": 1,
          "drawPile": [{"rank":"three","suit":"clubs"}],
          "discardPile": [{"rank":"five","suit":"diamonds"}],
          "currentPlayerIndex": 0,
          "direction": "clockwise",
          "pendingDrawCount": 0,
          "forcedSuit": null,
          "demandedCard": null,
          "kadiState": null,
          "rules": {
            "aceOfSpadesEnabled": true, "jokersIncluded": true, "deckCount": 1, "cardsPerPlayer": 4,
            "startingCardReshuffle": false, "drawStackCap": 0, "kadiPenalty": 0, "passAllowed": true,
            "kingStackable": true, "jackStackable": true, "lateKadiDeclaration": false, "turnTimerSeconds": 0,
            "jumpInterceptAllowed": false, "twosEnabled": true, "threesEnabled": true, "drawJumpAllowed": false,
            "jokerJumpAllowed": false, "showOpponentCardCounts": false, "hintLevel": "none"
          },
          "phase": "playing",
          "preSuitChoicePhase": null,
          "pendingSkipTarget": null,
          "winningCards": [],
          "skipInterceptQueue": [],
          "pendingSkipCount": 0,
          "skipOriginIndex": null,
          "skipInterceptedBy": []
        }
        """.data(using: .utf8)!

        let state = try decoder.decode(GameState.self, from: json)
        XCTAssertEqual(state.players.count, 2)
        XCTAssertEqual(state.players[0].id, "p1")
        XCTAssertEqual(state.drawPile, [card(.three, .clubs)])
        XCTAssertEqual(state.discardPile, [card(.five, .diamonds)])
        XCTAssertEqual(state.phase, .playing)
        XCTAssertEqual(state.direction, .clockwise)
    }
}
