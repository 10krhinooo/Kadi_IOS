import XCTest
@preconcurrency import FirebaseFirestore
import KadiEngine
@testable import KadiOnline

final class RuleSetServiceTests: EmulatorTestCase {
    func testSaveRuleSetWritesExpectedFields() async throws {
        let service = RuleSetService()
        let rules = RuleSet(deckCount: 2, cardsPerPlayer: 5)
        let id = try await service.saveRuleSet(uid: "uid-a", name: "My Rules", rules: rules)

        let doc = try await Firestore.firestore().collection("users").document("uid-a").collection("ruleSets").document(id).getDocument()
        let data = try XCTUnwrap(doc.data())
        XCTAssertEqual(data["name"] as? String, "My Rules")
        XCTAssertNotNil(data["createdAt"])

        let rulesData = try XCTUnwrap(data["rules"] as? [String: Any])
        XCTAssertEqual(rulesData["deckCount"] as? Int, 2)
        XCTAssertEqual(rulesData["cardsPerPlayer"] as? Int, 5)
    }

    func testObserveRuleSetsReturnsSavedRuleSet() async throws {
        let service = RuleSetService()
        let rules = RuleSet(deckCount: 2, cardsPerPlayer: 5)
        _ = try await service.saveRuleSet(uid: "uid-a", name: "My Rules", rules: rules)

        let stream = service.observeRuleSets(uid: "uid-a")
        for try await ruleSets in stream {
            if let first = ruleSets.first {
                XCTAssertEqual(first.name, "My Rules")
                XCTAssertEqual(first.rules, rules)
                XCTAssertNotNil(first.id)
                break
            }
        }
    }

    func testDeleteRuleSetRemovesDoc() async throws {
        let service = RuleSetService()
        let id = try await service.saveRuleSet(uid: "uid-a", name: "My Rules", rules: RuleSet())

        try await service.deleteRuleSet(uid: "uid-a", id: id)

        let doc = try await Firestore.firestore().collection("users").document("uid-a").collection("ruleSets").document(id).getDocument()
        XCTAssertFalse(doc.exists)
    }
}
