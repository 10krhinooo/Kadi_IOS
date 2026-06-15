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
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var pushTokenStore = PushTokenStore.shared
    @Environment(\.scenePhase) private var scenePhase
    private let presenceCoordinator: PresenceCoordinator
    private let pushCoordinator: PushNotificationCoordinator

    init() {
        FirebaseBootstrap.configure()
        presenceCoordinator = PresenceCoordinator()
        pushCoordinator = PushNotificationCoordinator()
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
                    Task { await pushCoordinator.handle(authState: newState, token: pushTokenStore.fcmToken) }
                }
                .onChange(of: pushTokenStore.fcmToken) { _, newToken in
                    Task { await pushCoordinator.handle(authState: authViewModel.authState, token: newToken) }
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
