//
//  SocialRootView.swift
//  kadi
//

import SwiftUI

/// Entry point for "Profile": gates `SocialHubView` behind the same shared
/// email/password auth flow (`AuthView` -> `VerifyEmailView`) used by
/// `Features/Online/`'s `OnlineRootView`, via the app-wide `AuthViewModel`.
struct SocialRootView: View {
    @EnvironmentObject private var viewModel: AuthViewModel

    var body: some View {
        switch viewModel.authState {
        case .loading:
            ZStack {
                KadiTheme.backgroundGradient.ignoresSafeArea()
                ProgressView()
                    .tint(KadiTheme.Colors.accent)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        case .signedOut:
            AuthView(viewModel: viewModel)
        case .needsVerification(let user):
            VerifyEmailView(viewModel: viewModel, user: user)
        case .signedIn(let user):
            SocialHubView(authUser: user)
        }
    }
}
