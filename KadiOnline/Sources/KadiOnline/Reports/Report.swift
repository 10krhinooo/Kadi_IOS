import Foundation

/// `/reports/{id}` document, per docs/GAME_SPEC.md §L.
///
/// Write-only from the client — there is no `observe`/`fetch` for reports; review is a
/// Phase 5 (admin app) concern with separate credentials.
public struct Report: Codable, Equatable, Sendable {
    public var reporterUid: String
    public var targetUid: String
    public var reason: String
    public var createdAt: Date?

    public init(reporterUid: String, targetUid: String, reason: String, createdAt: Date? = nil) {
        self.reporterUid = reporterUid
        self.targetUid = targetUid
        self.reason = reason
        self.createdAt = createdAt
    }
}
