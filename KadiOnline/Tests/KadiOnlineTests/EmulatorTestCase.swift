import XCTest
@preconcurrency import FirebaseFirestore
@testable import KadiOnline

/// Base class for tests that talk to the Firestore Local Emulator.
///
/// Run via `firebase emulators:exec --only firestore,auth,database 'swift test --package-path
/// KadiOnline'` from the repo root, which sets `FIRESTORE_EMULATOR_HOST`. If that env var
/// isn't set (emulator not running), tests `XCTSkip` instead of failing.
///
/// These tests run against `firestore.test.rules` (allow-all), not the production
/// `firestore.rules`, because `FirebaseAuth`'s keychain-backed persistence doesn't work in
/// `swift test` on macOS (`SecItemAdd -34018`, missing keychain-sharing entitlement for
/// command-line test binaries) — so emulator tests can't sign in via `FirebaseAuth` and
/// exercise auth-gated rules. `AuthServiceTests` covers Email/Password flows separately
/// where possible; full auth-gated-rules coverage requires `xcodebuild test` on an iOS
/// simulator (out of scope for this package's `swift test`-based suite).
class EmulatorTestCase: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(FirebaseBootstrap.isEmulatorAvailable, "Firebase emulator not running — run via `firebase emulators:exec --only firestore,auth 'swift test --package-path KadiOnline'`")
        FirebaseBootstrap.configureForTesting()
    }

    override func tearDown() async throws {
        try await clearFirestoreData()
        try await clearRealtimeDatabaseData()
        try await super.tearDown()
    }

    /// Wipes all Firestore documents in the `demo-kadi` emulator project between tests.
    private func clearFirestoreData() async throws {
        let url = URL(string: "http://localhost:8089/emulator/v1/projects/demo-kadi/databases/(default)/documents")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await URLSession.shared.data(for: request)
    }

    /// Wipes all data in the `demo-kadi-default-rtdb` Realtime Database emulator namespace between tests.
    private func clearRealtimeDatabaseData() async throws {
        let url = URL(string: "http://localhost:9000/.json?ns=demo-kadi-default-rtdb")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await URLSession.shared.data(for: request)
    }
}
