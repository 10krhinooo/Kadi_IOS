//
//  PresenceCoordinator.swift
//  kadi
//

import Foundation
import KadiOnline
import SwiftUI

/// Wires `PresenceService` (`/presence/{uid}` in RTDB) to the app-wide `AuthViewModel`
/// session and `ScenePhase`: marks the signed-in user online when signed in / in the
/// foreground, and offline when signed out or backgrounded. Owned by `kadiApp`.
@MainActor
final class PresenceCoordinator {
    private let presenceService: PresenceService
    private(set) var currentUid: String?

    init(presenceService: PresenceService = PresenceService()) {
        self.presenceService = presenceService
    }

    func handle(authState: AuthViewModel.AuthState) async {
        switch authState {
        case .signedIn(let user):
            guard currentUid != user.uid else { return }
            currentUid = user.uid
            try? await presenceService.goOnline(uid: user.uid)
        case .loading, .signedOut, .needsVerification:
            guard let uid = currentUid else { return }
            currentUid = nil
            try? await presenceService.goOffline(uid: uid)
        }
    }

    func handleScenePhase(_ phase: ScenePhase) async {
        guard let uid = currentUid else { return }
        switch phase {
        case .active:
            try? await presenceService.goOnline(uid: uid)
        case .background:
            try? await presenceService.goOffline(uid: uid)
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
