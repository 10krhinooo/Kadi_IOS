//
//  kadiApp.swift
//  kadi
//
//  Created by Collins Wachira on 10/06/2026.
//

import SwiftUI
// import KadiOnline // TODO: re-enable once kadi/GoogleService-Info.plist is added

@main
struct kadiApp: App {
    init() {
        // FirebaseBootstrap.configure() // TODO: re-enable once kadi/GoogleService-Info.plist is added
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
