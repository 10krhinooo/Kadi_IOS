@preconcurrency import FirebaseFirestore
import Foundation

/// `/reports/{id}` documents, per docs/GAME_SPEC.md §L.
public struct ReportService: Sendable {
    private let db: Firestore

    public init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    /// Creates a `/reports/{id}` doc. Write-only from the client — review is a Phase 5
    /// (admin app) concern with separate credentials.
    @discardableResult
    public func fileReport(reporterUid: String, targetUid: String, reason: String) async throws -> String {
        let data: [String: Any] = [
            "reporterUid": reporterUid,
            "targetUid": targetUid,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        let ref = try await db.collection("reports").addDocument(data: data)
        return ref.documentID
    }
}
