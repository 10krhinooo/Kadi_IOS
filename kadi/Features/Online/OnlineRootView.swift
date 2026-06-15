//
//  OnlineRootView.swift
//  kadi
//

import SwiftUI

/// Entry point for "Online Multiplayer": gates `OnlineSetupView` behind the
/// email/password auth flow (`AuthView` -> `VerifyEmailView` -> `OnlineSetupView`).
struct OnlineRootView: View {
    @EnvironmentObject private var viewModel: AuthViewModel

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.authState {
        case .loading:
            ZStack {
                KadiTheme.backgroundGradient.ignoresSafeArea()
                ProgressView()
                    .tint(KadiTheme.Colors.accent)
            }
            .navigationTitle("Online")
            .navigationBarTitleDisplayMode(.inline)
        case .signedOut:
            AuthView(viewModel: viewModel)
        case .needsVerification(let user):
            VerifyEmailView(viewModel: viewModel, user: user)
        case .signedIn(let user):
            OnlineSetupView(authUser: user)
        }
    }
}
