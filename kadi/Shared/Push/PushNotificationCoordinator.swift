//
//  PushNotificationCoordinator.swift
//  kadi
//

import Foundation
import KadiOnline

/// Wires FCM registration tokens (`PushTokenStore`) to the app-wide `AuthViewModel`
/// session: registers the current device token on `/users/{uid}.fcmTokens` once both
/// a signed-in user and a token are available, and unregisters it on sign-out. Owned
/// by `kadiApp`, mirroring `PresenceCoordinator`.
@MainActor
final class PushNotificationCoordinator {
    private let profileService: ProfileService
    private var currentUid: String?
    private var registeredToken: String?

    init(profileService: ProfileService = ProfileService()) {
        self.profileService = profileService
    }

    func handle(authState: AuthViewModel.AuthState, token: String?) async {
        switch authState {
        case .signedIn(let user):
            currentUid = user.uid
            guard let token, token != registeredToken else { return }
            try? await profileService.registerFCMToken(uid: user.uid, token: token)
            registeredToken = token
        case .loading, .signedOut, .needsVerification:
            guard let uid = currentUid, let token = registeredToken else {
                currentUid = nil
                registeredToken = nil
                return
            }
            currentUid = nil
            registeredToken = nil
            try? await profileService.unregisterFCMToken(uid: uid, token: token)
        }
    }
}
