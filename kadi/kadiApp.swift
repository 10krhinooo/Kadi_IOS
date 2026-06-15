//
//  kadiApp.swift
//  kadi
//
//  Created by Collins Wachira on 10/06/2026.
//

import SwiftUI
import KadiOnline
import GoogleSignIn

@main
struct kadiApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase
    private let presenceCoordinator: PresenceCoordinator

    init() {
        FirebaseBootstrap.configure()
        presenceCoordinator = PresenceCoordinator()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(authViewModel)
                .task {
                    authViewModel.start()
                }
                .onChange(of: authViewModel.authState) { _, newState in
                    Task { await presenceCoordinator.handle(authState: newState) }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    Task { await presenceCoordinator.handleScenePhase(newPhase) }
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
