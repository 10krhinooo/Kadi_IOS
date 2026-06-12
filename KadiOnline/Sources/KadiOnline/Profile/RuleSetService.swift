@preconcurrency import FirebaseFirestore
import Foundation
import KadiEngine

/// `/users/{uid}/ruleSets/{id}` documents, per docs/GAME_SPEC.md §L.
public struct RuleSetService: Sendable {
    private let db: Firestore

    public init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func ruleSetsRef(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("ruleSets")
    }

    /// Saves a new `/users/{uid}/ruleSets/{id}` doc and returns its generated ID.
    @discardableResult
    public func saveRuleSet(uid: String, name: String, rules: RuleSet) async throws -> String {
        let data: [String: Any] = [
            "name": name,
            "rules": try Firestore.Encoder().encode(rules),
            "createdAt": FieldValue.serverTimestamp(),
        ]
        let ref = try await ruleSetsRef(uid).addDocument(data: data)
        return ref.documentID
    }

    /// Streams `/users/{uid}/ruleSets`.
    public func observeRuleSets(uid: String) -> AsyncThrowingStream<[SavedRuleSet], Error> {
        AsyncThrowingStream { continuation in
            let listener = ruleSetsRef(uid)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else { return }
                    do {
                        let ruleSets = try snapshot.documents.map { document -> SavedRuleSet in
                            var ruleSet = try document.data(as: SavedRuleSet.self)
                            ruleSet.id = document.documentID
                            return ruleSet
                        }
                        continuation.yield(ruleSets)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// Deletes `/users/{uid}/ruleSets/{id}`.
    public func deleteRuleSet(uid: String, id: String) async throws {
        try await ruleSetsRef(uid).document(id).delete()
    }
}
