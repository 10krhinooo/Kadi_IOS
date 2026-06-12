import XCTest
@testable import KadiOnline

final class FirebaseBootstrapTests: XCTestCase {
    func testEmulatorAvailabilityFlagReadsEnvironment() {
        // Pure check of the environment-variable convention; doesn't configure Firebase.
        let hasHost = ProcessInfo.processInfo.environment["FIRESTORE_EMULATOR_HOST"] != nil
        XCTAssertEqual(FirebaseBootstrap.isEmulatorAvailable, hasHost)
    }
}
