import XCTest
@preconcurrency import FirebaseFirestore
@testable import KadiOnline

final class ReportServiceTests: EmulatorTestCase {
    func testFileReportWritesExpectedFields() async throws {
        let service = ReportService()
        let reportId = try await service.fileReport(reporterUid: "uid-a", targetUid: "uid-b", reason: "cheating")

        let doc = try await Firestore.firestore().collection("reports").document(reportId).getDocument()
        let data = try XCTUnwrap(doc.data())
        XCTAssertEqual(data["reporterUid"] as? String, "uid-a")
        XCTAssertEqual(data["targetUid"] as? String, "uid-b")
        XCTAssertEqual(data["reason"] as? String, "cheating")
        XCTAssertNotNil(data["createdAt"])
    }
}
