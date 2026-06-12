import FirebaseCore
import FirebaseFirestore
import FirebaseDatabase
import FirebaseAuth
import Foundation

/// Configures Firebase for the running process. Call once at app startup.
public enum FirebaseBootstrap {
    private static var configured = false

    /// Configures Firebase against the real `kadi-254` project using
    /// `GoogleService-Info.plist` bundled with the app target. RTDB presence/quickChat
    /// (Phase 3c) requires the Realtime Database to be enabled for `kadi-254` in the
    /// Firebase console so `DATABASE_URL` is present in the plist.
    public static func configure() {
        guard !configured else { return }
        FirebaseApp.configure()
        configured = true
    }

    /// Configures Firebase against the Firebase Local Emulator Suite using a
    /// `demo-kadi` placeholder project ID, which requires no real credentials.
    /// Intended for `swift test` runs started via
    /// `firebase emulators:exec --only firestore,auth,database 'swift test'`.
    public static func configureForTesting(
        firestoreHost: String = "localhost",
        firestorePort: Int = 8089,
        authHost: String = "localhost",
        authPort: Int = 9199,
        databaseHost: String = "localhost",
        databasePort: Int = 9000
    ) {
        guard !configured else { return }
        let options = FirebaseOptions(
            googleAppID: "1:000000000000:ios:0000000000000000000000",
            gcmSenderID: "000000000000"
        )
        options.projectID = "demo-kadi"
        options.apiKey = "fake-api-key"
        // Required for `Database.database()` to resolve a namespace; overridden by
        // `useEmulator` below.
        options.databaseURL = "https://demo-kadi-default-rtdb.firebaseio.com"
        FirebaseApp.configure(options: options)

        let settings = Firestore.firestore().settings
        settings.host = "\(firestoreHost):\(firestorePort)"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings

        Auth.auth().useEmulator(withHost: authHost, port: authPort)

        Database.database().useEmulator(withHost: databaseHost, port: databasePort)

        configured = true
    }

    /// Whether the Firebase Local Emulator Suite is expected to be running,
    /// based on the `FIRESTORE_EMULATOR_HOST` environment variable conventionally
    /// set by `firebase emulators:exec`.
    public static var isEmulatorAvailable: Bool {
        ProcessInfo.processInfo.environment["FIRESTORE_EMULATOR_HOST"] != nil
    }
}
